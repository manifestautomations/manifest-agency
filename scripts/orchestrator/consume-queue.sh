#!/usr/bin/env bash
# scripts/orchestrator/consume-queue.sh
#
# Process Dispatch Queue
# 1. Reads .worker/dispatch/dispatch.jsonl
# 2. Checks against .worker/dispatch/processed.log
# 3. Invokes Claude Agent for new events
# 4. Updates processed log

set -euo pipefail

# Configuration
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DISPATCH_FILE="$REPO_ROOT/.worker/dispatch/dispatch.jsonl"
PROCESSED_FILE="$REPO_ROOT/.worker/dispatch/processed.log"
LOG_DIR="$REPO_ROOT/.worker/logs/orchestrator"

# Ensure directories exist
mkdir -p "$(dirname "$PROCESSED_FILE")"
mkdir -p "$LOG_DIR"
touch "$PROCESSED_FILE"

# Logging helper
log() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $1"
}

log "Starting Dispatch Consumer..."

if [[ ! -f "$DISPATCH_FILE" ]]; then
    log "No dispatch file found at $DISPATCH_FILE"
    exit 0
fi

# Process each line in dispatch file
while IFS= read -r event_json; do
    # Skip empty lines
    [[ -z "$event_json" ]] && continue

    # Extract Event ID
    EVENT_ID=$(echo "$event_json" | jq -r '.event_id')
    
    # Check if already processed
    if grep -q "$EVENT_ID" "$PROCESSED_FILE"; then
        continue
    fi

    log "Processing Event: $EVENT_ID"

    # Extract Data
    WORKSPACE_PATH=$(echo "$event_json" | jq -r '.data.workspace_path')
    TASK_DESC=$(echo "$event_json" | jq -r '.data.task_description')
    PARENT_AGENT=$(echo "$event_json" | jq -r '.data.parent_agent')

    # Validate Workspace
    # Handle Windows/Git Bash path conversion issues if necessary
    # For now assuming paths are valid/accessible

    if [[ ! -d "$WORKSPACE_PATH" ]]; then
        log "Error: Workspace path not found: $WORKSPACE_PATH"
        echo "$EVENT_ID:FAILED:WorkspaceNotFound" >> "$PROCESSED_FILE"
        continue
    fi

    log "  Target: $WORKSPACE_PATH"
    log "  Task: $TASK_DESC"
    
    # Extract GitHub Context if present
    GH_REPO=$(echo "$event_json" | jq -r '.data.github_context.repo // empty')
    GH_ISSUE_NUM=$(echo "$event_json" | jq -r '.data.github_context.issue_number // empty')
    
    if [[ -n "$GH_REPO" && -n "$GH_ISSUE_NUM" ]]; then
        log "  Linked to GitHub Issue: $GH_REPO #$GH_ISSUE_NUM"
        gh issue comment "$GH_ISSUE_NUM" --repo "$GH_REPO" --body "🚀 **Agent Started**
        
        Processing task in workspace: \`$(basename "$WORKSPACE_PATH")\`
        " || log "  Warning: Failed to comment on GitHub Issue"
    fi

    # Construct Prompt
    # We explicitly highlight Global Tools location to the sub-agent
    PROMPT="You are an autonomous sub-agent dispatched to this workspace.
    
    **Your Objective:**
    $TASK_DESC
    
    **Context:**
    - You are working in: $WORKSPACE_PATH
    - You have full access to run commands and edit files in this directory.
    - **Global Tools:** You can access global GSD scripts at ~/.claude/commands/gsd/
    
    **CRITICAL: HEADLESS EXECUTION MODE**
    - You are running non-interactively.
    - When running GSD commands (like /gsd:execute-phase), YOU MUST ALWAYS APPEND THE \`--auto-approve\` FLAG.
    - Example: \`/gsd:execute-phase 1 --auto-approve\`
    - Do NOT stop to ask questions.
    
    **Instructions:**
    1. Read the necessary GSD scripts.
    2. Executive the workflow step-by-step.
    3. Self-supply all required inputs based on the plan.
    4. Report success only when the artifacts (PROJECT.md, etc.) are created.
    "

    # Execute Agent
    # We use a subshell to change directory without affecting the loop
    (
        cd "$WORKSPACE_PATH"
        
        log "  Invoking Claude Agent..."
        
        # Capture output to log file
        AGENT_LOG="$LOG_DIR/event-${EVENT_ID}.log"
        
        # Invoke Claude
        # Using -p for prompt, --print mode to just run it
        # Assuming 'claude' is in PATH. 
        # Note: In some environments we might need to specify full path or sourcing.
        
        if command -v claude &> /dev/null; then
             claude -p "$PROMPT" --allowedTools "Bash,Read,Write,Edit,Glob,Grep" > "$AGENT_LOG" 2>&1
             EXIT_CODE=$?
        else
             log "  Error: 'claude' command not found."
             echo "Error: claude command not found" > "$AGENT_LOG"
             EXIT_CODE=1
        fi
        
        if [[ $EXIT_CODE -eq 0 ]]; then
            log "  Success: Agent finished."
            if [[ -n "$GH_REPO" && -n "$GH_ISSUE_NUM" ]]; then
                 gh issue comment "$GH_ISSUE_NUM" --repo "$GH_REPO" --body "✅ **Task Complete**
                 
                 Agent finished successfully. Please review the changes in the repository.
                 "
                 gh issue edit "$GH_ISSUE_NUM" --repo "$GH_REPO" --add-label "agency:review" --remove-label "agency:queued"
            fi
        else
             log "  Failure: Agent exited with code $EXIT_CODE. See $AGENT_LOG"
             if [[ -n "$GH_REPO" && -n "$GH_ISSUE_NUM" ]]; then
                 gh issue comment "$GH_ISSUE_NUM" --repo "$GH_REPO" --body "❌ **Agent Failed**
                 
                 Exit Code: $EXIT_CODE
                 Log: \`$AGENT_LOG\`
                 "
                 gh issue edit "$GH_ISSUE_NUM" --repo "$GH_REPO" --add-label "agency:failed" --remove-label "agency:queued"
            fi
        fi
    )

    # Mark as processed
    echo "$EVENT_ID:PROCESSED" >> "$PROCESSED_FILE"

done < "$DISPATCH_FILE"

log "Dispatch Consumer run complete."
