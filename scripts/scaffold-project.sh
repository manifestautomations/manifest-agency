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
TEMPLATE_DIR="templates/new-project"

if [ -d "$TARGET_DIR" ]; then
  echo "❌ Error: Project directory $TARGET_DIR already exists."
  exit 1
fi

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "❌ Error: Template directory $TEMPLATE_DIR does not exist."
  exit 1
fi

echo "🏗️  Scaffolding '$PROJECT_NAME' into $TARGET_DIR..."

# 1. Copy Template Directory
cp -r "$TEMPLATE_DIR" "$TARGET_DIR"

# 2. Replace Variables in Files
# macOS/BSD sed requires '' after -i, Linux does not. We'll use a temp file approach or basic sed.
# Assuming Linux/Git Bash environment based on previous commands.

find "$TARGET_DIR" -type f -exec sed -i "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" {} +
find "$TARGET_DIR" -type f -exec sed -i "s/{{DATE}}/$(date +%Y-%m-%d)/g" {} +

# 3. Create Additional Directories (if not in template)
mkdir -p "$TARGET_DIR/src"
mkdir -p "$TARGET_DIR/docs"

# 4. Copy Contract Templates
if [ -f "templates/contracts/SOW-Discovery.md" ]; then
  cp "templates/contracts/SOW-Discovery.md" "$TARGET_DIR/docs/SOW-Discovery.md"
  echo "📄 Copied Discovery SOW template."
fi

# 5. Register in Active Projects
ACTIVE_REGISTRY=".planning/active-projects.md"
if [ -f "$ACTIVE_REGISTRY" ]; then
  # Append table row
  DATE_PLUS_14=$(date -d "+14 days" +%Y-%m-%d 2>/dev/null || date -v+14d +%Y-%m-%d) # Linux vs Mac compat
  echo "| **$PROJECT_NAME** | $PROJECT_NAME | 🟢 Planning | Discovery Kickoff | $DATE_PLUS_14 | 0 |" >> "$ACTIVE_REGISTRY"
  echo "📝 Registered in $ACTIVE_REGISTRY"
else
  echo "⚠️  Registry not found at $ACTIVE_REGISTRY"
fi

echo "✅ Project created at $TARGET_DIR"
echo "👉 Next steps:"
echo "   1. Edit $TARGET_DIR/.planning/BRIEF.md"
echo "   2. Run 'npm init' in $TARGET_DIR"
