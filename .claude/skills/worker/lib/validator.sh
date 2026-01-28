#!/usr/bin/env bash
# validator.sh - Command and scope validation for trust guardrails
# Version: 1.0.0
# Provides: Command validation, scope enforcement, violation tracking

set -euo pipefail

# Determine the project root (assumes this file is in .claude/skills/worker/lib/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# Configuration paths
GUARDRAILS_CONFIG="${PROJECT_ROOT}/.claude/trust-guardrails.yaml"
VIOLATIONS_DIR="${PROJECT_ROOT}/.worker/violations"
TRUST_SCORES_FILE="${VIOLATIONS_DIR}/trust-scores.json"

# Ensure yq is available (installed in 04-01)
if ! command -v yq &>/dev/null; then
  echo "Error: yq not found. Install yq first." >&2
  return 1
fi

# Ensure violations directory exists
mkdir -p "${VIOLATIONS_DIR}"

# Initialize trust-scores.json if it doesn't exist
if [[ ! -f "${TRUST_SCORES_FILE}" ]]; then
  echo '{}' > "${TRUST_SCORES_FILE}"
fi

###########################################
# load_guardrail_rules
# Load and merge hierarchical guardrail rules
# Arguments:
#   $1 - agent name
# Returns:
#   JSON string with merged rules
###########################################
load_guardrail_rules() {
  local agent="${1:-}"

  if [[ -z "${agent}" ]]; then
    echo '{"error": "Agent name required"}' >&2
    return 1
  fi

  local agent_manifest="${PROJECT_ROOT}/.claude/agents/${agent}.yaml"

  # Load project config
  if [[ ! -f "${GUARDRAILS_CONFIG}" ]]; then
    echo '{"error": "Guardrails config not found"}' >&2
    return 1
  fi

  # Parse YAML to JSON using yq
  local project_rules
  project_rules=$(yq eval -o=json '.' "${GUARDRAILS_CONFIG}")

  # Load agent manifest constraints if exists
  local agent_constraints='{}'
  if [[ -f "${agent_manifest}" ]]; then
    agent_constraints=$(yq eval -o=json '.constraints // {}' "${agent_manifest}")
  fi

  # Merge: project rules + agent constraints
  # Agent constraints are added to the merged result
  local merged_rules
  merged_rules=$(jq -n \
    --argjson project "${project_rules}" \
    --argjson agent "${agent_constraints}" \
    '{
      safety_floor: $project.safety_floor,
      destructive_operations: $project.destructive_operations,
      trust_levels: $project.trust_levels,
      violation_scoring: $project.violation_scoring,
      scope_enforcement: $project.scope_enforcement,
      agent_constraints: $agent
    }')

  echo "${merged_rules}"
}

###########################################
# command_matches_pattern
# Check if command matches a pattern
# Arguments:
#   $1 - command string
#   $2 - pattern (regex)
# Returns:
#   0 if matches, 1 if not
###########################################
command_matches_pattern() {
  local command="${1:-}"
  local pattern="${2:-}"

  if [[ -z "${command}" || -z "${pattern}" ]]; then
    return 1
  fi

  # Normalize command (collapse whitespace)
  command=$(echo "${command}" | tr -s ' ')

  # Convert \s to [ \t] for bash regex (bash doesn't support \s)
  pattern="${pattern//\\s/[[:space:]]}"

  # Use regex matching with extended regex
  if [[ "${command}" =~ ${pattern} ]]; then
    return 0
  else
    return 1
  fi
}

