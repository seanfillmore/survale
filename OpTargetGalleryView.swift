//
//  OpTargetGalleryView.swift
//  Survale
//
//  Created by You on 10/18/25.
//

import SwiftUI
import PhotosUI

#if canImport(PhotosUI)
@available(iOS 16.0, *)
struct OpTargetGalleryView: View {
    @Binding var target: OpTarget
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var fullscreenIndex: Int? = nil

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 10, alignment: .top)]

    var body: some View {
        VStack(spacing: 12) {
            header
            if target.images.isEmpty {
                emptyState
            } else {
                grid
            }
        }
        .padding(.horizontal)
        .photosPicker(isPresented: .constant(false), selection: $selectedItems, maxSelectionCount: 20, matching: .images)
        .onChange(of: selectedItems) { _, newValue in
            Task {
                do {
                    #if canImport(PhotosUI)
                    if #available(iOS 16.0, *) {
                        let added = try await OpTargetImageManager.shared.importPhotos(newValue, into: target.id)
                        target.images.insert(contentsOf: added, at: 0)
                    }
                    #endif
                    selectedItems.removeAll()
                } catch {
                    print("Photo import failed: \(error)")
                }
            }
        }
        .sheet(item: Binding<FullscreenItem?>(
            get: {
                guard let i = fullscreenIndex, target.images.indices.contains(i) else { return nil }
                return FullscreenItem(index: i, id: target.images[i].id)
            },
            set: { fullscreenIndex = $0?.index }
        )) { item in
            FullscreenImagePager(
                images: target.images,
                startIndex: item.index,
                onDelete: { delete(at: $0) }
            )
        }
    }

    private var header: some View {
        HStack {
            Text("Images").font(.title3).bold()
            Spacer()
            PhotosPicker(selection: $selectedItems, maxSelectionCount: 20, matching: .images) {
                Label("Add", systemImage: "plus.circle.fill").font(.headline)
            }
            .buttonStyle(.borderless)
        }
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 42)).foregroundStyle(.secondary)
            Text("No images yet").font(.headline).foregroundStyle(.secondary)
            PhotosPicker(selection: $selectedItems, maxSelectionCount: 20, matching: .images) {
                Text("Select Photos")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(target.images.enumerated()), id: \.element.id) { index, media in
                    ThumbCell(media: media)
                        .onTapGesture { fullscreenIndex = index }
                        .contextMenu {
                            Button(role: .destructive) { delete(at: index) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func delete(at index: Int) {
        guard target.images.indices.contains(index) else { return }
        let img = target.images[index]
        OpTargetImageManager.shared.delete(img, targetID: target.id)
        target.images.remove(at: index)
    }


    private struct FullscreenItem: Identifiable { let index: Int; let id: UUID }
}

private struct ThumbCell: View {
    let media: OpTargetImage

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            thumbImageView

            if let date = media.createdAtFormatted {
                Text(date)
                    .font(.caption2).bold()
                    .padding(6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(6)
            }
        }
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private var thumbImageView: some View {
        if let path = media.thumbLocalPath,
           let ui = OpTargetImageManager.shared.loadImage(atRelativePath: path) {
            Image(uiImage: ui)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .frame(height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.quaternary) }
        } else if let path = media.localPath,
                  let ui = OpTargetImageManager.shared.loadImage(atRelativePath: path) {
            Image(uiImage: ui)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .frame(height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.quaternary) }
        } else if let url = media.remoteURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): 
                    img
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.quaternary) }
                case .failure: 
                    Image(systemName: "photo")
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.quaternary) }
                case .empty: 
                    ProgressView()
                        .frame(height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.quaternary) }
                @unknown default: 
                    Image(systemName: "photo")
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.quaternary) }
                }
            }
        } else {
            Image(systemName: "photo")
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .frame(height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.quaternary) }
        }
    }
}

private struct FullscreenImagePager: View {
    let images: [OpTargetImage]
    let startIndex: Int
    let onDelete: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var index: Int

    init(images: [OpTargetImage], startIndex: Int, onDelete: @escaping (Int) -> Void) {
        self.images = images
        self.startIndex = startIndex
        self.onDelete = onDelete
        _index = State(initialValue: startIndex)
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $index) {
                ForEach(Array(images.enumerated()), id: \.element.id) { i, media in
                    ZStack {
                        Color.black.ignoresSafeArea()
                        fullImage(for: media)
                            .scaledToFit()
                            .padding()
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .background(Color.black)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Label("Close", systemImage: "xmark.circle.fill").labelStyle(.titleAndIcon)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            onDelete(index)
                            if images.isEmpty { dismiss() }
                        } label: {
                            Label("Delete Photo", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func fullImage(for media: OpTargetImage) -> some View {
        if let path = media.localPath,
           let ui = OpTargetImageManager.shared.loadImage(atRelativePath: path) {
            Image(uiImage: ui).renderingMode(.original)
        } else if let url = media.remoteURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img
                case .failure: Image(systemName: "photo")
                case .empty: ProgressView()
                @unknown default: Image(systemName: "photo")
                }
            }
        } else {
            Image(systemName: "photo")
        }
    }
}
#endif
