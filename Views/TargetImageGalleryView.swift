//
//  TargetImageGalleryView.swift
//  Survale
//
//  Full-screen image gallery for viewing target images
//

import SwiftUI

@available(iOS 16.0, *)
struct TargetImageGalleryView: View {
    let images: [OpTargetImage]
    @State private var selectedIndex: Int = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                TabView(selection: $selectedIndex) {
                    ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                        ImageDetailView(image: image)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
            .navigationTitle("Photo \(selectedIndex + 1) of \(images.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Image Detail View

@available(iOS 16.0, *)
struct ImageDetailView: View {
    let image: OpTargetImage
    @State private var uiImage: UIImage?
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    // Limit zoom
                                    if scale < 1.0 {
                                        withAnimation {
                                            scale = 1.0
                                        }
                                    } else if scale > 4.0 {
                                        withAnimation {
                                            scale = 4.0
                                        }
                                    }
                                    lastScale = scale
                                }
                        )
                        .onTapGesture(count: 2) {
                            // Double tap to reset zoom
                            withAnimation {
                                scale = 1.0
                                lastScale = 1.0
                            }
                        }
                } else if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                        Text("Loading...")
                            .foregroundStyle(.white)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("Failed to load image")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            // Ignore cancellation errors (normal when swiping between images)
            if (error as NSError).code != NSURLErrorCancelled {
                print("❌ Failed to load image: \(error)")
            }
        }
    }
}

