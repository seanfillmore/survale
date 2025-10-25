# Target Image Gallery Setup Guide

## 🎯 Overview
This guide will help you set up the image gallery feature for targets, allowing users to:
- Upload multiple photos for each target
- View photos in a gallery
- Zoom and swipe through photos
- Delete photos

## ✅ What's Been Implemented

### 1. **Supabase Storage Service** (`SupabaseStorageService.swift`)
- Upload images to Supabase Storage
- Download images from URLs
- Delete images
- Automatic compression (80% JPEG quality)

### 2. **Image Picker Component** (`TargetImagePicker.swift`)
- PhotosUI integration (iOS 16+)
- Multiple image selection (up to 10)
- Thumbnail gallery view
- Upload progress indicator
- Delete functionality

### 3. **Full-Screen Gallery** (`TargetImageGalleryView.swift`)
- Swipeable image viewer
- Pinch-to-zoom support
- Double-tap to reset zoom
- Share functionality
- Dark mode UI

### 4. **Database Integration**
- RPC functions updated to handle image arrays
- Images stored as JSONB in target `data` field
- `rpc_update_target_images()` for adding/removing images after creation

## 🚀 Setup Instructions

### Step 1: Run Database Script
Open your Supabase SQL Editor and run:

```sql
\i /path/to/Docs/setup_storage_bucket.sql
```

Or copy/paste the contents of `setup_storage_bucket.sql`.

This will:
- Create the `target-images` bucket
- Set up storage policies for upload/download/delete
- Enable public read access

### Step 2: Update RPC Functions
Run the SQL script:

```sql
\i /path/to/Docs/add_images_to_targets.sql
```

This updates:
- `rpc_create_person_target` - adds `images` parameter
- `rpc_create_vehicle_target` - adds `images` parameter
- `rpc_create_location_target` - adds `images` parameter
- Adds new `rpc_update_target_images` function

### Step 3: Add Files to Xcode Project
⚠️ **IMPORTANT**: These new files need to be added to your Xcode project:

1. **Services/SupabaseStorageService.swift**
2. **Views/TargetImagePicker.swift**
3. **Views/TargetImageGalleryView.swift**

**To add them:**
1. Open your Xcode project
2. Right-click on the appropriate folder (Services or Views)
3. Select "Add Files to Survale..."
4. Select the files
5. Make sure "Add to targets: Survale" is checked
6. Click "Add"

### Step 4: Integrate Image Picker into Target Forms
The `TargetImagePicker` component needs to be added to your target creation/editing forms.

Example integration:

```swift
// In CreateOperationView.swift (Targets step)
struct PersonTargetForm: View {
    @Binding var target: OpTarget
    
    var body: some View {
        Form {
            TextField("First Name", text: $target.personFirstName ?? "")
            TextField("Last Name", text: $target.personLastName ?? "")
            TextField("Phone", text: $target.personPhone ?? "")
            
            // Add image picker
            if #available(iOS 16.0, *) {
                TargetImagePicker(
                    images: $target.images,
                    targetId: target.id
                )
            }
        }
    }
}
```

### Step 5: Display Gallery
To view images in full screen:

```swift
struct TargetDetailView: View {
    let target: OpTarget
    @State private var showingGallery = false
    
    var body: some View {
        VStack {
            // Thumbnail view
            if !target.images.isEmpty {
                Button {
                    showingGallery = true
                } label: {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("\(target.images.count) photo(s)")
                    }
                }
            }
        }
        .sheet(isPresented: $showingGallery) {
            if #available(iOS 16.0, *) {
                TargetImageGalleryView(images: target.images)
            }
        }
    }
}
```

## 📝 How It Works

### Image Upload Flow
1. User selects photos from PhotosUI picker
2. Images are compressed to JPEG (80% quality)
3. Each image uploaded to Supabase Storage: `target-images/targets/{targetId}/{imageId}.jpg`
4. Public URL returned
5. `OpTargetImage` created with URL and metadata
6. Added to target's `images` array

### Image Storage Format (Database)
Images are stored in the target's `data` JSONB field:

```json
{
  "first_name": "John",
  "last_name": "Doe",
  "phone": "555-1234",
  "images": [
    {
      "id": "uuid-here",
      "storage_kind": "remoteURL",
      "remote_url": "https://xxx.supabase.co/storage/v1/object/public/target-images/...",
      "filename": "uuid.jpg",
      "pixel_width": 1920,
      "pixel_height": 1080,
      "byte_size": 245678,
      "created_at": "2025-10-19T12:00:00Z",
      "caption": null
    }
  ]
}
```

### Image Deletion Flow
1. User taps delete button on thumbnail
2. Image deleted from Supabase Storage
3. Removed from target's `images` array
4. Call `SupabaseRPCService.updateTargetImages()` to sync with database

## 🎨 UI Features

### Image Picker
- Horizontal scrollable thumbnail gallery
- Empty state with icon
- Upload progress indicator
- Delete button on each thumbnail (red X)
- Max 10 images per selection

### Full-Screen Gallery
- TabView with page indicators
- Pinch-to-zoom (1x to 4x)
- Double-tap to reset zoom
- Swipe between images
- Dark mode
- Share button
- Close button

## 🔒 Security & Permissions

### Storage Policies
- **Upload**: Authenticated users only
- **Read**: Public (anyone with URL can view)
- **Update**: Authenticated users (same operation members)
- **Delete**: Authenticated users (same operation members)

### App Permissions
Photos access is already configured in `Info.plist`:
- `NSPhotoLibraryUsageDescription`

## 🐛 Troubleshooting

### Images not uploading?
1. Check Supabase Storage bucket exists: `target-images`
2. Verify storage policies are set up
3. Check network logs in Xcode console
4. Ensure user is authenticated

### Images not displaying?
1. Verify image URLs are valid
2. Check `remoteURL` is set in `OpTargetImage`
3. Look for download errors in console
4. Test URL in browser (should be publicly accessible)

### "Failed to add files to project" in Xcode?
1. Make sure files are saved in the correct directory
2. Use "Add Files to Survale..." not "New File"
3. Verify target membership is checked

## 📱 iOS Version Support
The image gallery requires **iOS 16.0+** for:
- `PhotosUI` framework
- `PhotosPickerItem` API

For older iOS versions, a fallback UI or alternative picker would be needed.

## ✅ Testing Checklist
- [ ] Run `setup_storage_bucket.sql` in Supabase
- [ ] Run `add_images_to_targets.sql` in Supabase
- [ ] Add 3 new Swift files to Xcode project
- [ ] Integrate `TargetImagePicker` into target forms
- [ ] Test uploading 1 image
- [ ] Test uploading multiple images (5+)
- [ ] Test viewing images in gallery
- [ ] Test pinch-to-zoom
- [ ] Test deleting an image
- [ ] Verify images persist after app restart
- [ ] Test on physical device (simulator may have photo picker issues)

## 🎉 You're Done!
Once all steps are complete, users will be able to add photos to targets during creation and view them in a beautiful full-screen gallery!

