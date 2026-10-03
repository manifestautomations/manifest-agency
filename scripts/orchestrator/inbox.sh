#!/usr/bin/env bash
# scripts/orchestrator/inbox.sh
#
# Agency Inbox View
# Displays status of dispatched tasks, active agents, and project health.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DISPATCH_FILE="$REPO_ROOT/.worker/dispatch/dispatch.jsonl"
PROCESSED_FILE="$REPO_ROOT/.worker/dispatch/processed.log"
LOG_DIR="$REPO_ROOT/.worker/logs/orchestrator"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

clear
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}       AGENCY ORCHESTRATOR INBOX        ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. Active Agents
echo -e "${YELLOW}▶ Active Agents${NC}"
# Check for running invoke-claude processes or just check if consume-queue is running
if ps aux | grep "claude" | grep -v grep > /dev/null; then
  echo "  • Dispatch Consumer: RUNNING"
else
  echo "  • Dispatch Consumer: STOPPED"
fi
echo ""

# 2. Tasks Overview
echo -e "${GREEN}▶ Tasks Overview${NC}"

if [[ ! -f "$DISPATCH_FILE" ]]; then
    echo "  No tasks found."
else
    # Simple counting
    TOTAL=$(wc -l < "$DISPATCH_FILE" | tr -d ' ')
    
    if [[ -f "$PROCESSED_FILE" ]]; then
        PROCESSED=$(wc -l < "$PROCESSED_FILE" | tr -d ' ')
    else
        PROCESSED=0
    fi
    
    PENDING=$((TOTAL - PROCESSED))

    echo "  • Total Dispatched: $TOTAL"
    echo "  • Completed/Processing: $PROCESSED"
    echo "  • Pending: $PENDING"
    echo ""
    
    # 3. Recent Activity
    echo -e "${BLUE}▶ Recent Activity${NC}"
    # Show last 5 dispatched items with status
    echo "  (Event ID | Status | Project | Task)"
    echo "  ------------------------------------------------------------"
    
    # Read last 5 lines of dispatch file
    tail -n 5 "$DISPATCH_FILE" | while IFS= read -r line; do
        EVENT_ID=$(echo "$line" | jq -r '.event_id')
        PROJECT=$(echo "$line" | jq -r '.data.workspace_id')
        TASK=$(echo "$line" | jq -r '.data.task_description' | cut -c1-30)... 
        
        STATUS="PENDING"
        if grep -q "$EVENT_ID" "$PROCESSED_FILE" 2>/dev/null; then
            # Check if failed
            if grep -q "$EVENT_ID:FAILED" "$PROCESSED_FILE"; then
                 STATUS="${RED}FAILED${NC} "
            else
                 STATUS="${GREEN}DONE${NC}   "
            fi
        fi
        
        printf "  %s | %b | %s | %s\n" "${EVENT_ID: -8}" "$STATUS" "$PROJECT" "$TASK"
    done
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo "Run ./scripts/orchestrator/consume-queue.sh to process pending tasks."