###########################################
# validate_command
# Validate command against safety floor and destructive patterns
# Arguments:
#   $1 - agent name
#   $2 - trust level (0-4)
#   $3 - command to validate
# Returns:
#   JSON: {action: "allow|block|confirm", severity, reason, alternatives[]}
###########################################
validate_command() {
  local agent="${1:-}"
  local trust_level="${2:-}"
  local command="${3:-}"

  if [[ -z "${agent}" || -z "${trust_level}" || -z "${command}" ]]; then
    echo '{"action": "block", "severity": "critical", "reason": "Invalid parameters", "alternatives": []}'
    return 1
  fi

  # Load rules
  local rules
  rules=$(load_guardrail_rules "${agent}")

  # Check safety floor patterns (ALWAYS block regardless of trust level)
  local safety_patterns
  safety_patterns=$(echo "${rules}" | jq -r '.safety_floor.patterns[]')

  while IFS= read -r pattern_obj; do
    [[ -z "${pattern_obj}" ]] && continue

    local pattern
    pattern=$(echo "${pattern_obj}" | jq -r '.pattern')

    if command_matches_pattern "${command}" "${pattern}"; then
      local severity
      severity=$(echo "${pattern_obj}" | jq -r '.severity')
      local reason
      reason=$(echo "${pattern_obj}" | jq -r '.reason')

      echo "{\"action\": \"block\", \"severity\": \"${severity}\", \"reason\": \"Safety floor: ${reason}\", \"alternatives\": []}"
      return 0
    fi
  done < <(echo "${rules}" | jq -c '.safety_floor.patterns[]')

  # Check destructive operations patterns
  local destructive_patterns
  while IFS= read -r pattern_obj; do
    [[ -z "${pattern_obj}" ]] && continue

    local pattern
    pattern=$(echo "${pattern_obj}" | jq -r '.pattern')

    if command_matches_pattern "${command}" "${pattern}"; then
      local severity
      severity=$(echo "${pattern_obj}" | jq -r '.severity')
      local reason
      reason=$(echo "${pattern_obj}" | jq -r '.reason')

      # Determine action based on trust level + severity
      local action
      action=$(echo "${rules}" | jq -r ".trust_levels[\"${trust_level}\"].${severity}")

      # If action is null (trust level 0 blocks everything), default to block
      if [[ "${action}" == "null" || -z "${action}" ]]; then
        action="block"
      fi

      echo "{\"action\": \"${action}\", \"severity\": \"${severity}\", \"reason\": \"${reason}\", \"alternatives\": []}"
      return 0
    fi
  done < <(echo "${rules}" | jq -c '.destructive_operations.patterns[]')

  # No pattern matched - allow
  echo '{"action": "allow", "severity": "low", "reason": "No matching patterns", "alternatives": []}'
  return 0
}

###########################################
# path_matches_pattern
# Check if path matches a glob pattern with security constraints
# Arguments:
#   $1 - file path
#   $2 - glob pattern
# Returns:
#   0 if matches, 1 if not
###########################################
path_matches_pattern() {
  local path="${1:-}"
  local pattern="${2:-}"

  if [[ -z "${path}" || -z "${pattern}" ]]; then
    return 1
  fi

  # Convert glob pattern to regex with security constraints
  # require_literal_separator: / not matched by *
  # require_literal_leading_dot: . at start not matched by *

  # Escape special regex characters except * and ?
  local regex="${pattern}"
  regex="${regex//./\\.}"  # Escape dots
  regex="${regex//+/\\+}"  # Escape plus
  regex="${regex//^/\\^}"  # Escape caret
  regex="${regex//$/\\$}"  # Escape dollar
  regex="${regex//(/\\(}"  # Escape parens
  regex="${regex//)/\\)}"
  regex="${regex//[/\\[}"  # Escape brackets
  regex="${regex//]/\\]}"

  # Convert glob wildcards to regex with constraints
  # ** matches any path segment (including /)
  regex="${regex//\*\*/___DOUBLE_STAR___}"
  # * matches any character except /
  regex="${regex//\*/[^/]*}"
  # Restore **
  regex="${regex//___DOUBLE_STAR___/.*}"
  # ? matches any single character except /
  regex="${regex//\?/[^/]}"

  # Anchor the pattern
  regex="^${regex}$"

  # Leading dot constraint: if path starts with . and pattern doesn't, fail
  if [[ "${path}" =~ ^\. && ! "${pattern}" =~ ^\. ]]; then
    return 1
  fi

  # Match
  if [[ "${path}" =~ ${regex} ]]; then
    return 0
  else
    return 1
  fi
}

###########################################
# validate_scope
# Validate file path against agent's allow/deny constraints
# Arguments:
#   $1 - agent name
#   $2 - file path
#   $3 - operation (read|write)
# Returns:
#   JSON: {allowed: true|false, reason, matched_pattern, alternatives[]}
###########################################
validate_scope() {
  local agent="${1:-}"
  local file_path="${2:-}"
  local operation="${3:-read}"

  if [[ -z "${agent}" || -z "${file_path}" ]]; then
    echo '{"allowed": false, "reason": "Invalid parameters", "matched_pattern": null, "alternatives": []}'
    return 1
  fi

  # Load rules
  local rules
  rules=$(load_guardrail_rules "${agent}")

  # Get agent constraints
  local allow_patterns
  allow_patterns=$(echo "${rules}" | jq -c '.agent_constraints.allow // []')
  local deny_patterns
  deny_patterns=$(echo "${rules}" | jq -c '.agent_constraints.deny // []')

  # Resolve file path to canonical form (handle relative paths)
  local canonical_path
  if [[ "${file_path}" =~ ^/ ]]; then
    canonical_path="${file_path}"
  else
    canonical_path="${file_path}"
  fi

  # Check deny list first (deny always wins)
  while IFS= read -r pattern; do
    [[ -z "${pattern}" || "${pattern}" == "null" ]] && continue

    # Remove quotes from jq output
    pattern="${pattern//\"/}"

    if path_matches_pattern "${canonical_path}" "${pattern}"; then
      echo "{\"allowed\": false, \"reason\": \"Path denied by pattern\", \"matched_pattern\": \"${pattern}\", \"alternatives\": []}"
      return 0
    fi
  done < <(echo "${deny_patterns}" | jq -r '.[]')

  # Check allow list
  local allowed=false
  local matched_pattern=""

  while IFS= read -r pattern; do
    [[ -z "${pattern}" || "${pattern}" == "null" ]] && continue

    # Remove quotes from jq output
    pattern="${pattern//\"/}"

    if path_matches_pattern "${canonical_path}" "${pattern}"; then
      allowed=true
      matched_pattern="${pattern}"
      break
    fi
  done < <(echo "${allow_patterns}" | jq -r '.[]')

  if [[ "${allowed}" == "true" ]]; then
    echo "{\"allowed\": true, \"reason\": \"Path allowed by pattern\", \"matched_pattern\": \"${matched_pattern}\", \"alternatives\": []}"
    return 0
  else
    echo "{\"allowed\": false, \"reason\": \"Path not in allowed list\", \"matched_pattern\": null, \"alternatives\": []}"
    return 0
  fi
}

