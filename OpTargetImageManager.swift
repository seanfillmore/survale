//
//  OpTargetImageManager.swift
//  Survale
//
//  Created by You on 10/18/25.
//

import Foundation
import UIKit
import Combine

#if canImport(PhotosUI)
import PhotosUI
#endif

@MainActor
final class OpTargetImageManager: ObservableObject {
    static let shared = OpTargetImageManager()

    private let fm = FileManager.default
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        // Configure cache limits to prevent memory issues
        cache.countLimit = 20  // Max 20 images in memory
        cache.totalCostLimit = 50 * 1024 * 1024  // 50MB maximum cache size
        
        print("✅ OpTargetImageManager: Cache configured with limits")
        print("   Count limit: 20 images")
        print("   Size limit: 50MB")
    }

    // MARK: - Paths

    /// Documents/Media/Targets/<target-id>/
    private func targetFolder(targetID: UUID) throws -> URL {
        let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let base = docs.appendingPathComponent("Media/Targets/\(targetID.uuidString)", isDirectory: true)
        if !fm.fileExists(atPath: base.path) {
            try fm.createDirectory(at: base, withIntermediateDirectories: true, attributes: nil)
        }
        return base
    }

    private func writeJPEG(_ image: UIImage, to url: URL, quality: CGFloat = 0.85) throws {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw NSError(domain: "OpTargetImageManager", code: 1001,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to encode JPEG"])
        }
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Loading

    /// Load an image with automatic downsampling to prevent memory issues
    /// - Parameters:
    ///   - relPath: Relative path to the image
    ///   - maxSize: Maximum size in pixels (default 1920x1920)
    /// - Returns: Downsampled UIImage or nil if loading fails
    func loadImage(atRelativePath relPath: String, maxSize: CGSize = CGSize(width: 1920, height: 1920)) -> UIImage? {
        // Create unique cache key based on path and size
        let key = "\(relPath)-\(Int(maxSize.width))" as NSString
        
        // Check cache first
        if let cached = cache.object(forKey: key) {
            return cached
        }
        
        do {
            let absURL = try absoluteURL(forRelativePath: relPath)
            
            // Downsample image to max size (much more memory efficient than loading full size)
            guard let downsampledImage = downsampleImage(at: absURL, to: maxSize) else {
                return nil
            }
            
            // Calculate cost for cache (approximate memory usage)
            let cost = Int(downsampledImage.size.width * downsampledImage.size.height * 4) // 4 bytes per pixel (RGBA)
            cache.setObject(downsampledImage, forKey: key, cost: cost)
            
            return downsampledImage
        } catch {
            print("❌ Failed to load image at \(relPath): \(error)")
            return nil
        }
    }
    
    /// Efficiently downsample an image without loading full resolution into memory
    /// Uses ImageIO for memory-efficient downsampling
    private func downsampleImage(at url: URL, to size: CGSize) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,  // Don't cache during downsampling
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height)
        ]
        
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            // Fallback to traditional loading if downsampling fails
            return UIImage(contentsOfFile: url.path)
        }
        
        return UIImage(cgImage: cgImage)
    }

    func absoluteURL(forRelativePath relPath: String) throws -> URL {
        let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return docs.appendingPathComponent(relPath)
    }

    // MARK: - Import

    #if canImport(PhotosUI)
    @available(iOS 16.0, *)
    func importPhotos(_ items: [Any], into targetID: UUID) async throws -> [OpTargetImage] {
        // TODO: Implement photo import when PhotosPickerItem is available
        // For now, return empty array to avoid compile-time type resolution issues
        return []
    }
    #else
    // Fallback for older iOS versions - return empty array
    func importPhotos(_ items: [Any], into targetID: UUID) async throws -> [OpTargetImage] {
        return []
    }
    #endif

    // MARK: - Delete

    func delete(_ image: OpTargetImage, targetID: UUID) {
        if let rel = image.localPath {
            if let abs = try? absoluteURL(forRelativePath: rel), fm.fileExists(atPath: abs.path) {
                try? fm.removeItem(at: abs)
            }
            cache.removeObject(forKey: (rel as NSString))
        }
        if let thumb = image.thumbLocalPath {
            if let abs = try? absoluteURL(forRelativePath: thumb), fm.fileExists(atPath: abs.path) {
                try? fm.removeItem(at: abs)
            }
            cache.removeObject(forKey: (thumb as NSString))
        }
    }
}

private extension UIImage {
    func resizedMaintainingAspect(maxWidth: CGFloat) -> UIImage {
        guard size.width > maxWidth else { return self }
        let scale = maxWidth / size.width
        let newSize = CGSize(width: maxWidth, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}
