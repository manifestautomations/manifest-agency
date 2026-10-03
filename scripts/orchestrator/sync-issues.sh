#!/usr/bin/env bash
# scripts/orchestrator/sync-issues.sh
#
# Bridges GitHub Issues to the Dispatch Queue.
# 1. Scans specific repos for issues with label "agency:pending"
# 2. Converts them to dispatch events
# 3. Updates the issue label to "agency:queued"
# 4. Appends to dispatch.jsonl

set -euo pipefail

# Configuration
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DISPATCH_FILE="$REPO_ROOT/.worker/dispatch/dispatch.jsonl"
REPOS=("manifestautomations/project-saas-factory" "manifestautomations/project-external-auditor")
TRIGGER_LABEL="agency:pending"
QUEUED_LABEL="agency:queued"

# Ensure dispatch file exists
mkdir -p "$(dirname "$DISPATCH_FILE")"
touch "$DISPATCH_FILE"

log() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $1"
}

log "Starting GitHub Issue Sync..."

for FULL_REPO in "${REPOS[@]}"; do
    log "Scanning $FULL_REPO for label '$TRIGGER_LABEL'..."
    
    # List issues with label, formatted as JSON
    # Fields: title, body, number, url
    ISSUES=$(gh issue list --repo "$FULL_REPO" --label "$TRIGGER_LABEL" --json title,body,number,url 2>/dev/null || echo "[]")
    
    # Process each issue
    echo "$ISSUES" | jq -c '.[]' | while read -r issue_json; do
        TITLE=$(echo "$issue_json" | jq -r '.title')
        BODY=$(echo "$issue_json" | jq -r '.body')
        NUMBER=$(echo "$issue_json" | jq -r '.number')
        URL=$(echo "$issue_json" | jq -r '.url')
        
        log "Found Issue #$NUMBER: $TITLE"
        
        # Determine Workspace Path based on Repo Name
        # Assumes repo name matches project directory name
        REPO_NAME=$(basename "$FULL_REPO")
        WORKSPACE_PATH="$REPO_ROOT/projects/$REPO_NAME"
        
        # Validation
        if [[ ! -d "$WORKSPACE_PATH" ]]; then
            log "  Warning: Workspace $WORKSPACE_PATH does not exist. Skipping."
            continue
        fi
        
        # Construct Event ID
        EVENT_ID=$(date +%s%N)
        
        # Create Dispatch Event Payload
        # We assume the Issue Body is the task description
        # We prepend the Title to give context
        FULL_TASK="[From GitHub Issue #$NUMBER] $TITLE\n\n$BODY"
        
        # JSON construction
        # Note: We include github_context for the consumer
        PAYLOAD=$(jq -c -n \
                  --arg id "$EVENT_ID" \
                  --arg time "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
                  --arg path "$WORKSPACE_PATH" \
                  --arg task "$FULL_TASK" \
                  --arg repo "$FULL_REPO" \
                  --arg num "$NUMBER" \
                  '{
                    event_id: $id,
                    timestamp: $time,
                    type: "workspace_dispatch",
                    data: {
                      workspace_path: $path,
                      task_description: $task,
                      github_context: {
                        repo: $repo,
                        issue_number: $num
                      }
                    }
                  }')
        
        # Append to Dispatch Queue
        echo "$PAYLOAD" >> "$DISPATCH_FILE"
        log "  Dispatched Event: $EVENT_ID"
        
        # Update GitHub Issue
        # 1. Add queued label
        # 2. Remove pending label
        # 3. Add comment
        gh issue edit "$NUMBER" --repo "$FULL_REPO" --add-label "$QUEUED_LABEL" --remove-label "$TRIGGER_LABEL"
        gh issue comment "$NUMBER" --repo "$FULL_REPO" --body "🤖 **Agent Dispatched**
        
        Event ID: \`$EVENT_ID\`
        Status: Queued for execution.
        "
        
        log "  Issue #$NUMBER updated."
    done
done

log "Sync Complete."
