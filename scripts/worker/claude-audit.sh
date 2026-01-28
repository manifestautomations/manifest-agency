#!/usr/bin/env bash
# claude-audit - Query audit logs and trust status
# Version: 1.0.0
#
# Usage:
#   claude-audit list [agent] [since]     - List audit events
#   claude-audit violations [agent]       - Show violations
#   claude-audit verify                   - Verify audit chain integrity
#   claude-audit trust-report             - Show trust scores
#   claude-audit explain <command>        - Explain why command was blocked
#   claude-audit incident <id>            - Show incident details
#   claude-audit timeline <issue>         - Show timeline for issue

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKER_DIR="$REPO_ROOT/.worker"
LIB_DIR="$REPO_ROOT/.claude/skills/worker/lib"
AUDIT_DIR="$WORKER_DIR/audit"
VIOLATIONS_DIR="$WORKER_DIR/violations"
LOGS_DIR="$WORKER_DIR/logs"

# --- Show help ---
show_help() {
  cat <<EOF
claude-audit - Query audit logs and trust status

USAGE:
  claude-audit <command> [options]

COMMANDS:
  list [agent] [since]     List audit events
                           - agent: Filter by agent name (optional)
                           - since: Filter by date YYYY-MM-DD (optional)

  violations [agent]       Show violations
                           - agent: Filter by agent name (optional)

  verify                   Verify audit chain integrity
                           Checks hash chain for tampering

  trust-report             Show trust scores for all agents
                           Displays current trust levels and status

  explain <command>        Explain why command was blocked
                           - command: Command pattern to search for

  incident <id>            Show incident details
                           - id: Incident ID (from violations)

  timeline <issue>         Show timeline for issue
                           - issue: Issue number

  --help, -h               Show this help message

EXAMPLES:
  # List all audit events
  claude-audit list

  # List events for specific agent
  claude-audit list backend-developer

  # List events since date
  claude-audit list "" 2026-01-28

  # Show all violations
  claude-audit violations

  # Verify audit chain
  claude-audit verify

  # Show trust report
  claude-audit trust-report

  # Explain blocked command
  claude-audit explain "rm -rf /"

  # Show incident details
  claude-audit incident 20260128-001

EXIT CODES:
  0 - Success
  1 - Error
  2 - Invalid arguments
EOF
}

