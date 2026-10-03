#!/usr/bin/env bash
# scripts/orchestrator/scrum-master.sh
#
# Headless Scrum Master Agent
# 1. Fetches ALL open issues from tracked repositories
# 2. Uses Claude to Analyze, Triage, and Prioritize
# 3. Executes Claude's decisions:
#    - Label as agency:queued (Dispatch)
#    - Close duplicates
#    - Request more info
#    - Merge related tasks

set -euo pipefail

# Configuration
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPOS=("manifestautomations/project-saas-factory" "manifestautomations/project-external-auditor")
SCRUM_LOG="$REPO_ROOT/.worker/logs/scrum-master.log"
SYNC_SCRIPT="$REPO_ROOT/scripts/orchestrator/sync-issues.sh"

log() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $1" | tee -a "$SCRUM_LOG"
}

log "Starting Scrum Master Cycle..."

ALL_ISSUES="[]"

# 1. Gather Intelligence
for REPO in "${REPOS[@]}"; do
    log "Polling $REPO..."
    ISSUES=$(gh issue list --repo "$REPO" --state open --json number,title,body,labels,url,author --limit 50 2>/dev/null || echo "[]")
    
    # Decorate with Repo name
    ISSUES=$(echo "$ISSUES" | jq --arg repo "$REPO" 'map(. + {repository: $repo})')
    
    # Merge into master list
    ALL_ISSUES=$(echo "$ALL_ISSUES" | jq --argjson new "$ISSUES" '. + $new')
done

COUNT=$(echo "$ALL_ISSUES" | jq 'length')
log "Found $COUNT open issues total."

if [[ "$COUNT" -eq 0 ]]; then
    log "No issues to manage. Sleeping."
    exit 0
fi

# 2. Consult the Oracle (Claude)


log "Invoking Claude Strategy..."

# Use HEREDOC to avoid argument length limits and safe quoting
cat <<EOF > .scrum_prompt.txt
You are the Headless Scrum Master for 'Manifest Automations'.
Your goal is to optimize the workflow of autonomous agents.

**Current Open Issues:**
$ALL_ISSUES

**Your Instructions:**
1. **Analyze**: Read all issues. Look for duplicates, dependencies, or unclear tasks.
2. **Triaging Rules**:
    - If a task is clear and ready for execution -> Action: 'dispatch'
    - If a task is a duplicate -> Action: 'close' (citing the original)
    - If a task is vague -> Action: 'comment' (asking for clarification)
    - If a task is already running (has label 'agency:processing') -> Action: 'ignore'
    - If a task is pending dispatch (has label 'agency:pending') -> Action: 'ignore'
    - If a task is queued (has label 'agency:queued') -> Action: 'ignore'

**Output Format:**
Return ONLY a valid JSON array of actions. Do not output markdown.
Possible actions:
[
  { "action": "dispatch", "repo": "...", "issue_number": 123, "reason": "Clear task" },
  { "action": "close", "repo": "...", "issue_number": 123, "reason": "Duplicate of #10" },
  { "action": "comment", "repo": "...", "issue_number": 123, "body": "Please clarify X" }
]
EOF

# Call Claude
PLAN_JSON=$(claude -p "$(cat .scrum_prompt.txt)" --print)

# 3. Execute the Plan
echo "$PLAN_JSON" | jq -c '.[]' | while read -r action; do
    TYPE=$(echo "$action" | jq -r '.action')
    REPO=$(echo "$action" | jq -r '.repo')
    NUM=$(echo "$action" | jq -r '.issue_number')
    
    log "Executing: $TYPE on $REPO #$NUM"
    
    case "$TYPE" in
        "dispatch")
            # Apply 'agency:queued' label. The sync-issues.sh script will pick this up.
            gh issue edit "$NUM" --repo "$REPO" --add-label "agency:pending"
            log "  Marked for dispatch."
            ;;
        "close")
            REASON=$(echo "$action" | jq -r '.reason')
            gh issue close "$NUM" --repo "$REPO" --comment "Closed by Scrum Master: $REASON"
            ;;
        "comment")
            BODY=$(echo "$action" | jq -r '.body')
            gh issue comment "$NUM" --repo "$REPO" --body "Scrum Master: $BODY"
            ;;
        "ignore")
            # Do nothing
            ;;
    esac
done
# 4. Trigger Sync
# Now that labels are applied, run the bridge to actually dispatch them.
log "Triggering Dispatch Sync..."
"$SYNC_SCRIPT"

log "Scrum Cycle Complete."
rm .scrum_prompt.txt

# 4. Trigger Sync
# Now that labels are applied, run the bridge to actually dispatch them.
log "Triggering Dispatch Sync..."
"$SYNC_SCRIPT"

log "Scrum Cycle Complete."
rm .scrum_prompt.txt
