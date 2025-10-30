//
//  ChatExportService.swift
//  Survale
//
//  Chat export functionality for generating PDF reports
//  with filtering options and media downloads
//

import Foundation
import PDFKit
import UIKit
import Supabase

/// Service for exporting chat conversations to PDF with media
@MainActor
class ChatExportService {
    static let shared = ChatExportService()
    
    private let supabase = SupabaseClientManager.shared.client
    
    private init() {}
    
    // MARK: - Public API
    
    /// Export chat for an operation with optional filters
    func exportChat(
        operationId: UUID,
        operation: Operation,
        members: [User],
        filters: ChatExportFilters? = nil
    ) async throws -> ChatExportResult {
        
        let exportFilters = filters ?? ChatExportFilters()
        
        print("📄 Starting chat export for operation: \(operation.name)")
        
        // 1. Fetch all messages
        print("   → Fetching messages...")
        let allMessages = try await fetchMessages(operationId: operationId)
        print("   → Found \(allMessages.count) total messages")
        
        // 2. Apply filters
        let filteredMessages = allMessages.filter { message in
            exportFilters.matches(message: message, messageDate: message.createdAt)
        }
        print("   → After filtering: \(filteredMessages.count) messages")
        
        guard !filteredMessages.isEmpty else {
            throw ChatExportError.noMessagesToExport
        }
        
        // 3. Download media
        print("   → Downloading media...")
        let mediaFiles = try await downloadMedia(for: filteredMessages)
        print("   → Downloaded \(mediaFiles.count) media files")
        
        // 4. Generate PDF
        print("   → Generating PDF...")
        let pdfURL = try await generatePDF(
            operation: operation,
            members: members,
            messages: filteredMessages,
            mediaFiles: mediaFiles,
            filters: exportFilters
        )
        print("   → PDF generated at: \(pdfURL.path)")
        
        // 5. Organize media in folder
        let mediaFolderURL = mediaFiles.isEmpty ? nil : try createMediaFolder(mediaFiles: mediaFiles, operationName: operation.name)
        
        return ChatExportResult(
            pdfURL: pdfURL,
            mediaFolderURL: mediaFolderURL,
            messageCount: filteredMessages.count,
            mediaCount: mediaFiles.count
        )
    }
    
    // MARK: - Private Methods
    
    private func fetchMessages(operationId: UUID) async throws -> [ChatMessage] {
        struct MessageWithUser: Decodable {
            let id: String
            let operation_id: String
            let sender_user_id: String
            let body_text: String
            let created_at: String
            let media_path: String?
            let media_type: String?
            let users: UserInfo?
            
            struct UserInfo: Decodable {
                let full_name: String?
            }
        }
        
        let response = try await supabase
            .from("op_messages")
            .select("*, users!sender_user_id(full_name)")
            .eq("operation_id", value: operationId.uuidString)
            .order("created_at", ascending: true)
            .execute()
        
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let messagesWithUser = try decoder.decode([MessageWithUser].self, from: response.data)
        
        return messagesWithUser.compactMap { msg in
            guard let operationId = UUID(uuidString: msg.operation_id),
                  let createdAt = formatter.date(from: msg.created_at) else {
                return nil
            }
            
            return ChatMessage(
                id: msg.id,
                operationID: operationId,
                userID: msg.sender_user_id,
                content: msg.body_text,
                createdAt: createdAt,
                userName: msg.users?.full_name,
                mediaPath: msg.media_path,
                mediaType: msg.media_type ?? "text"
            )
        }
    }
    