###########################################
# record_violation
# Record a violation and update trust scores
# Arguments:
#   $1 - agent name
#   $2 - command that caused violation
#   $3 - reason (e.g., "safety_floor", "scope_denied")
#   $4 - severity (critical|high|medium|low)
# Returns:
#   JSON: {status, new_score, threshold_status}
###########################################
record_violation() {
  local agent="${1:-}"
  local command="${2:-}"
  local reason="${3:-}"
  local severity="${4:-low}"

  if [[ -z "${agent}" ]]; then
    echo '{"status": "error", "reason": "Agent name required"}'
    return 1
  fi

  # Load guardrail rules for scoring
  local rules
  rules=$(load_guardrail_rules "${agent}")

  # Get points for severity
  local points
  points=$(echo "${rules}" | jq -r ".violation_scoring.points_per_severity.${severity} // 2")

  # Get current score
  local current_score
  if [[ -f "${TRUST_SCORES_FILE}" ]]; then
    current_score=$(jq -r ".\"${agent}\" // 0" "${TRUST_SCORES_FILE}")
  else
    current_score=0
  fi

  # Calculate new score
  local new_score=$((current_score + points))

  # Update trust-scores.json
  local updated_scores
  updated_scores=$(jq --arg agent "${agent}" --argjson score "${new_score}" \
    '.[$agent] = $score' "${TRUST_SCORES_FILE}")
  echo "${updated_scores}" > "${TRUST_SCORES_FILE}"

  # Append to agent violations log
  local violations_log="${VIOLATIONS_DIR}/${agent}-violations.jsonl"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local violation_entry
  violation_entry=$(jq -n \
    --arg ts "${timestamp}" \
    --arg cmd "${command}" \
    --arg reason "${reason}" \
    --arg severity "${severity}" \
    --argjson points "${points}" \
    --argjson new_score "${new_score}" \
    '{
      timestamp: $ts,
      command: $cmd,
      reason: $reason,
      severity: $severity,
      points: $points,
      new_score: $new_score
    }')

  echo "${violation_entry}" >> "${violations_log}"

  # Check thresholds
  local warning_threshold
  warning_threshold=$(echo "${rules}" | jq -r '.violation_scoring.thresholds.warning // 20')
  local probation_threshold
  probation_threshold=$(echo "${rules}" | jq -r '.violation_scoring.thresholds.probation // 40')
  local demotion_threshold
  demotion_threshold=$(echo "${rules}" | jq -r '.violation_scoring.thresholds.demotion // 60')

  local threshold_status="ok"
  if (( new_score >= demotion_threshold )); then
    threshold_status="demotion"
  elif (( new_score >= probation_threshold )); then
    threshold_status="probation"
  elif (( new_score >= warning_threshold )); then
    threshold_status="warning"
  fi

  echo "{\"status\": \"recorded\", \"new_score\": ${new_score}, \"threshold_status\": \"${threshold_status}\"}"
  return 0
}

