//
//  ChatExportModels.swift
//  Survale
//
//  Data models for chat export functionality
//

import Foundation

/// Filters for chat export
struct ChatExportFilters: Sendable {
    var startDate: Date?
    var endDate: Date?
    var selectedMemberIds: Set<UUID>?  // nil = all members
    
    func matches(message: ChatMessage, messageDate: Date) -> Bool {
        // Check date range
        if let start = startDate, messageDate < start {
            return false
        }
        if let end = endDate, messageDate > end {
            return false
        }
        
        // Check member filter
        if let memberIds = selectedMemberIds,
           !memberIds.isEmpty,
           let userId = UUID(uuidString: message.userID),
           !memberIds.contains(userId) {
            return false
        }
        
        return true
    }
}

/// Result of a chat export operation
struct ChatExportResult: Sendable {
    let pdfURL: URL
    let mediaFolderURL: URL?
    let messageCount: Int
    let mediaCount: Int
}

