#!/bin/bash

# Check for duplicate file references in Xcode project

echo "Checking for duplicate EditOperationView.swift references..."
echo ""

grep -n "EditOperationView.swift" Survale.xcodeproj/project.pbxproj

echo ""
echo "If you see multiple lines above, EditOperationView.swift is referenced multiple times."
echo ""
echo "To fix:"
echo "1. Open Xcode"
echo "2. Go to Project Navigator"
echo "3. Find all instances of EditOperationView.swift"
echo "4. Remove duplicates (Remove Reference, not Move to Trash)"
echo "5. Product → Clean Build Folder (Cmd+Shift+K)"
echo "6. Rebuild"

