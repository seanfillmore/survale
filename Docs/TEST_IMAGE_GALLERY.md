# 🧪 Quick Test: Image Gallery

## ⚡ 2-Minute Test

### Prerequisites
✅ You completed Steps 1 & 2:
- ✅ Ran `setup_storage_bucket.sql` in Supabase
- ✅ Ran `add_images_to_targets.sql` in Supabase  
- ✅ Added 3 files to Xcode project

### Integration
✅ Automatically done:
- ✅ `TargetImagePicker` added to all target forms
- ✅ `OperationStore` updated to save images
- ✅ No linter errors

## 🎯 Quick Test Steps

1. **Build & Run** the app
2. **Create new operation**
3. **Go to Targets step**
4. **Select "Person"**
5. **Enter name:** "Test Person"
6. **Scroll down** to see "Photos" section
7. **Tap "Add Photos"**
8. **Select 2-3 images** from Photos
9. **Watch upload progress**
10. **See thumbnails appear**
11. **Tap ❌** on one thumbnail to delete
12. **Tap "Add Target"**
13. **Continue through steps** and complete operation
14. **Check Xcode console** for:
    ```
    ✅ Image uploaded successfully
    ✅ Saved target: Test Person (2 image(s))
    ```

## ✅ Success Criteria

- [ ] Photos picker opens
- [ ] Multiple images can be selected
- [ ] Upload progress shows
- [ ] Thumbnails appear in horizontal scroll
- [ ] Delete (❌) button works
- [ ] Target saves with images
- [ ] Console shows upload success
- [ ] Console shows target saved with image count

## 🐛 Troubleshooting

### "Add Photos" button doesn't work
- Make sure you added `TargetImagePicker.swift` to Xcode project
- Check for build errors in Xcode

### Images don't upload
- Verify `setup_storage_bucket.sql` was run
- Check Supabase dashboard → Storage → Buckets → `target-images`
- Look for error messages in console

### "Failed to save target"
- Verify `add_images_to_targets.sql` was run
- Check RPC function exists: `rpc_create_person_target` with `images` parameter

### Thumbnails don't show
- Images might still be uploading - wait a moment
- Check console for "Image uploaded successfully"
- Try with smaller images first

## 📸 What You Should See

### Photos Section (Empty State)
```
┌──────────────────────────────┐
│   Photos                     │
│   [Add Photos] button        │
│   ┌────────────────────────┐ │
│   │    📷                  │ │
│   │  No photos yet         │ │
│   └────────────────────────┘ │
└──────────────────────────────┘
```

### Photos Section (With Images)
```
┌──────────────────────────────┐
│   Photos        [Add Photos] │
│                              │
│   ╔═══╗  ╔═══╗  ╔═══╗       │
│   ║ ❌║  ║ ❌║  ║ ❌║       │
│   ║   ║  ║   ║  ║   ║       │
│   ║IMG║  ║IMG║  ║IMG║  ──►  │
│   ╚═══╝  ╚═══╝  ╚═══╝       │
│                              │
└──────────────────────────────┘
```

## 🎊 Next Steps

Once basic upload/display works:
1. Test with vehicle targets
2. Test with location targets
3. Test creating operation with multiple targets with images
4. Verify images persist (check Supabase Storage dashboard)
5. Test deleting images before adding target

## 📞 Need Help?

If something doesn't work:
1. Check Xcode console for errors
2. Verify all 3 files are in project and building
3. Verify both SQL scripts ran successfully
4. Take screenshot of error and share

**The feature is ready - happy testing!** 🚀

