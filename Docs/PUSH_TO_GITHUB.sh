#!/bin/bash

# ============================================
# Push Survale to GitHub
# ============================================
# Quick script to initialize and push to GitHub
# Run this from the Survale project root
# ============================================

echo "🚀 Survale GitHub Setup"
echo "======================="
echo ""

# Check if we're in the right directory
if [ ! -f "Survale.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Not in Survale project directory"
    echo "Please cd to: /Users/seanfillmore/Code/Survale/Survale"
    exit 1
fi

echo "📁 Current directory: $(pwd)"
echo ""

# Check if .gitignore exists
if [ ! -f ".gitignore" ]; then
    echo "⚠️  Warning: .gitignore not found"
    echo "Creating .gitignore..."
    # Create .gitignore (file already created above)
fi

# Initialize git if needed
if [ ! -d ".git" ]; then
    echo "📦 Initializing Git repository..."
    git init
    echo "✅ Git initialized"
else
    echo "✅ Git already initialized"
fi

# Check if remote exists
if git remote | grep -q "origin"; then
    echo "✅ Remote 'origin' already exists"
else
    echo "🔗 Adding GitHub remote..."
    git remote add origin https://github.com/seanfillmore/survale.git
    echo "✅ Remote added"
fi

echo ""
echo "📊 Current Git Status:"
git status --short

echo ""
read -p "📝 Do you want to stage all files? (y/n): " stage
if [ "$stage" = "y" ]; then
    echo "➕ Staging files..."
    git add .
    echo "✅ Files staged"
    
    echo ""
    echo "📋 Staged files:"
    git status --short
    
    echo ""
    read -p "💬 Enter commit message (or press Enter for default): " commit_msg
    
    if [ -z "$commit_msg" ]; then
        commit_msg="Update Survale app - $(date +'%Y-%m-%d %H:%M')"
    fi
    
    echo "💾 Committing..."
    git commit -m "$commit_msg"
    echo "✅ Committed"
    
    echo ""
    read -p "🚀 Push to GitHub? (y/n): " push
    if [ "$push" = "y" ]; then
        echo "📤 Pushing to GitHub..."
        
        # Check if main branch exists
        if git show-ref --verify --quiet refs/heads/main; then
            git push -u origin main
        else
            git branch -M main
            git push -u origin main
        fi
        
        echo ""
        echo "✅ Successfully pushed to GitHub!"
        echo "🔗 View at: https://github.com/seanfillmore/survale"
    fi
fi

echo ""
echo "✨ Done!"

