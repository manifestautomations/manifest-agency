#!/usr/bin/env bash
# audit.sh - Immutable audit log with cryptographic hash chaining
#
# Usage:
#   source .claude/skills/worker/lib/audit.sh
#   init_audit_chain
#   log_audit_event "command_allowed" --arg command "ls" --arg issue "42"
#   verify_audit_chain
#
# Hash chaining provides tamper detection:
# - Each entry contains previous_checksum linking to prior entry
# - Each entry has checksum computed over its content
# - Modifying any entry breaks the chain verification
# - Genesis entry uses 64 zeros as previous_checksum

# Directory for audit logs
AUDIT_DIR=".worker/audit"
CHAIN_STATE_FILE="$AUDIT_DIR/chain.json"

# Initialize the audit chain
# Creates audit directory and genesis chain state if not exists
init_audit_chain() {
  mkdir -p "$AUDIT_DIR"

  # Create genesis chain state if missing
  if [ ! -f "$CHAIN_STATE_FILE" ]; then
    # Genesis checksum: 64 zeros (SHA-256 null state)
    jq -n \
      --arg last_checksum "0000000000000000000000000000000000000000000000000000000000000000" \
      --arg last_timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      --arg entry_count "0" \
      '{
        last_checksum: $last_checksum,
        last_timestamp: $last_timestamp,
        entry_count: ($entry_count | tonumber)
      }' > "$CHAIN_STATE_FILE"
  fi
}

