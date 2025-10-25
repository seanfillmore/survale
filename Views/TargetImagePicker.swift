//
//  TargetImagePicker.swift
//  Survale
//
//  Photo picker for target images
//

import SwiftUI
import PhotosUI

@available(iOS 16.0, *)
struct TargetImagePicker: View {
    @Binding var images: [OpTargetImage]
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var errorMessage: String?
    
    let targetId: UUID
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with add button
            HStack {
                Text("Photos")
                    .font(.headline)
                
                Spacer()
                
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    Label("Add Photos", systemImage: "photo.badge.plus")
                        .font(.subheadline)
                }
                .disabled(isUploading)
            }
            
            // Image gallery
            if !images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(images) { image in
                            TargetImageThumbnail(
                                image: image,
                                onDelete: {
                                    deleteImage(image)
                                }
                            )
                        }
                    }
                }
                .frame(height: 120)
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No photos yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            // Upload progress
            if isUploading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Uploading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onChange(of: selectedItems) { oldValue, newValue in
            Task {
                await uploadSelectedImages()
            }
        }
    }
    
    // MARK: - Upload Images
    
    private func uploadSelectedImages() async {
        guard !selectedItems.isEmpty else { return }
        
        isUploading = true
        errorMessage = nil
        
        for item in selectedItems {
            do {
                // Load image data
                guard let data = try await item.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data) else {
                    continue
                }
                
                // Upload to Supabase Storage
                let imageId = UUID()
                let url = try await SupabaseStorageService.shared.uploadImage(
                    uiImage,
                    targetId: targetId,
                    imageId: imageId
                )
                
                // Create OpTargetImage
                let targetImage = OpTargetImage(
                    id: imageId,
                    storageKind: .remoteURL,
                    localPath: nil,
                    remoteURL: url,
                    filename: "\(imageId.uuidString).jpg",
                    pixelWidth: Int(uiImage.size.width),
                    pixelHeight: Int(uiImage.size.height),
                    byteSize: data.count,
                    createdAt: Date(),
                    caption: nil
                )
                
                // Add to images array
                await MainActor.run {
                    images.append(targetImage)
                }
                
                print("✅ Image uploaded and added to target")
                
            } catch {
                print("❌ Failed to upload image: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to upload image"
                }
            }
        }
        
        await MainActor.run {
            isUploading = false
            selectedItems = []
        }
    }
    
    // MARK: - Delete Image
    
    private func deleteImage(_ image: OpTargetImage) {
        Task {
            do {
                // Delete from Supabase Storage
                if let url = image.remoteURL {
                    try await SupabaseStorageService.shared.deleteImage(at: url)
                }
                
                // Remove from images array
                await MainActor.run {
                    images.removeAll { $0.id == image.id }
                }
                
                print("✅ Image deleted")
            } catch {
                print("❌ Failed to delete image: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to delete image"
                }
            }
        }
    }
}

// MARK: - Image Thumbnail

@available(iOS 16.0, *)
struct TargetImageThumbnail: View {
    let image: OpTargetImage
    let onDelete: () -> Void
    
    @State private var uiImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Image
            Group {
                if let uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 100, height: 100)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .background(Circle().fill(.red))
            }
            .offset(x: 8, y: -8)
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            if let url = image.remoteURL {
                let downloaded = try await SupabaseStorageService.shared.downloadImage(from: url)
                await MainActor.run {
                    self.uiImage = downloaded
                }
            } else if let localPath = image.localPath {
                let manager = OpTargetImageManager.shared
                await MainActor.run {
                    self.uiImage = manager.loadImage(atRelativePath: localPath)
                }
            }
        } catch {
            print("❌ Failed to load image: \(error)")
        }
    }
}

