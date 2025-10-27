//
//  SupabaseStorageService.swift
//  Survale
//
//  Manages image uploads/downloads to Supabase Storage
//

import Foundation
import UIKit
import Supabase

final class SupabaseStorageService {
    static let shared = SupabaseStorageService()
    
    private let client: SupabaseClient
    private let bucketName = "target-images"
    
    private init() {
        // Use shared client instance to reduce overhead
        self.client = SupabaseClientManager.shared.supabase
    }
    
    // MARK: - Upload Image
    
    /// Upload an image to Supabase Storage
    /// Returns the public URL of the uploaded image
    func uploadImage(_ image: UIImage, targetId: UUID, imageId: UUID) async throws -> URL {
        // Compress image to JPEG
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.compressionFailed
        }
        
        // Create file path: targets/{targetId}/{imageId}.jpg
        let filePath = "targets/\(targetId.uuidString)/\(imageId.uuidString).jpg"
        
        print("📤 Uploading image to: \(filePath) (\(imageData.count) bytes)")
        
        do {
            // Upload to Supabase Storage
            _ = try await client.storage
                .from(bucketName)
                .upload(
                    path: filePath,
                    file: imageData,
                    options: FileOptions(cacheControl: "3600", upsert: true)
                )
            
            // Get public URL
            let publicURL = try client.storage
                .from(bucketName)
                .getPublicURL(path: filePath)
            
            print("✅ Image uploaded successfully: \(publicURL.absoluteString)")
            return publicURL
        } catch {
            print("❌ Failed to upload image: \(error)")
            throw StorageError.uploadFailed(error)
        }
    }
    
    /// Upload raw data to a specific bucket and path
    /// Returns the storage path (not the public URL)
    func uploadImage(data: Data, bucket: String, path: String) async throws -> String {
        print("📤 Uploading data to \(bucket)/\(path) (\(data.count) bytes)")
        
        do {
            _ = try await client.storage
                .from(bucket)
                .upload(
                    path: path,
                    file: data,
                    options: FileOptions(cacheControl: "3600", upsert: true)
                )
            
            print("✅ Data uploaded successfully to: \(path)")
            return path
        } catch {
            print("❌ Failed to upload data: \(error)")
            throw StorageError.uploadFailed(error)
        }
    }
    
    // MARK: - Download Image
    
    /// Download an image from Supabase Storage
    func downloadImage(from url: URL) async throws -> UIImage {
        print("📥 Downloading image from: \(url.absoluteString)")
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            guard let image = UIImage(data: data) else {
                throw StorageError.invalidImageData
            }
            
            print("✅ Image downloaded successfully")
            return image
        } catch {
            print("❌ Failed to download image: \(error)")
            throw StorageError.downloadFailed(error)
        }
    }
    
    /// Download an image from a specific bucket and path
    func downloadImage(from path: String, bucket: String) async throws -> UIImage {
        print("📥 Downloading image from \(bucket)/\(path)")
        
        do {
            let data = try await client.storage
                .from(bucket)
                .download(path: path)
            
            guard let image = UIImage(data: data) else {
                throw StorageError.invalidImageData
            }
            
            print("✅ Image downloaded successfully")
            return image
        } catch {
            print("❌ Failed to download image: \(error)")
            throw StorageError.downloadFailed(error)
        }
    }
    
    // MARK: - Delete Image
    
    /// Delete an image from Supabase Storage
    func deleteImage(at url: URL) async throws {
        // Extract file path from URL
        // URL format: https://{project}.supabase.co/storage/v1/object/public/target-images/targets/{targetId}/{imageId}.jpg
        guard let path = extractStoragePath(from: url) else {
            throw StorageError.invalidURL
        }
        
        print("🗑️ Deleting image at: \(path)")
        
        do {
            try await client.storage
                .from(bucketName)
                .remove(paths: [path])
            
            print("✅ Image deleted successfully")
        } catch {
            print("❌ Failed to delete image: \(error)")
            throw StorageError.deleteFailed(error)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Extract storage path from public URL
    /// e.g., "https://abc.supabase.co/storage/v1/object/public/target-images/targets/123/456.jpg"
    /// returns "targets/123/456.jpg"
    private func extractStoragePath(from url: URL) -> String? {
        let urlString = url.absoluteString
        
        // Find the bucket name in the URL
        guard let bucketRange = urlString.range(of: "/\(bucketName)/") else {
            return nil
        }
        
        // Extract everything after the bucket name
        let startIndex = bucketRange.upperBound
        return String(urlString[startIndex...])
    }
    
    /// Get the size of an image file
    func getImageSize(at url: URL) async throws -> Int {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data.count
    }
}

// MARK: - Errors

enum StorageError: LocalizedError {
    case compressionFailed
    case uploadFailed(Error)
    case downloadFailed(Error)
    case deleteFailed(Error)
    case invalidImageData
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .uploadFailed(let error):
            return "Upload failed: \(error.localizedDescription)"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Delete failed: \(error.localizedDescription)"
        case .invalidImageData:
            return "Invalid image data"
        case .invalidURL:
            return "Invalid storage URL"
        }
    }
}