# --- List audit events ---
cmd_list() {
  local agent="${1:-}"
  local since="${2:-}"

  if [[ ! -d "$AUDIT_DIR" ]]; then
    echo "No audit directory found at: $AUDIT_DIR"
    return 1
  fi

  # Find audit log files
  local log_files=()
  if [[ -n "$since" ]]; then
    # Filter by date
    while IFS= read -r file; do
      log_files+=("$file")
    done < <(find "$AUDIT_DIR" -name "*.audit.jsonl" -type f | sort)
  else
    # All log files
    while IFS= read -r file; do
      log_files+=("$file")
    done < <(find "$AUDIT_DIR" -name "*.audit.jsonl" -type f | sort)
  fi

  if [[ ${#log_files[@]} -eq 0 ]]; then
    echo "No audit logs found"
    return 0
  fi

  # Process and filter logs
  {
    echo "TIMESTAMP EVENT_TYPE AGENT COMMAND"
    for log_file in "${log_files[@]}"; do
      if [[ -n "$since" ]]; then
        # Filter by date in filename
        local file_date
        file_date=$(basename "$log_file" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
        if [[ "$file_date" < "$since" ]]; then
          continue
        fi
      fi

      while IFS= read -r line; do
        local event_type agent_name command timestamp
        event_type=$(echo "$line" | jq -r '.event_type // "unknown"')
        agent_name=$(echo "$line" | jq -r '.agent // "unknown"')
        command=$(echo "$line" | jq -r '.command // "-"')
        timestamp=$(echo "$line" | jq -r '.timestamp // "-"')

        # Filter by agent if specified
        if [[ -n "$agent" && "$agent_name" != "$agent" ]]; then
          continue
        fi

        # Truncate command if too long
        if [[ ${#command} -gt 60 ]]; then
          command="${command:0:57}..."
        fi

        echo "$timestamp $event_type $agent_name $command"
      done < "$log_file"
    done
  } | column -t
}

# --- Show violations ---
cmd_violations() {
  local agent="${1:-}"

  if [[ ! -d "$VIOLATIONS_DIR" ]]; then
    echo "No violations directory found at: $VIOLATIONS_DIR"
    return 1
  fi

  # Find violation log files
  local violation_files=()
  while IFS= read -r file; do
    violation_files+=("$file")
  done < <(find "$VIOLATIONS_DIR" -name "*-violations.jsonl" -type f | sort)

  if [[ ${#violation_files[@]} -eq 0 ]]; then
    echo "No violations found"
    return 0
  fi

  # Process violations
  {
    echo "TIMESTAMP AGENT SEVERITY COMMAND REASON"
    for viol_file in "${violation_files[@]}"; do
      while IFS= read -r line; do
        local timestamp agent_name severity command reason
        timestamp=$(echo "$line" | jq -r '.timestamp // "-"')
        agent_name=$(echo "$line" | jq -r '.agent // "unknown"')
        severity=$(echo "$line" | jq -r '.severity // "unknown"')
        command=$(echo "$line" | jq -r '.command // "-"')
        reason=$(echo "$line" | jq -r '.reason // "-"')

        # Filter by agent if specified
        if [[ -n "$agent" && "$agent_name" != "$agent" ]]; then
          continue
        fi

        # Truncate fields if too long
        if [[ ${#command} -gt 40 ]]; then
          command="${command:0:37}..."
        fi
        if [[ ${#reason} -gt 50 ]]; then
          reason="${reason:0:47}..."
        fi

        echo "$timestamp $agent_name $severity $command $reason"
      done < "$viol_file"
    done
  } | column -t
}

# --- Verify audit chain ---
cmd_verify() {
  # Source audit library to access verification function
  if [[ ! -f "$LIB_DIR/audit.sh" ]]; then
    echo "ERROR: Audit library not found at: $LIB_DIR/audit.sh"
    return 1
  fi

  source "$LIB_DIR/audit.sh"

  echo "Verifying audit chain integrity..."
  echo ""

  if verify_audit_chain; then
    echo ""
    echo "✓ Audit chain verification PASSED"
    echo "  All entries are cryptographically linked"
    echo "  No tampering detected"
    return 0
  else
    echo ""
    echo "✗ Audit chain verification FAILED"
    echo "  Chain integrity compromised"
    echo "  Possible tampering or corruption"
    return 1
  fi
}

# --- Trust report ---
cmd_trust_report() {
  local trust_file="$WORKER_DIR/trust-scores.json"

  if [[ ! -f "$trust_file" ]]; then
    echo "No trust scores found at: $trust_file"
    echo ""
    echo "Trust scores are created when agents execute commands."
    return 0
  fi

  echo "Trust Report"
  echo "============"
  echo ""

  # Parse trust scores
  {
    echo "AGENT SCORE STATUS LAST_VIOLATION"
    jq -r 'to_entries[] | "\(.key) \(.value.score // 0) \(.value.status // "unknown") \(.value.last_violation // "-")"' "$trust_file"
  } | column -t

  echo ""
  echo "Status codes:"
  echo "  good       - Score < 20 (warning threshold)"
  echo "  warning    - Score >= 20 and < 40"
  echo "  probation  - Score >= 40 and < 60"
  echo "  restricted - Score >= 60 (demotion threshold)"
}

# --- Explain blocked command ---
cmd_explain() {
  local command_pattern="${1:-}"

  if [[ -z "$command_pattern" ]]; then
    echo "ERROR: Command pattern required"
    echo "Usage: claude-audit explain <command>"
    return 2
  fi

  if [[ ! -d "$AUDIT_DIR" ]]; then
    echo "No audit directory found at: $AUDIT_DIR"
    return 1
  fi

  # Find most recent command_blocked event matching pattern
  local found=false
  local log_files=()
  while IFS= read -r file; do
    log_files+=("$file")
  done < <(find "$AUDIT_DIR" -name "*.audit.jsonl" -type f | sort -r)

  for log_file in "${log_files[@]}"; do
    while IFS= read -r line; do
      local event_type command
      event_type=$(echo "$line" | jq -r '.event_type // ""')
      command=$(echo "$line" | jq -r '.command // ""')

      if [[ "$event_type" == "command_blocked" && "$command" == *"$command_pattern"* ]]; then
        found=true
        echo "Blocked Command Explanation"
        echo "==========================="
        echo ""
        echo "$line" | jq -r '
          "Command:    \(.command)",
          "Timestamp:  \(.timestamp)",
          "Agent:      \(.agent)",
          "Trust Level: \(.trust_level)",
          "Severity:   \(.severity)",
          "Reason:     \(.reason)",
          "",
          "This command was blocked by the trust guardrails system.",
          "To execute this command, one of the following is required:",
          "  1. Increase agent trust level",
          "  2. Adjust guardrails configuration",
          "  3. Execute manually outside worker context"
        '
        return 0
      fi
    done < "$log_file"
  done

  if [[ "$found" == false ]]; then
    echo "No blocked command matching pattern: $command_pattern"
    return 1
  fi
}

# --- Show incident details ---
cmd_incident() {
  local incident_id="${1:-}"

  if [[ -z "$incident_id" ]]; then
    echo "ERROR: Incident ID required"
    echo "Usage: claude-audit incident <id>"
    return 2
  fi

  local incident_file="$VIOLATIONS_DIR/incident-${incident_id}.json"

  if [[ ! -f "$incident_file" ]]; then
    echo "Incident not found: $incident_id"
    echo "File: $incident_file"
    return 1
  fi

  echo "Incident Details: $incident_id"
  echo "=============================="
  echo ""
  jq '.' "$incident_file"
}

# --- Show timeline for issue ---
cmd_timeline() {
  local issue="${1:-}"

  if [[ -z "$issue" ]]; then
    echo "ERROR: Issue number required"
    echo "Usage: claude-audit timeline <issue>"
    return 2
  fi

  if [[ ! -d "$LOGS_DIR" ]]; then
    echo "No logs directory found at: $LOGS_DIR"
    return 1
  fi

  # Find log files for issue
  local log_files=()
  while IFS= read -r file; do
    log_files+=("$file")
  done < <(find "$LOGS_DIR" -name "issue-${issue}-*.jsonl" -type f | sort)

  if [[ ${#log_files[@]} -eq 0 ]]; then
    echo "No logs found for issue #${issue}"
    return 0
  fi

  echo "Timeline for Issue #${issue}"
  echo "============================"
  echo ""

  # Process logs chronologically
  {
    echo "TIMESTAMP EVENT_TYPE DATA"
    for log_file in "${log_files[@]}"; do
      while IFS= read -r line; do
        local timestamp event_type data
        timestamp=$(echo "$line" | jq -r '.timestamp // "-"')
        event_type=$(echo "$line" | jq -r '.event_type // "unknown"')
        data=$(echo "$line" | jq -c '.data // {}' | head -c 80)

        echo "$timestamp $event_type $data"
      done < "$log_file"
    done
  } | column -t
}

# --- Main ---
main() {
  local command="${1:-}"

  case "$command" in
    list)
      shift
      cmd_list "$@"
      ;;
    violations)
      shift
      cmd_violations "$@"
      ;;
    verify)
      cmd_verify
      ;;
    trust-report)
      cmd_trust_report
      ;;
    explain)
      shift
      cmd_explain "$@"
      ;;
    incident)
      shift
      cmd_incident "$@"
      ;;
    timeline)
      shift
      cmd_timeline "$@"
      ;;
    --help|-h|help|"")
      show_help
      exit 0
      ;;
    *)
      echo "ERROR: Unknown command: $command"
      echo ""
      show_help
      exit 2
      ;;
  esac
}

main "$@"
