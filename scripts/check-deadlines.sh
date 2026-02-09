#!/bin/bash

# Configuration
WEBHOOK_URL="${DISCORD_WEBHOOK_URL}"
ACTIVE_PROJECTS_FILE=".planning/active-projects.md"

if [ -z "$WEBHOOK_URL" ]; then
  echo "❌ DISCORD_WEBHOOK_URL is not set."
  exit 1
fi

if [ ! -f "$ACTIVE_PROJECTS_FILE" ]; then
  echo "❌ $ACTIVE_PROJECTS_FILE not found."
  exit 0
fi

echo "🔍 Scanning for deadlines in $ACTIVE_PROJECTS_FILE..."

# Parse the markdown table
# Skipping header lines (first 2)
# Extracting: Project, Deadline
# Note: This is a simple regex parser. It assumes the format | Project | ... | Deadline | ... |

TODAY=$(date +%Y-%m-%d)
UPCOMING_DEADLINES=""

while IFS= read -r line; do
  # Skip headers and separators
  if [[ "$line" =~ ^\|.*\|.*\|.*\|.*\|.*\|$ ]] && ! [[ "$line" =~ "---" ]] && ! [[ "$line" =~ "Project" ]]; then
    
    PROJECT=$(echo "$line" | awk -F'|' '{print $2}' | xargs)
    DEADLINE=$(echo "$line" | awk -F'|' '{print $5}' | xargs)
    
    if [ ! -z "$DEADLINE" ]; then
      # Check if deadline is within 7 days
      # Using python for date math because bash is painful
      DAYS_DIFF=$(python3 -c "from datetime import datetime; d1 = datetime.strptime('$TODAY', '%Y-%m-%d'); d2 = datetime.strptime('$DEADLINE', '%Y-%m-%d'); print((d2 - d1).days)")
      
      if [ "$DAYS_DIFF" -ge 0 ] && [ "$DAYS_DIFF" -le 7 ]; then
        UPCOMING_DEADLINES="${UPCOMING_DEADLINES}• **${PROJECT}**: ${DEADLINE} (in ${DAYS_DIFF} days)\n"
      elif [ "$DAYS_DIFF" -lt 0 ]; then
         UPCOMING_DEADLINES="${UPCOMING_DEADLINES}• 🚨 **${PROJECT}**: ${DEADLINE} (OVERDUE by ${DAYS_DIFF/-/} days)\n"
      fi
    fi
  fi
done < "$ACTIVE_PROJECTS_FILE"

if [ -z "$UPCOMING_DEADLINES" ]; then
  echo "✅ No looming deadlines found."
  exit 0
fi

# Send to Discord
PAYLOAD=$(cat <<EOF
{
  "embeds": [
    {
      "title": "⏰ Looming Deadlines",
      "description": "The following milestones are due soon:",
      "color": 16729871,
      "fields": [
        {
          "name": "Deliverables",
          "value": "${UPCOMING_DEADLINES}",
          "inline": false
        }
      ],
      "footer": {
        "text": "Manifest Automations • Accountability Bot"
      }
    }
  ]
}
EOF
)

curl -H "Content-Type: application/json" \
     -X POST \
     -d "$PAYLOAD" \
     "$WEBHOOK_URL"

echo "✅ Notification sent."
