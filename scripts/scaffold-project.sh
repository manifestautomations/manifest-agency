#!/bin/bash

# Scaffold a new client project
# Usage: ./scaffold-project.sh "Project Name" "client-slug"

PROJECT_NAME="$1"
SLUG="$2"

if [ -z "$PROJECT_NAME" ] || [ -z "$SLUG" ]; then
  echo "Usage: ./scaffold-project.sh \"Project Name\" \"client-slug\""
  exit 1
fi

TARGET_DIR="projects/$SLUG"

if [ -d "$TARGET_DIR" ]; then
  echo "❌ Error: Project directory $TARGET_DIR already exists."
  exit 1
fi

echo "🏗️  Scaffolding '$PROJECT_NAME' into $TARGET_DIR..."

# 1. Copy Template
# Assuming we have a base template. If not, we create the structure.
mkdir -p "$TARGET_DIR/.planning"
mkdir -p "$TARGET_DIR/src"
mkdir -p "$TARGET_DIR/docs"

# 2. Create README
cat <<EOF > "$TARGET_DIR/README.md"
# $PROJECT_NAME

**Client:** $PROJECT_NAME
**Status:** Initialization
**Trust Level:** 0 (Read-Only)

## Overview
[Description of the project]

## Quick Start
\`\`\`bash
# Install dependencies
npm install

# Run dev server
npm run dev
\`\`\`
EOF

# 3. Create Planning Docs
cat <<EOF > "$TARGET_DIR/.planning/BRIEF.md"
# Project Brief: $PROJECT_NAME

## Goals
- [ ] Goal 1
- [ ] Goal 2

## Constraints
- Tech Stack: [TBD]
- Timeline: [TBD]
EOF

cat <<EOF > "$TARGET_DIR/.planning/trust-ledger.md"
# Trust Ledger

| Date | Level | Reason | Hash |
|---|---|---|---|
| $(date +%Y-%m-%d) | 0 | Project Initialization | N/A |
EOF

# 4. Copy Contract Templates
if [ -f "templates/contracts/SOW-Discovery.md" ]; then
  cp "templates/contracts/SOW-Discovery.md" "$TARGET_DIR/docs/SOW-Discovery.md"
  echo "📄 Copied Discovery SOW template."
fi

# 5. Register in Active Projects
ACTIVE_REGISTRY=".planning/active-projects.md"
if [ -f "$ACTIVE_REGISTRY" ]; then
  # Append table row
  echo "| **$PROJECT_NAME** | $PROJECT_NAME | 🟢 Planning | Discovery Kickoff | $(date -d "+14 days" +%Y-%m-%d) | 0 |" >> "$ACTIVE_REGISTRY"
  echo "📝 Registered in $ACTIVE_REGISTRY"
else
  echo "⚠️  Registry not found at $ACTIVE_REGISTRY"
fi

echo "✅ Project created at $TARGET_DIR"
echo "👉 Next steps:"
echo "   1. Edit $TARGET_DIR/.planning/BRIEF.md"
echo "   2. Run 'npm init' in $TARGET_DIR"
