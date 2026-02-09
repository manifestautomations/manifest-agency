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

# 2. Install Sub-Package Dependencies

# Sales Scripts
if [ -d "scripts/sales" ]; then
    echo "📦 Installing Sales Triage dependencies..."
    cd scripts/sales
    if [ -f "package.json" ]; then
        npm install
    fi
    cd ../..
fi

# Outreach Scripts
if [ -d "scripts/outreach" ]; then
    echo "📦 Installing Outreach Generator dependencies..."
    cd scripts/outreach
    if [ -f "package.json" ]; then
        npm install
    fi
    cd ../..
fi

# Agency Website (Next.js)
if [ -d "projects/agency-website" ]; then
    echo "📦 Installing Agency Website dependencies..."
    cd projects/agency-website
    if [ -f "package.json" ]; then
        npm install
    fi
    cd ../..
fi

# 3. Setup Hooks (Lobster)
echo "🦞 Setting up git hooks..."
# (Future: Install pre-commit hooks)

echo "✅ Setup complete! You are ready to build."
echo "👉 Run './scripts/scaffold-project.sh' to start a new client project."
