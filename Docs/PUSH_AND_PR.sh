#!/bin/bash

# Push and Create Pull Request for Operation Screen Changes
# Run this script from the project root

set -e  # Exit on error

echo "🚀 Pushing feature/op-screen-changes to GitHub..."
git push origin feature/op-screen-changes

echo ""
echo "✅ Branch pushed successfully!"
echo ""
echo "📝 Creating Pull Request..."
echo ""

# Check if GitHub CLI is installed
if command -v gh &> /dev/null; then
    echo "Using GitHub CLI to create PR..."
    gh pr create \
      --base main \
      --head feature/op-screen-changes \
      --title "Feature: Operation Screen UX Improvements" \
      --body "# Operation Screen UX Improvements

## 🎯 Overview
This PR introduces significant UX improvements to the Operations screen and operation management workflows.

## ✨ Features
- Direct Operation Details Display
- Transfer Operation (Case Agent)
- Leave Operation (Team Members)  
- End Operation (Case Agent)
- Clone Operation (Ended Operations) ⭐
- Hide Chat Input when no active operation

## 📊 Database Changes
**Required:** Run \`Docs/transfer_and_leave_operation.sql\` in Supabase

## 🧪 Testing
All features tested and confirmed working ✅

## 📚 Documentation
See \`Docs/OP_SCREEN_CHANGES_SUMMARY.md\` for complete details

**Ready for production deployment!** 🎉"
    
    echo ""
    echo "✅ Pull Request created!"
else
    echo "GitHub CLI not found. Please create PR manually:"
    echo ""
    echo "1. Go to: https://github.com/seanfillmore/Survale"
    echo "2. Click 'Compare & pull request' button"
    echo "3. Copy content from: Docs/CREATE_PULL_REQUEST.md"
    echo ""
fi

echo ""
echo "🎉 Done!"

