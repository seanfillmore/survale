//
//  CameraView.swift
//  Survale
//
//  UIImagePickerController wrapper for camera access
//

import SwiftUI
import UIKit
import AVFoundation

struct CameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let sourceType: UIImagePickerController.SourceType
    let mediaTypes: [String]
    let onMediaCaptured: (Data, String) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.mediaTypes = mediaTypes
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        
        // For video, set quality
        if mediaTypes.contains("public.movie") {
            picker.videoQuality = .typeMedium
            picker.videoMaximumDuration = 60 // 60 seconds max
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            defer { parent.dismiss() }
            
            // Handle image
            if let image = info[.originalImage] as? UIImage,
               let imageData = image.jpegData(compressionQuality: 0.8) {
                parent.onMediaCaptured(imageData, "image")
                return
            }
            
            // Handle video
            if let videoURL = info[.mediaURL] as? URL {
                do {
                    let videoData = try Data(contentsOf: videoURL)
                    parent.onMediaCaptured(videoData, "video")
                } catch {
                    print("❌ Failed to load video data: \(error)")
                }
                return
            }
            
            print("⚠️ No media data captured")
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Camera Permission Helper

struct CameraPermissionHelper {
    static func checkCameraPermission() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    static func requestCameraPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
    
    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}