    private func downloadMedia(for messages: [ChatMessage]) async throws -> [MediaFile] {
        var mediaFiles: [MediaFile] = []
        
        for message in messages {
            guard let mediaPath = message.mediaPath,
                  !mediaPath.isEmpty,
                  message.mediaType != "text" else {
                continue
            }
            
            do {
                let data = try await supabase.storage
                    .from("chat-media")
                    .download(path: mediaPath)
                
                // Determine if it's an image or video
                let isVideo = message.mediaType == "video"
                
                let mediaFile = MediaFile(
                    id: message.id,
                    data: data,
                    filename: (mediaPath as NSString).lastPathComponent,
                    isVideo: isVideo,
                    timestamp: message.createdAt,
                    userName: message.userName ?? "Unknown"
                )
                
                mediaFiles.append(mediaFile)
                
            } catch {
                print("⚠️ Failed to download media for message \(message.id): \(error)")
                // Continue with other media files
            }
        }
        
        return mediaFiles
    }
    
    private func generatePDF(
        operation: Operation,
        members: [User],
        messages: [ChatMessage],
        mediaFiles: [MediaFile],
        filters: ChatExportFilters
    ) async throws -> URL {
        
        let pdfMetadata = [
            kCGPDFContextTitle as String: "Chat Export - \(operation.name)",
            kCGPDFContextAuthor as String: "Survale",
            kCGPDFContextSubject as String: "Operation Chat Transcript"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetadata as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)  // Letter size
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            // Page 1: Cover page
            context.beginPage()
            drawCoverPage(
                in: pageRect,
                operation: operation,
                members: members,
                messageCount: messages.count,
                mediaCount: mediaFiles.count,
                filters: filters
            )
            
            // Subsequent pages: Messages
            var yOffset: CGFloat = 60  // Start position on page
            let margin: CGFloat = 50
            let contentWidth = pageRect.width - (margin * 2)
            
            for (index, message) in messages.enumerated() {
                // Check if we need a new page
                let estimatedHeight = estimateMessageHeight(message: message, width: contentWidth)
                
                if yOffset + estimatedHeight > pageRect.height - margin {
                    context.beginPage()
                    yOffset = 60
                }
                
                // Draw message
                yOffset = drawMessage(
                    message: message,
                    at: CGPoint(x: margin, y: yOffset),
                    width: contentWidth,
                    pageRect: pageRect,
                    mediaFiles: mediaFiles
                )
                
                yOffset += 20  // Spacing between messages
            }
        }
        
        // Save PDF to temporary directory
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "Chat_Export_\(operation.name.replacingOccurrences(of: " ", with: "_"))_\(Date().timeIntervalSince1970).pdf"
        let pdfURL = tempDir.appendingPathComponent(filename)
        
        try data.write(to: pdfURL)
        
