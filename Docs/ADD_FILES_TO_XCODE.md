# Add New Files to Xcode Project

## Issue
The new files created for the location assignment feature are not in the Xcode project, causing linter errors:
- `Models/AssignmentModels.swift`
- `Services/AssignmentService.swift`
- `Views/AssignLocationSheet.swift`
- `Views/AssignmentBanner.swift`
- `Views/AssignmentDetailView.swift`

## Solution

### Option 1: Add Files in Xcode (Recommended)

1. **Open Xcode:**
   ```bash
   open /Users/seanfillmore/Code/Survale/Survale/Survale.xcodeproj
   ```

2. **For Each New File:**
   - In Xcode's Project Navigator (left sidebar), right-click on the appropriate folder
   - Select "Add Files to 'Survale'..."
   - Navigate to the file location
   - **IMPORTANT:** Make sure "Copy items if needed" is UNCHECKED (files are already in place)
   - **IMPORTANT:** Make sure "Add to targets" has "Survale" CHECKED
   - Click "Add"

3. **Files to Add:**

   **Models Folder:**
   - `Models/AssignmentModels.swift`

   **Services Folder:**
   - `Services/AssignmentService.swift`

   **Views Folder:**
   - `Views/AssignLocationSheet.swift`
   - `Views/AssignmentBanner.swift`
   - `Views/AssignmentDetailView.swift`

4. **Verify:**
   - Files should appear in blue in Project Navigator (not gray/red)
   - Build the project (⌘B)
   - Linter errors should disappear

### Option 2: Use Terminal Command

Alternatively, you can use `xcodebuild` to add files, but it's more complex.

### After Adding Files

1. **Clean Build Folder:**
   - In Xcode: Product → Clean Build Folder (⇧⌘K)

2. **Rebuild:**
   - Product → Build (⌘B)

3. **Verify No Errors:**
   - Check the Issue Navigator (⌘5)
   - Should see 0 errors

### Quick Verification

Run this in terminal to check if files are in the project:
```bash
cd /Users/seanfillmore/Code/Survale/Survale
grep -c "AssignmentModels.swift" Survale.xcodeproj/project.pbxproj
# Should return a number > 0 if file is added
```

## Why This Happened

Git tracks files, but Xcode projects need files explicitly added to the `project.pbxproj` file. When creating new Swift files outside of Xcode, they need to be manually added to the project.

## Alternative: Create Files in Xcode Next Time

To avoid this in the future:
1. Right-click folder in Xcode
2. Select "New File..."
3. Choose "Swift File"
4. This automatically adds it to the project

