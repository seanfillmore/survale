#!/bin/bash

# Performance Bugfix Branch Merge Script
# Branch: bugfix/settings-button-always-active

set -e  # Exit on error

BRANCH_NAME="bugfix/settings-button-always-active"
REPO_DIR="/Users/seanfillmore/Code/Survale/Survale"

cd "$REPO_DIR"

echo "=========================================="
echo "🚀 Merging Performance Bugfix Branch"
echo "=========================================="
echo ""
echo "Branch: $BRANCH_NAME"
echo "Fixes:"
echo "  ✅ Settings button always active"
echo "  ✅ Login screen 5-7 second lag"
echo "  ✅ Settings field navigation lag"
echo ""

# Step 1: Push branch to GitHub
echo "📤 Step 1: Pushing branch to GitHub..."
git push origin "$BRANCH_NAME"
echo "✅ Branch pushed successfully"
echo ""

# Step 2: Switch to main and pull latest
echo "🔄 Step 2: Switching to main branch..."
git checkout main
echo "✅ Switched to main"
echo ""

echo "📥 Step 3: Pulling latest changes from main..."
git pull origin main
echo "✅ Main branch updated"
echo ""

# Step 3: Merge the bugfix branch
echo "🔀 Step 4: Merging $BRANCH_NAME into main..."
git merge "$BRANCH_NAME" --no-ff -m "Merge: Performance bugfix - eliminate 5-7s delays and text field lag

Fixes:
- Settings button always active when no changes made
- Login screen 5-7 second keyboard lag (critical)
- Settings field navigation lag

Performance improvements:
✅ Instant login field response
✅ Smooth settings navigation
✅ Cached validation (no regex on every keystroke)
✅ Optimized view hierarchy

Branch: $BRANCH_NAME
Commits: 5 (see PERFORMANCE_BUGFIX_SUMMARY.md)"

echo "✅ Branch merged successfully"
echo ""

# Step 4: Push merged main
echo "📤 Step 5: Pushing merged main to GitHub..."
git push origin main
echo "✅ Main branch pushed"
echo ""

# Step 5: Delete local branch (optional)
echo "🗑️  Step 6: Cleaning up local branch..."
git branch -d "$BRANCH_NAME"
echo "✅ Local branch deleted"
echo ""

echo "=========================================="
echo "✅ MERGE COMPLETE!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  • Branch merged to main"
echo "  • Changes pushed to GitHub"
echo "  • Local branch cleaned up"
echo ""
echo "Next: Delete remote branch on GitHub if desired:"
echo "  git push origin --delete $BRANCH_NAME"
echo ""

