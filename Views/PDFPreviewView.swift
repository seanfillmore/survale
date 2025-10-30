//
//  PDFPreviewView.swift
//  Survale
//
//  PDF preview with share functionality
//

import SwiftUI
import QuickLook

struct PDFPreviewView: UIViewControllerRepresentable {
    let pdfURL: URL
    let mediaFolderURL: URL?
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> PDFPreviewViewController {
        let controller = PDFPreviewViewController()
        controller.pdfURL = pdfURL
        controller.mediaFolderURL = mediaFolderURL
        controller.dismissHandler = onDismiss
        return controller
    }
    
    func updateUIViewController(_ uiViewController: PDFPreviewViewController, context: Context) {
        // No updates needed
    }
}

class PDFPreviewViewController: UIViewController, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    var pdfURL: URL!
    var mediaFolderURL: URL?
    var dismissHandler: (() -> Void)?
    
    private var previewController: QLPreviewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupPreviewController()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Present the preview controller
        if previewController.presentingViewController == nil {
            present(previewController, animated: true)
        }
    }
    
    private func setupPreviewController() {
        previewController = QLPreviewController()
        previewController.dataSource = self
        previewController.delegate = self
        
        // Add custom share button
        let shareButton = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(shareButtonTapped)
        )
        previewController.navigationItem.rightBarButtonItem = shareButton
    }
    
    @objc private func shareButtonTapped() {
        var itemsToShare: [Any] = [pdfURL]
        
        // Add media folder if present
        if let mediaFolder = mediaFolderURL {
            itemsToShare.append(mediaFolder)
        }
        
        let activityVC = UIActivityViewController(
            activityItems: itemsToShare,
            applicationActivities: nil
        )
        
        // For iPad
        if let popover = activityVC.popoverPresentationController {
            popover.barButtonItem = previewController.navigationItem.rightBarButtonItem
        }
        
        previewController.present(activityVC, animated: true)
    }
    
    // MARK: - QLPreviewControllerDataSource
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return pdfURL as QLPreviewItem
    }
    
    // MARK: - QLPreviewControllerDelegate
    
    func previewControllerDidDismiss(_ controller: QLPreviewController) {
        // User dismissed the preview, call the dismiss handler
        dismissHandler?()
    }
}