        return pdfURL
    }
    
    private func drawCoverPage(
        in rect: CGRect,
        operation: Operation,
        members: [User],
        messageCount: Int,
        mediaCount: Int,
        filters: ChatExportFilters
    ) {
        let margin: CGFloat = 50
        var yOffset: CGFloat = 100
        
        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        let title = "Chat Export Report"
        title.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: titleAttributes)
        yOffset += 40
        
        // Operation details
        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.darkGray
        ]
        
        let details = [
            "Operation: \(operation.name)",
            "Incident #: \(operation.incidentNumber ?? "N/A")",
            "Created: \(formatDate(operation.createdAt))",
            "Ended: \(formatDate(operation.endsAt ?? Date()))",
            "",
            "Participants: \(members.count)",
            "Messages: \(messageCount)",
            "Media Files: \(mediaCount)",
            "",
            "Exported: \(formatDate(Date()))"
        ]
        
        for detail in details {
            detail.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: detailAttributes)
            yOffset += 25
        }
        
        // Filters applied
        if filters.startDate != nil || filters.endDate != nil || filters.selectedMemberIds != nil {
            yOffset += 20
            "Filters Applied:".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: titleAttributes)
            yOffset += 30
            
            if let start = filters.startDate {
                "From: \(formatDate(start))".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: detailAttributes)
                yOffset += 25
            }
            if let end = filters.endDate {
                "To: \(formatDate(end))".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: detailAttributes)
                yOffset += 25
            }
            if let memberIds = filters.selectedMemberIds, !memberIds.isEmpty {
                "Selected Members: \(memberIds.count)".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: detailAttributes)
                yOffset += 25
            }
        }
    }
    
    private func drawMessage(
        message: ChatMessage,
        at point: CGPoint,
        width: CGFloat,
        pageRect: CGRect,
        mediaFiles: [MediaFile]
    ) -> CGFloat {
        var yOffset = point.y
        
        // Message header (timestamp and user)
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray
        ]
        
        let header = "\(formatDateTime(message.createdAt)) - \(message.userName ?? "Unknown")"
        header.draw(at: CGPoint(x: point.x, y: yOffset), withAttributes: headerAttributes)
        yOffset += 20
        
        // Message content
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        let contentRect = CGRect(x: point.x, y: yOffset, width: width, height: CGFloat.greatestFiniteMagnitude)
        let contentSize = message.content.boundingRect(
            with: contentRect.size,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: contentAttributes,
            context: nil
        )
        
        message.content.draw(in: CGRect(x: point.x, y: yOffset, width: width, height: contentSize.height), withAttributes: contentAttributes)
        yOffset += contentSize.height + 10
        
        // Media thumbnail if present
        if let mediaFile = mediaFiles.first(where: { $0.id == message.id }) {
            let thumbnailSize: CGFloat = 100
            yOffset += 5
            
            if mediaFile.isVideo {
                // Video placeholder
                let placeholderRect = CGRect(x: point.x, y: yOffset, width: thumbnailSize, height: thumbnailSize)
                UIColor.lightGray.setFill()
                UIBezierPath(roundedRect: placeholderRect, cornerRadius: 8).fill()
                
                let videoLabel = "📹 Video"
                let labelAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.white
                ]
                videoLabel.draw(at: CGPoint(x: point.x + 20, y: yOffset + 40), withAttributes: labelAttributes)
            } else {
                // Image thumbnail
                if let image = UIImage(data: mediaFile.data) {
                    let thumbnailRect = CGRect(x: point.x, y: yOffset, width: thumbnailSize, height: thumbnailSize)
                    image.draw(in: thumbnailRect)
                }
            }
            
            yOffset += thumbnailSize + 5
            
            // Filename
            let filenameAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.gray
            ]
            "File: \(mediaFile.filename)".draw(at: CGPoint(x: point.x, y: yOffset), withAttributes: filenameAttributes)
            yOffset += 15
        }
        
        return yOffset
    }
    
    private func estimateMessageHeight(message: ChatMessage, width: CGFloat) -> CGFloat {
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12)
        ]
        
        let contentSize = message.content.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: contentAttributes,
            context: nil
        )
        
        var height: CGFloat = 20 + contentSize.height + 10  // Header + content + spacing
        
        if message.mediaPath != nil {
            height += 120  // Thumbnail + filename
        }
        
        return height
    }
    
    private func createMediaFolder(mediaFiles: [MediaFile], operationName: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let folderName = "Chat_Media_\(operationName.replacingOccurrences(of: " ", with: "_"))_\(Date().timeIntervalSince1970)"
        let mediaFolder = tempDir.appendingPathComponent(folderName)
        
        try FileManager.default.createDirectory(at: mediaFolder, withIntermediateDirectories: true)
        
        for mediaFile in mediaFiles {
            let fileURL = mediaFolder.appendingPathComponent(mediaFile.filename)
            try mediaFile.data.write(to: fileURL)
        }
        
        return mediaFolder
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

struct MediaFile: Sendable {
    let id: String
    let data: Data
    let filename: String
    let isVideo: Bool
    let timestamp: Date
    let userName: String
}

enum ChatExportError: LocalizedError {
    case noMessagesToExport
    case downloadFailed
    case pdfGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .noMessagesToExport:
            return "No messages to export with the selected filters"
        case .downloadFailed:
            return "Failed to download media files"
        case .pdfGenerationFailed:
            return "Failed to generate PDF"
        }
    }
}