# Log an audit event with hash chaining
# Arguments: event_type [--arg key value]...
# Example: log_audit_event "command_blocked" --arg command "rm -rf /" --arg reason "unsafe"
log_audit_event() {
  local event_type="$1"
  shift

  # Ensure chain is initialized
  if [ ! -f "$CHAIN_STATE_FILE" ]; then
    init_audit_chain
  fi

  # Load previous checksum from chain state
  local previous_checksum
  previous_checksum=$(jq -r '.last_checksum' "$CHAIN_STATE_FILE")

  # Collect all --arg pairs into arrays for processing
  local -a arg_flags=()
  local -a arg_names=()

  # Parse --arg key value pairs
  while [ $# -gt 0 ]; do
    if [ "$1" = "--arg" ]; then
      arg_flags+=("--arg" "$2" "$3")
      arg_names+=("$2")
      shift 3
    else
      shift
    fi
  done

  # Build jq expression to construct data object from args
  local jq_expr='{'
  local first=true
  for name in "${arg_names[@]}"; do
    if [ "$first" = true ]; then
      first=false
    else
      jq_expr+=', '
    fi
    jq_expr+="$name: \$$name"
  done
  jq_expr+='}'

  # Build data object
  local data_json
  if [ ${#arg_flags[@]} -gt 0 ]; then
    data_json=$(jq -n "${arg_flags[@]}" "$jq_expr")
  else
    data_json='{}'
  fi

  # Create timestamp and event ID
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local event_id
  event_id="audit-$(date +%s%N)-$$"

  # Build entry WITHOUT checksum field (will add after computing hash)
  local entry_without_checksum
  entry_without_checksum=$(jq -nc \
    --arg event_type "$event_type" \
    --arg event_id "$event_id" \
    --arg timestamp "$timestamp" \
    --arg previous_checksum "$previous_checksum" \
    --argjson data "$data_json" \
    '{event_type: $event_type, event_id: $event_id, timestamp: $timestamp, previous_checksum: $previous_checksum, data: $data}')

  # Compute checksum of entry content (before adding checksum field)
  local checksum
  checksum=$(echo -n "$entry_without_checksum" | sha256sum | awk '{print $1}')

  # Add checksum field to create final entry
  local final_entry
  final_entry=$(echo "$entry_without_checksum" | jq -c --arg checksum "$checksum" '. + {checksum: $checksum}')

  # Append to daily audit file
  local audit_file="$AUDIT_DIR/$(date +%Y-%m-%d).audit.jsonl"
  echo "$final_entry" >> "$audit_file"

  # Update chain state with new checksum
  local new_count
  new_count=$(jq -r '.entry_count' "$CHAIN_STATE_FILE")
  new_count=$((new_count + 1))

  jq -n \
    --arg last_checksum "$checksum" \
    --arg last_timestamp "$timestamp" \
    --arg entry_count "$new_count" \
    '{
      last_checksum: $last_checksum,
      last_timestamp: $last_timestamp,
      entry_count: ($entry_count | tonumber)
    }' > "$CHAIN_STATE_FILE"
}

# Verify audit chain integrity
# Iterates all .audit.jsonl files in chronological order
# Returns 0 if chain valid, 1 if broken with error details
verify_audit_chain() {
  if [ ! -f "$CHAIN_STATE_FILE" ]; then
    echo "ERROR: Audit chain not initialized" >&2
    return 1
  fi

  # Start with genesis checksum
  local expected_checksum="0000000000000000000000000000000000000000000000000000000000000000"
  local entry_num=0
  local files_checked=0

  # Process all audit files in chronological order (sorted by filename)
  for audit_file in "$AUDIT_DIR"/*.audit.jsonl; do
    # Skip if no files exist (glob didn't match)
    [ -e "$audit_file" ] || continue

    files_checked=$((files_checked + 1))

    # Process each entry in the file
    while IFS= read -r entry; do
      entry_num=$((entry_num + 1))

      # Extract fields from entry
      local event_type event_id timestamp previous_checksum stored_checksum
      event_type=$(echo "$entry" | jq -r '.event_type')
      event_id=$(echo "$entry" | jq -r '.event_id')
      timestamp=$(echo "$entry" | jq -r '.timestamp')
      previous_checksum=$(echo "$entry" | jq -r '.previous_checksum')
      stored_checksum=$(echo "$entry" | jq -r '.checksum')

      # Verify chain continuity (previous_checksum matches expected)
      if [ "$previous_checksum" != "$expected_checksum" ]; then
        echo "ERROR: Chain broken at entry $entry_num ($event_id)" >&2
        echo "  Expected previous_checksum: $expected_checksum" >&2
        echo "  Found previous_checksum: $previous_checksum" >&2
        echo "  File: $audit_file" >&2
        return 1
      fi

      # Recompute checksum from entry content (without checksum field)
      local entry_without_checksum
      entry_without_checksum=$(echo "$entry" | jq -c 'del(.checksum)')
      local computed_checksum
      computed_checksum=$(echo -n "$entry_without_checksum" | sha256sum | awk '{print $1}')

      # Verify checksum matches (tamper detection)
      if [ "$computed_checksum" != "$stored_checksum" ]; then
        echo "ERROR: Tampered entry detected at entry $entry_num ($event_id)" >&2
        echo "  Stored checksum: $stored_checksum" >&2
        echo "  Computed checksum: $computed_checksum" >&2
        echo "  File: $audit_file" >&2
        return 1
      fi

      # Update expected checksum for next entry
      expected_checksum="$stored_checksum"
    done < "$audit_file"
  done

  # Verify final checksum matches chain state
  local chain_checksum
  chain_checksum=$(jq -r '.last_checksum' "$CHAIN_STATE_FILE")

  if [ "$expected_checksum" != "$chain_checksum" ]; then
    echo "ERROR: Chain state mismatch" >&2
    echo "  Chain file says: $chain_checksum" >&2
    echo "  Last entry has: $expected_checksum" >&2
    return 1
  fi

  # Verify entry count matches
  local chain_count
  chain_count=$(jq -r '.entry_count' "$CHAIN_STATE_FILE")

  if [ "$entry_num" != "$chain_count" ]; then
    echo "ERROR: Entry count mismatch" >&2
    echo "  Chain state says: $chain_count entries" >&2
    echo "  Found: $entry_num entries" >&2
    return 1
  fi

  echo "Audit chain verified: $entry_num entries across $files_checked files"
  return 0
}

# Get audit statistics
# Returns JSON with total entries, entries by type, etc.
get_audit_stats() {
  if [ ! -f "$CHAIN_STATE_FILE" ]; then
    echo "{}"
    return
  fi

  local total_entries
  total_entries=$(jq -r '.entry_count' "$CHAIN_STATE_FILE")

  # Count entries by type across all files
  local type_counts="{}"
  for audit_file in "$AUDIT_DIR"/*.audit.jsonl; do
    [ -e "$audit_file" ] || continue

    while IFS= read -r entry; do
      local event_type
      event_type=$(echo "$entry" | jq -r '.event_type')

      # Update type count
      type_counts=$(echo "$type_counts" | jq --arg type "$event_type" '
        .[$type] = ((.[$type] // 0) + 1)
      ')
    done < "$audit_file"
  done

  # Find last violation time (any event with "violation" or "blocked" in type)
  local last_violation=""
  for audit_file in "$AUDIT_DIR"/*.audit.jsonl; do
    [ -e "$audit_file" ] || continue

    while IFS= read -r entry; do
      local event_type timestamp
      event_type=$(echo "$entry" | jq -r '.event_type')
      timestamp=$(echo "$entry" | jq -r '.timestamp')

      if [[ "$event_type" =~ violation|blocked ]]; then
        last_violation="$timestamp"
      fi
    done < "$audit_file"
  done

  # Build stats JSON
  jq -nc \
    --arg total_entries "$total_entries" \
    --argjson type_counts "$type_counts" \
    --arg last_violation "$last_violation" \
    '{
      total_entries: ($total_entries | tonumber),
      entries_by_type: $type_counts,
      last_violation: (if $last_violation == "" then null else $last_violation end)
    }'
}
