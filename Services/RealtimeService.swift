//
//  RealtimeService.swift
//  Survale
//
//  Handles Supabase Realtime subscriptions for location and chat
//

import Foundation
import Supabase
import Combine

@MainActor
final class RealtimeService: ObservableObject {
    static let shared = RealtimeService()
    
    private let client: SupabaseClient
    
    // Published state
    @Published var isConnected = false
    @Published var memberLocations: [UUID: MemberLocation] = [:]  // userId -> location
    
    // Active subscriptions
    private var locationChannel: RealtimeChannelV2?
    private var chatChannel: RealtimeChannelV2?
    
    // Callbacks
    private var locationUpdateHandler: ((LocationPoint) -> Void)?
    private var messageReceivedHandler: ((ChatMessage) -> Void)?
    
    private init() {
        // Use shared client instance to reduce overhead
        self.client = SupabaseClientManager.shared.client
    }
    
    // MARK: - Helpers
    
    /// Convert [String: Any] payload to [String: AnyJSON]
    private func convertToJSONObject(_ payload: [String: Any]) -> JSONObject {
        var result: JSONObject = [:]
        for (key, value) in payload {
            result[key] = convertToAnyJSON(value)
        }
        return result
    }
    
    private func convertToAnyJSON(_ value: Any) -> AnyJSON {
        switch value {
        case let string as String:
            return .string(string)
        case let int as Int:
            return .double(Double(int))
        case let double as Double:
            return .double(double)
        case let bool as Bool:
            return .bool(bool)
        case let array as [Any]:
            return .array(array.map { convertToAnyJSON($0) })
        case let dict as [String: Any]:
            return .object(convertToJSONObject(dict))
        case is NSNull:
            return .null
        default:
            return .null
        }
    }
    
    // MARK: - Location Channel
    