###########################################
# apply_trust_decay
# Apply decay to trust score (reward clean actions)
# Arguments:
#   $1 - agent name
# Returns:
#   JSON: {status, new_score}
###########################################
apply_trust_decay() {
  local agent="${1:-}"

  if [[ -z "${agent}" ]]; then
    echo '{"status": "error", "reason": "Agent name required"}'
    return 1
  fi

  # Load guardrail rules for decay rate
  local rules
  rules=$(load_guardrail_rules "${agent}")

  local decay_rate
  decay_rate=$(echo "${rules}" | jq -r '.violation_scoring.decay_rate // 5')

  # Get current score
  local current_score
  if [[ -f "${TRUST_SCORES_FILE}" ]]; then
    current_score=$(jq -r ".\"${agent}\" // 0" "${TRUST_SCORES_FILE}")
  else
    current_score=0
  fi

  # Calculate new score (floor at 0)
  local new_score=$((current_score - decay_rate))
  if (( new_score < 0 )); then
    new_score=0
  fi

  # Update trust-scores.json
  local updated_scores
  updated_scores=$(jq --arg agent "${agent}" --argjson score "${new_score}" \
    '.[$agent] = $score' "${TRUST_SCORES_FILE}")
  echo "${updated_scores}" > "${TRUST_SCORES_FILE}"

  echo "{\"status\": \"decayed\", \"new_score\": ${new_score}}"
  return 0
}

###########################################
# get_trust_status
# Get current trust status for an agent
# Arguments:
#   $1 - agent name
# Returns:
#   JSON: {score, status, last_violation}
###########################################
get_trust_status() {
  local agent="${1:-}"

  if [[ -z "${agent}" ]]; then
    echo '{"status": "error", "reason": "Agent name required"}'
    return 1
  fi

  # Get current score
  local score
  if [[ -f "${TRUST_SCORES_FILE}" ]]; then
    score=$(jq -r ".\"${agent}\" // 0" "${TRUST_SCORES_FILE}")
  else
    score=0
  fi

  # Load thresholds
  local rules
  rules=$(load_guardrail_rules "${agent}")

  local warning_threshold
  warning_threshold=$(echo "${rules}" | jq -r '.violation_scoring.thresholds.warning // 20')
  local probation_threshold
  probation_threshold=$(echo "${rules}" | jq -r '.violation_scoring.thresholds.probation // 40')
  local demotion_threshold
  demotion_threshold=$(echo "${rules}" | jq -r '.violation_scoring.thresholds.demotion // 60')

  local status="ok"
  if (( score >= demotion_threshold )); then
    status="demotion"
  elif (( score >= probation_threshold )); then
    status="probation"
  elif (( score >= warning_threshold )); then
    status="warning"
  fi

  # Get last violation timestamp
  local violations_log="${VIOLATIONS_DIR}/${agent}-violations.jsonl"
  local last_violation="null"

  if [[ -f "${violations_log}" ]]; then
    last_violation=$(tail -n 1 "${violations_log}" | jq -r '.timestamp // "null"')
  fi

  echo "{\"score\": ${score}, \"status\": \"${status}\", \"last_violation\": \"${last_violation}\"}"
  return 0
}

###########################################
# handle_critical_violation
# Handle critical violations by creating incident files
# Arguments:
#   $1 - agent name
#   $2 - command that caused violation
#   $3 - pattern that matched
#   $4 - issue context (optional)
# Returns:
#   JSON: {incident_id, file_path}
###########################################
handle_critical_violation() {
  local agent="${1:-}"
  local command="${2:-}"
  local pattern="${3:-}"
  local issue="${4:-}"

  if [[ -z "${agent}" || -z "${command}" || -z "${pattern}" ]]; then
    echo '{"status": "error", "reason": "Invalid parameters"}'
    return 1
  fi

  # Generate incident ID
  local incident_id
  incident_id="$(date +%Y%m%d-%H%M%S)-${agent}"

  local incident_file="${VIOLATIONS_DIR}/incident-${incident_id}.json"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Create incident record
  local incident_record
  incident_record=$(jq -n \
    --arg id "${incident_id}" \
    --arg ts "${timestamp}" \
    --arg agent "${agent}" \
    --arg cmd "${command}" \
    --arg pattern "${pattern}" \
    --arg issue "${issue}" \
    '{
      incident_id: $id,
      timestamp: $ts,
      agent: $agent,
      command: $cmd,
      pattern: $pattern,
      severity: "critical",
      issue: $issue,
      git_ref: null,
      cwd: null
    }')

  # Add git context if available
  if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null 2>&1; then
    local git_ref
    git_ref=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    incident_record=$(echo "${incident_record}" | jq --arg ref "${git_ref}" '.git_ref = $ref')
  fi

  # Add working directory
  incident_record=$(echo "${incident_record}" | jq --arg cwd "$(pwd)" '.cwd = $cwd')

  # Write incident file
  echo "${incident_record}" > "${incident_file}"

  echo "{\"incident_id\": \"${incident_id}\", \"file_path\": \"${incident_file}\"}"
  return 0
}

# Export functions for use in other scripts
export -f load_guardrail_rules
export -f command_matches_pattern
export -f validate_command
export -f path_matches_pattern
export -f validate_scope
export -f record_violation
export -f apply_trust_decay
export -f get_trust_status
export -f handle_critical_violation
