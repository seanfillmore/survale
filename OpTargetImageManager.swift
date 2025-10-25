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
    private init() {}

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

    func loadImage(atRelativePath relPath: String) -> UIImage? {
        let key = relPath as NSString
        if let cached = cache.object(forKey: key) { return cached }
        do {
            let absURL = try absoluteURL(forRelativePath: relPath)
            guard let img = UIImage(contentsOfFile: absURL.path) else { return nil }
            cache.setObject(img, forKey: key)
            return img
        } catch { return nil }
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
