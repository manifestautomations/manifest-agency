#!/bin/bash

# Manifest Agency - Developer Setup Script
# "One script to rule them all."

echo "🦞 Manifest Agency Setup"
echo "========================"

# 1. Check Prerequisites
echo "🔍 Checking tools..."

if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) not found. Please install it."
    exit 1
fi
echo "✅ GitHub CLI found."

if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Please install it."
    exit 1
fi
echo "✅ Node.js found."

# 2. Install Global Utils (Optional)
# echo "📦 Installing global utilities..."
# npm install -g supabase

# 3. Setup Kitchen Assistant
if [ -d "projects/kitchen-assistant" ]; then
    echo "🍳 Setting up Kitchen Assistant..."
    cd projects/kitchen-assistant
    if [ -f "package.json" ]; then
        npm install
    else
        echo "⚠️  No package.json found in kitchen-assistant."
    fi
    cd ../..
fi

# 4. Setup Hooks (Lobster)
echo "🦞 Setting up git hooks..."
# (Future: Install pre-commit hooks)

echo "✅ Setup complete! You are ready to build."
echo "👉 Run './scripts/scaffold-project.sh' to start a new client project."