    /// Subscribe to location updates for an operation
    func subscribeToLocations(
        operationId: UUID,
        onLocationUpdate: @escaping (LocationPoint) -> Void
    ) async throws {
        // Store callback
        self.locationUpdateHandler = onLocationUpdate
        
        // Create channel name
        let channelName = "db-changes-locations-\(operationId.uuidString)"
        
        // Remove existing subscription if any
        if let existing = locationChannel {
            await existing.unsubscribe()
        }
        
        // Create channel with postgres changes subscription
        let channel = client.channel(channelName)
        
        // Subscribe to INSERT events on locations_stream table for this operation
        _ = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "locations_stream",
            filter: "operation_id=eq.\(operationId.uuidString)"
        ) { [weak self] change in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                print("📍 New location received via realtime")
                await self.handleLocationInsert(change.record)
            }
        }
        
        do {
            try await channel.subscribeWithError()
            self.locationChannel = channel
            self.isConnected = true
            print("✅ RealtimeService: Location subscription active for operation: \(operationId)")
        } catch {
            print("❌ Location channel subscription error: \(error)")
            throw error
        }
    }
    
    /// Publish location update (now handled by RPC -> database insert -> realtime notification)
    /// This method is no longer needed as we publish via RPC which triggers database inserts
    /// The database inserts automatically trigger the Postgres Changes subscriptions
    func publishLocation(
        operationId: UUID,
        userId: UUID,
        latitude: Double,
        longitude: Double,
        accuracy: Double,
        speed: Double?,
        heading: Double?
    ) async {
        // No-op: Location publishing is now handled entirely by SupabaseRPCService.publishLocation()
        // which inserts into locations_stream table, triggering our postgresChange subscription
        print("RealtimeService.publishLocation called - location will be published via RPC")
    }
    
    /// Handle location insert from database
    private func handleLocationInsert(_ record: [String: AnyJSON]) async {
        // Parse the location data from database record
        // Database column names: user_id, lat, lon, accuracy_m, ts, speed_mps, heading_deg
        guard case .string(let userIdStr) = record["user_id"],
              let userId = UUID(uuidString: userIdStr),
              case .double(let lat) = record["lat"],          // Database: 'lat' not 'latitude'
              case .double(let lon) = record["lon"],          // Database: 'lon' not 'longitude'
              case .double(let accuracy) = record["accuracy_m"],  // Database: 'accuracy_m' not 'accuracy'
              case .string(let timestampStr) = record["ts"],  // Database: 'ts' not 'timestamp'
              let timestamp = ISO8601DateFormatter().date(from: timestampStr) else {
            print("Failed to parse location insert")
            return
        }
        
        var speed: Double?
        if case .double(let speedValue) = record["speed_mps"] {  // Database: 'speed_mps' not 'speed'
            speed = speedValue
        }
        
        var heading: Double?
        if case .double(let headingValue) = record["heading_deg"] {  // Database: 'heading_deg' not 'heading'
            heading = headingValue
        }
        
        guard case .string(let opIdStr) = record["operation_id"],
              let operationId = UUID(uuidString: opIdStr) else {
            print("Failed to parse operation_id")
            return
        }
        
        let locationPoint = LocationPoint(
            userId: userId,
            operationId: operationId,
            timestamp: timestamp,
            latitude: lat,
            longitude: lon,
            accuracy: accuracy,
            speed: speed,
            heading: heading
        )
        
        // Update member location state
        var memberLocation = memberLocations[userId] ?? MemberLocation(id: userId)
        memberLocation.lastLocation = locationPoint
        memberLocation.isActive = true
        memberLocation.lastUpdate = Date()
        memberLocations[userId] = memberLocation
        
        // Call handler
        locationUpdateHandler?(locationPoint)
    }
    
    // MARK: - Chat Channel
    
    /// Subscribe to chat messages for an operation
    /// Note: Swift SDK doesn't support postgres_changes yet, so this is a placeholder
    func subscribeToChatMessages(
        operationId: UUID,
        onMessageReceived: @escaping (ChatMessage) -> Void
    ) async throws {
        // Store callback
        self.messageReceivedHandler = onMessageReceived
        
        // Create channel name
        let channelName = "db-changes-chat-\(operationId.uuidString)"
        
        // Remove existing subscription if any
        if let existing = chatChannel {
            await existing.unsubscribe()
        }
        
        // Create channel with postgres changes subscription
        let channel = client.channel(channelName)
        
        // Subscribe to INSERT events on op_messages table for this operation
        _ = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "op_messages",
            filter: "operation_id=eq.\(operationId.uuidString)"
        ) { [weak self] _ in
            guard let self = self else { return }
            
            print("📨 New chat message received via realtime - triggering callback")
            
            // Trigger the callback - ChatView will handle fetching new messages
            Task { @MainActor in
                // Create a dummy message to signal that new messages are available
                // ChatView will handle deduplication and proper fetching
                let dummyMessage = ChatMessage(
                    id: UUID().uuidString,
                    operationID: operationId,
                    userID: "",
                    content: "__RELOAD__", // Special marker
                    createdAt: Date(),
                    userName: nil,
                    mediaPath: nil,
                    mediaType: "text"
                )
                self.messageReceivedHandler?(dummyMessage)
            }
        }
        
        do {
            try await channel.subscribeWithError()
            self.chatChannel = channel
            print("✅ Chat realtime subscription active for operation: \(operationId)")
        } catch {
            print("❌ Chat channel subscription error: \(error)")
            throw error
        }
    }
    
    /// Publish a chat message (now handled by DatabaseService -> database insert -> realtime notification)
    /// This method is no longer needed as we publish via DatabaseService which triggers database inserts
    /// The database inserts automatically trigger the Postgres Changes subscriptions
    func publishChatMessage(
        operationId: UUID,
        userId: UUID,
        content: String
    ) async {
        // No-op: Chat publishing is now handled entirely by DatabaseService.sendMessage()
        // which inserts into op_messages table, triggering our postgresChange subscription
        print("RealtimeService.publishChatMessage called - message will be published via DatabaseService")
    }
    
    /// Handle message insert from database
    private func handleMessageInsert(_ record: [String: AnyJSON]) async {
        // Parse the message data from database record
        // Database column names: sender_user_id, body_text
        guard case .string(let idStr) = record["id"],
              case .string(let userIdStr) = record["sender_user_id"],  // Database: 'sender_user_id' not 'user_id'
              case .string(let content) = record["body_text"],         // Database: 'body_text' not 'content'
              case .string(let createdAtStr) = record["created_at"],
              let createdAt = ISO8601DateFormatter().date(from: createdAtStr) else {
            print("Failed to parse message insert")
            return
        }
        
        guard case .string(let opIdStr) = record["operation_id"],
              let operationID = UUID(uuidString: opIdStr) else {
            print("Failed to parse operation_id")
            return
        }
        
        // Get optional user_name
        var userName: String?
        if case .string(let name) = record["user_name"] {
            userName = name
        }
        
        // Get optional media fields
        var mediaPath: String?
        if case .string(let path) = record["media_path"] {
            mediaPath = path
        }
        
        var mediaType = "text"
        if case .string(let type) = record["media_type"] {
            mediaType = type
        }
        
        let message = ChatMessage(
            id: idStr,
            operationID: operationID,
            userID: userIdStr,
            content: content,
            createdAt: createdAt,
            userName: userName,
            mediaPath: mediaPath,
            mediaType: mediaType
        )
        
        // Call handler
        messageReceivedHandler?(message)
    }
    
    // MARK: - Cleanup
    
    /// Unsubscribe from all channels
    func unsubscribeAll() async {
        if let channel = locationChannel {
            await channel.unsubscribe()
            locationChannel = nil
        }
        
        if let channel = chatChannel {
            await channel.unsubscribe()
            chatChannel = nil
        }
        
        memberLocations.removeAll()
        isConnected = false
        locationUpdateHandler = nil
        messageReceivedHandler = nil
    }
    
    /// Unsubscribe from location channel only
    func unsubscribeFromLocations() async {
        if let channel = locationChannel {
            await channel.unsubscribe()
            locationChannel = nil
        }
        memberLocations.removeAll()
        locationUpdateHandler = nil
    }
    
    /// Unsubscribe from chat channel only
    func unsubscribeFromChat() async {
        if let channel = chatChannel {
            await channel.unsubscribe()
            chatChannel = nil
        }
        messageReceivedHandler = nil
    }
}

// MARK: - Errors

enum RealtimeServiceError: LocalizedError {
    case notSubscribed
    case connectionFailed
    case invalidPayload
    
    var errorDescription: String? {
        switch self {
        case .notSubscribed:
            return "Not subscribed to any channel"
        case .connectionFailed:
            return "Failed to connect to realtime service"
        case .invalidPayload:
            return "Invalid message payload received"
        }
    }
}
