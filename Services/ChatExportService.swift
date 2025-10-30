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
        var yOffset: CGFloat = 80
        
        // Draw header bar
        let headerRect = CGRect(x: 0, y: 0, width: rect.width, height: 60)
        UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0).setFill()
        UIBezierPath(rect: headerRect).fill()
        
        // App name in header
        let appNameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .foregroundColor: UIColor.white
        ]
        "SURVALE".draw(at: CGPoint(x: margin, y: 20), withAttributes: appNameAttributes)
        
        yOffset = 100
        
        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 28),
            .foregroundColor: UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
        ]
        "Chat Export Report".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: titleAttributes)
        yOffset += 50
        
        // Draw main info box
        let boxRect = CGRect(x: margin, y: yOffset, width: rect.width - (margin * 2), height: 240)
        UIColor(white: 0.97, alpha: 1.0).setFill()
        UIBezierPath(roundedRect: boxRect, cornerRadius: 8).fill()
        
        UIColor(white: 0.85, alpha: 1.0).setStroke()
        let boxBorder = UIBezierPath(roundedRect: boxRect, cornerRadius: 8)
        boxBorder.lineWidth = 1
        boxBorder.stroke()
        
        yOffset += 20
        
        // Section header
        let sectionHeaderAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
        ]
        
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray
        ]
        
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        "OPERATION DETAILS".draw(at: CGPoint(x: margin + 15, y: yOffset), withAttributes: sectionHeaderAttributes)
        yOffset += 25
        
        // Operation info with labels
        let leftColumn = margin + 20
        let rightColumn = margin + 140
        
        "Operation:".draw(at: CGPoint(x: leftColumn, y: yOffset), withAttributes: labelAttributes)
        operation.name.draw(at: CGPoint(x: rightColumn, y: yOffset), withAttributes: valueAttributes)
        yOffset += 22
        
        "Incident #:".draw(at: CGPoint(x: leftColumn, y: yOffset), withAttributes: labelAttributes)
        (operation.incidentNumber ?? "N/A").draw(at: CGPoint(x: rightColumn, y: yOffset), withAttributes: valueAttributes)
        yOffset += 22
        
        "Created:".draw(at: CGPoint(x: leftColumn, y: yOffset), withAttributes: labelAttributes)
        formatDate(operation.createdAt).draw(at: CGPoint(x: rightColumn, y: yOffset), withAttributes: valueAttributes)
        yOffset += 22
        
        "Ended:".draw(at: CGPoint(x: leftColumn, y: yOffset), withAttributes: labelAttributes)
        formatDate(operation.endsAt ?? Date()).draw(at: CGPoint(x: rightColumn, y: yOffset), withAttributes: valueAttributes)
        yOffset += 30
        
        // Statistics section
        "STATISTICS".draw(at: CGPoint(x: margin + 15, y: yOffset), withAttributes: sectionHeaderAttributes)
        yOffset += 25
        
        "Participants:".draw(at: CGPoint(x: leftColumn, y: yOffset), withAttributes: labelAttributes)
        "\(members.count)".draw(at: CGPoint(x: rightColumn, y: yOffset), withAttributes: valueAttributes)
        yOffset += 22
        
        "Messages:".draw(at: CGPoint(x: leftColumn, y: yOffset), withAttributes: labelAttributes)
        "\(messageCount)".draw(at: CGPoint(x: rightColumn, y: yOffset), withAttributes: valueAttributes)
        yOffset += 22
        
        "Media Files:".draw(at: CGPoint(x: leftColumn, y: yOffset), withAttributes: labelAttributes)
        "\(mediaCount)".draw(at: CGPoint(x: rightColumn, y: yOffset), withAttributes: valueAttributes)
        
        yOffset = boxRect.maxY + 30
        
        // Filters section (if any)
        if filters.startDate != nil || filters.endDate != nil || filters.selectedMemberIds != nil {
            let filterBoxRect = CGRect(x: margin, y: yOffset, width: rect.width - (margin * 2), height: 120)
            UIColor(red: 1.0, green: 0.95, blue: 0.8, alpha: 1.0).setFill()
            UIBezierPath(roundedRect: filterBoxRect, cornerRadius: 8).fill()
            
            UIColor.orange.setStroke()
            let filterBorder = UIBezierPath(roundedRect: filterBoxRect, cornerRadius: 8)
            filterBorder.lineWidth = 1
            filterBorder.stroke()
            
            yOffset += 20
            
            "FILTERS APPLIED".draw(at: CGPoint(x: margin + 15, y: yOffset), withAttributes: sectionHeaderAttributes)
            yOffset += 25
            
            if let start = filters.startDate {
                "From:".draw(at: CGPoint(x: leftColumn, y: yOffset), withAttributes: labelAttributes)
                formatDate(start).draw(at: CGPoint(x: rightColumn, y: yOffset), withAttributes: valueAttributes)
                yOffset += 22
            }
            if let end = filters.endDate {
                "To:".draw(at: CGPoint(x: leftColumn, y: yOffset), withAttributes: labelAttributes)
                formatDate(end).draw(at: CGPoint(x: rightColumn, y: yOffset), withAttributes: valueAttributes)
                yOffset += 22
            }
            if let memberIds = filters.selectedMemberIds, !memberIds.isEmpty {
                "Members:".draw(at: CGPoint(x: leftColumn, y: yOffset), withAttributes: labelAttributes)
                "\(memberIds.count) selected".draw(at: CGPoint(x: rightColumn, y: yOffset), withAttributes: valueAttributes)
                yOffset += 22
            }
            
            yOffset = filterBoxRect.maxY + 20
        }
        
        // Footer with export date
        yOffset = rect.height - 80
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]
        "Exported: \(formatDateTime(Date()))".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: footerAttributes)
    }
    
    private func drawMessage(
        message: ChatMessage,
        at point: CGPoint,
        width: CGFloat,
        pageRect: CGRect,
        mediaFiles: [MediaFile]
    ) -> CGFloat {
        var yOffset = point.y
        let padding: CGFloat = 12
        let messagePadding: CGFloat = 8
        
        // Calculate content height first to determine box size
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.black
        ]
        
        let contentWidth = width - (padding * 2) - (messagePadding * 2)
        let contentSize = message.content.boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: contentAttributes,
            context: nil
        )
        
        // Calculate total message box height
        var messageBoxHeight: CGFloat = 30 + contentSize.height + messagePadding * 2 // Header + content + padding
        let hasMedia = mediaFiles.contains(where: { $0.id == message.id })
        if hasMedia {
            messageBoxHeight += 125 // Thumbnail + spacing + filename
        }
        
        // Draw light gray background box for entire message
        let messageBoxRect = CGRect(
            x: point.x,
            y: yOffset,
            width: width,
            height: messageBoxHeight
        )
        UIColor(white: 0.97, alpha: 1.0).setFill()
        UIBezierPath(roundedRect: messageBoxRect, cornerRadius: 8).fill()
        
        // Draw border
        UIColor(white: 0.85, alpha: 1.0).setStroke()
        let border = UIBezierPath(roundedRect: messageBoxRect, cornerRadius: 8)
        border.lineWidth = 0.5
        border.stroke()
        
        // Draw header section (timestamp and user)
        yOffset += padding
        
        let headerTimeAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.darkGray
        ]
        
        let headerUserAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
        ]
        
        let timeString = formatDateTime(message.createdAt)
        timeString.draw(at: CGPoint(x: point.x + padding, y: yOffset), withAttributes: headerTimeAttributes)
        
        let userName = message.userName ?? "Unknown"
        let userNameX = point.x + width - padding - userName.size(withAttributes: headerUserAttributes).width
        userName.draw(at: CGPoint(x: userNameX, y: yOffset), withAttributes: headerUserAttributes)
        
        yOffset += 20
        
        // Draw thin separator line
        let separatorY = yOffset
        UIColor(white: 0.85, alpha: 1.0).setStroke()
        let separatorPath = UIBezierPath()
        separatorPath.move(to: CGPoint(x: point.x + padding, y: separatorY))
        separatorPath.addLine(to: CGPoint(x: point.x + width - padding, y: separatorY))
        separatorPath.lineWidth = 0.5
        separatorPath.stroke()
        
        yOffset += 10
        
        // Draw message content with proper padding and wrapping
        let contentX = point.x + padding + messagePadding
        let contentY = yOffset
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        paragraphStyle.alignment = .left
        
        let enhancedContentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraphStyle
        ]
        
        message.content.draw(
            in: CGRect(x: contentX, y: contentY, width: contentWidth, height: contentSize.height),
            withAttributes: enhancedContentAttributes
        )
        
        yOffset += contentSize.height + messagePadding + 10
        
        // Media thumbnail if present (below text, nicely formatted)
        if let mediaFile = mediaFiles.first(where: { $0.id == message.id }) {
            let thumbnailSize: CGFloat = 100
            let thumbnailX = point.x + padding + messagePadding
            
            if mediaFile.isVideo {
                // Video placeholder with better styling
                let placeholderRect = CGRect(x: thumbnailX, y: yOffset, width: thumbnailSize, height: thumbnailSize)
                
                // Gradient background
                UIColor(white: 0.4, alpha: 1.0).setFill()
                UIBezierPath(roundedRect: placeholderRect, cornerRadius: 6).fill()
                
                // Border
                UIColor(white: 0.3, alpha: 1.0).setStroke()
                let border = UIBezierPath(roundedRect: placeholderRect, cornerRadius: 6)
                border.lineWidth = 1
                border.stroke()
                
                // Play icon and text
                let videoLabel = "📹 VIDEO"
                let labelAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 11),
                    .foregroundColor: UIColor.white
                ]
                let labelSize = videoLabel.size(withAttributes: labelAttributes)
                let labelX = thumbnailX + (thumbnailSize - labelSize.width) / 2
                let labelY = yOffset + (thumbnailSize - labelSize.height) / 2
                videoLabel.draw(at: CGPoint(x: labelX, y: labelY), withAttributes: labelAttributes)
            } else {
                // Image thumbnail with border
                if let image = UIImage(data: mediaFile.data) {
                    let thumbnailRect = CGRect(x: thumbnailX, y: yOffset, width: thumbnailSize, height: thumbnailSize)
                    
                    // Draw white background
                    UIColor.white.setFill()
                    UIBezierPath(rect: thumbnailRect).fill()
                    
                    // Draw image (aspect fill)
                    let imageAspect = image.size.width / image.size.height
                    let thumbAspect = thumbnailSize / thumbnailSize
                    var drawRect = thumbnailRect
                    
                    if imageAspect > thumbAspect {
                        // Image is wider - fit height
                        let width = thumbnailSize * imageAspect
                        drawRect = CGRect(
                            x: thumbnailX - (width - thumbnailSize) / 2,
                            y: yOffset,
                            width: width,
                            height: thumbnailSize
                        )
                    } else {
                        // Image is taller - fit width
                        let height = thumbnailSize / imageAspect
                        drawRect = CGRect(
                            x: thumbnailX,
                            y: yOffset - (height - thumbnailSize) / 2,
                            width: thumbnailSize,
                            height: height
                        )
                    }
                    
                    // Clip to thumbnail bounds
                    UIBezierPath(rect: thumbnailRect).addClip()
                    image.draw(in: drawRect)
                    
                    // Draw border
                    UIColor(white: 0.7, alpha: 1.0).setStroke()
                    let border = UIBezierPath(rect: thumbnailRect)
                    border.lineWidth = 1
                    border.stroke()
                }
            }
            
            yOffset += thumbnailSize + 6
            
            // Filename with icon
            let filenameAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.gray
            ]
            let icon = mediaFile.isVideo ? "🎬" : "📎"
            "\(icon) \(mediaFile.filename)".draw(at: CGPoint(x: thumbnailX, y: yOffset), withAttributes: filenameAttributes)
            yOffset += 15
        }
        
        yOffset += padding // Bottom padding
        
        return yOffset
    }
    
    private func estimateMessageHeight(message: ChatMessage, width: CGFloat) -> CGFloat {
        let padding: CGFloat = 12
        let messagePadding: CGFloat = 8
        
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11)
        ]
        
        let contentWidth = width - (padding * 2) - (messagePadding * 2)
        let contentSize = message.content.boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: contentAttributes,
            context: nil
        )
        
        // Header (20) + separator (10) + content + padding
        var height: CGFloat = 30 + contentSize.height + messagePadding * 2 + padding * 2
        
        if message.mediaPath != nil {
            height += 125  // Thumbnail + spacing + filename
        }
        
        return height + 20  // Add spacing between messages
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

