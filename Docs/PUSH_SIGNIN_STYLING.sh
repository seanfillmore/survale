#!/bin/bash

# Sign-In Screen Styling Feature - Push and Merge Script
# Branch: feature/signin-screen-styling

set -e  # Exit on error

BRANCH_NAME="feature/signin-screen-styling"
REPO_DIR="/Users/seanfillmore/Code/Survale/Survale"

cd "$REPO_DIR"

echo "=========================================="
echo "🎨 Pushing Sign-In Styling Feature"
echo "=========================================="
echo ""
echo "Branch: $BRANCH_NAME"
echo ""
echo "Features:"
echo "  ✅ Modern sign-in screen redesign"
echo "  ✅ Animated splash screen with progress"
echo "  ✅ Custom logo integration"
echo "  ✅ Static launch screen setup"
echo ""

# Step 1: Push branch to GitHub
echo "📤 Step 1: Pushing branch to GitHub..."
git push origin "$BRANCH_NAME"
echo "✅ Branch pushed successfully"
echo ""

# Step 2: Provide pull request info
echo "=========================================="
echo "✅ PUSH COMPLETE!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "  1. Go to GitHub repository"
echo "  2. Create Pull Request from $BRANCH_NAME to main"
echo "  3. Review changes and merge"
echo ""
echo "Summary:"
echo "  • Modern sign-in screen with gradient design"
echo "  • Custom text fields with icons"
echo "  • Animated splash screen (1.5s with progress)"
echo "  • Static launch screen configured"
echo "  • No more blank white screen!"
echo ""
echo "Commits: 6"
echo "Documentation: SIGNIN_STYLING_SUMMARY.md"
echo ""

