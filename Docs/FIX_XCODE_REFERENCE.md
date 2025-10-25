# Fix Xcode Build Error - JoinOperationView

## Error
```
Build input file cannot be found: '/Users/seanfillmore/Code/Survale/Survale/Views/JoinOperationView.swift'
```

## Cause
The file was deleted from the filesystem, but Xcode still has a reference to it in the project file.

## Solution

### Option 1: Remove via Xcode (Recommended)
1. In Xcode, look in the Project Navigator (left sidebar)
2. Find `Views/JoinOperationView.swift` (it will be red/missing)
3. Right-click on it
4. Select **"Delete"** 
5. In the dialog, choose **"Remove Reference"** (NOT "Move to Trash" since file is already gone)
6. Clean build folder: `Cmd+Shift+K`
7. Build again: `Cmd+B`

### Option 2: If You Don't See the File in Xcode
The file might already be removed from the navigator but still referenced in build phases.

1. Click on the **Survale project** (blue icon at top of navigator)
2. Select the **Survale target** 
3. Go to **Build Phases** tab
4. Expand **"Compile Sources"**
5. Look for `JoinOperationView.swift`
6. If found, select it and click the **minus (−)** button
7. Clean: `Cmd+Shift+K`
8. Build: `Cmd+B`

### Option 3: Manual Edit (Advanced)
If the above don't work, edit the project file directly:

1. Close Xcode
2. Open `Survale.xcodeproj/project.pbxproj` in a text editor
3. Search for `JoinOperationView.swift`
4. Delete all lines containing this filename
5. Save the file
6. Reopen in Xcode
7. Clean and build

## Why This Happened
When files are deleted outside of Xcode (via terminal, Cursor, etc.), Xcode doesn't know about it. The project file (`.pbxproj`) still contains references to the deleted file.

## Prevention
Always delete files through Xcode's interface:
- Right-click → Delete → Move to Trash

Or if deleting outside Xcode, immediately remove the reference in Xcode.

---

**After fixing, the build should succeed!** ✅

