//
//  SupabaseRPCService.swift
//  Survale
//
//  RPC functions for secure Supabase operations
//

import Foundation
import Supabase
import MapKit

final class SupabaseRPCService: @unchecked Sendable {
    static let shared = SupabaseRPCService()
    
    private let client: SupabaseClient
    
    private init() {
        // Use shared client instance to reduce overhead
        self.client = SupabaseClientManager.shared.supabase
    }
    
    // MARK: - Assignment Response Models
    
    struct AssignmentResponse: Decodable, Sendable {
        let assignment_id: String
        let status: String
    }
    
    struct AssignmentStatusResponse: Decodable, Sendable {
        let assignment_id: String
        let status: String
        let updated_at: String
        let completed_at: String?
    }
    
    // MARK: - Image Models
    
    // Shared image item struct for encoding
    struct EncodableImageItem: Encodable, Sendable {
        let id: String
        let storage_kind: String
        let remote_url: String?
        let local_path: String?
        let filename: String
        let pixel_width: Int?
        let pixel_height: Int?
        let byte_size: Int?
        let created_at: String
        let caption: String?
        
        static func from(_ dict: [String: Any]) -> EncodableImageItem? {
            guard let id = dict["id"] as? String,
                  let storageKind = dict["storage_kind"] as? String,
                  let filename = dict["filename"] as? String,
                  let createdAt = dict["created_at"] as? String else {
                return nil
            }
            return EncodableImageItem(
                id: id,
                storage_kind: storageKind,
                remote_url: dict["remote_url"] as? String,
                local_path: dict["local_path"] as? String,
                filename: filename,
                pixel_width: dict["pixel_width"] as? Int,
                pixel_height: dict["pixel_height"] as? Int,
                byte_size: dict["byte_size"] as? Int,
                created_at: createdAt,
                caption: dict["caption"] as? String
            )
        }
        
        static func fromArray(_ dictArray: [[String: Any]]) -> [EncodableImageItem] {
            return dictArray.compactMap { from($0) }
        }
    }
    
    // MARK: - Operation Lifecycle
    
    /// Create a new operation (draft state)
    /// Returns the operation ID
    nonisolated func createOperation(name: String, incidentNumber: String?, isDraft: Bool = false) async throws -> UUID {
        struct CreateOperationParams: Encodable, Sendable {
            let name: String
            let incident_number: String?
            let is_draft: Bool
        }
        
        struct CreateOperationResponse: Decodable, Sendable {
            let operation_id: String
        }
        
        let params = CreateOperationParams(
            name: name,
            incident_number: incidentNumber,
            is_draft: isDraft
        )
        
        let response: CreateOperationResponse = try await client
            .rpc("rpc_create_operation", params: params)
            .execute()
            .value
        
        guard let uuid = UUID(uuidString: response.operation_id) else {
            throw SupabaseRPCError.invalidResponse("Invalid operation ID format")
        }
        
        return uuid
    }
    
    /// Start an operation (changes state to active)
    nonisolated func startOperation(operationId: UUID) async throws {
        struct StartOperationParams: Encodable, Sendable {
            let operation_id: String
        }
        
        let params = StartOperationParams(operation_id: operationId.uuidString)
        
        try await client
            .rpc("rpc_start_operation", params: params)
            .execute()
    }
    
    /// End an operation (changes state to ended)
    nonisolated func endOperation(operationId: UUID) async throws {
        struct EndOperationParams: Encodable, Sendable {
            let operation_id: String
        }
        
        let params = EndOperationParams(operation_id: operationId.uuidString)
        
        try await client
            .rpc("rpc_end_operation", params: params)
            .execute()
    }
    
    /// Transfer operation to a new case agent
    nonisolated func transferOperation(operationId: UUID, newCaseAgentId: UUID) async throws {
        struct TransferParams: Encodable, Sendable {
            let operation_id: String
            let new_case_agent_id: String
        }
        
        let params = TransferParams(
            operation_id: operationId.uuidString,
            new_case_agent_id: newCaseAgentId.uuidString
        )
        
        try await client
            .rpc("rpc_transfer_operation", params: params)
            .execute()
    }
    
    /// Leave an operation
    nonisolated func leaveOperation(operationId: UUID, userId: UUID) async throws {
        struct LeaveParams: Encodable, Sendable {
            let operation_id: String
            let user_id: String
        }
        
        let params = LeaveParams(
            operation_id: operationId.uuidString,
            user_id: userId.uuidString
        )
        
        try await client
            .rpc("rpc_leave_operation", params: params)
            .execute()
    }
    
    // MARK: - Member Management
    
    /// Invite a user to an operation
    nonisolated func inviteUser(operationId: UUID, inviteeUserId: UUID, expiresAt: Date) async throws {
        struct InviteUserParams: Encodable, Sendable {
            let operation_id: String
            let invitee_user_id: String
            let expires_at: String
        }
        
        let formatter = ISO8601DateFormatter()
        let params = InviteUserParams(
            operation_id: operationId.uuidString,
            invitee_user_id: inviteeUserId.uuidString,
            expires_at: formatter.string(from: expiresAt)
        )
        
        try await client
            .rpc("rpc_invite_user", params: params)
            .execute()
    }
    
    /// Accept an operation invite
    nonisolated func acceptInvite(inviteId: UUID) async throws {
        struct AcceptInviteParams: Encodable, Sendable {
            let invite_id: String
        }
        
        let params = AcceptInviteParams(invite_id: inviteId.uuidString)
        
        try await client
            .rpc("rpc_accept_invite", params: params)
            .execute()
    }
    
    /// Request to join an operation
    nonisolated func requestJoin(operationId: UUID) async throws {
        struct RequestJoinParams: Encodable, Sendable {
            let operation_id: String
        }
        
        let params = RequestJoinParams(operation_id: operationId.uuidString)
        
        try await client
            .rpc("rpc_request_join", params: params)
            .execute()
    }
    
    /// Approve or deny a join request
    nonisolated func approveJoin(requestId: UUID, approve: Bool) async throws {
        struct ApproveJoinParams: Encodable, Sendable {
            let request_id: String
            let approve_bool: Bool
        }
        
        let params = ApproveJoinParams(
            request_id: requestId.uuidString,
            approve_bool: approve
        )
        
        try await client
            .rpc("rpc_approve_join", params: params)
            .execute()
    }
    
    // MARK: - Messaging
    
    /// Post a message to an operation channel
    nonisolated func postMessage(
        operationId: UUID,
        bodyText: String,
        mediaPath: String? = nil,
        mediaType: String = "text"
    ) async throws {
        struct PostMessageParams: Encodable, Sendable {
            let operation_id: String
            let body_text: String
            let media_path: String?
            let media_type: String
        }
        
        let params = PostMessageParams(
            operation_id: operationId.uuidString,
            body_text: bodyText,
            media_path: mediaPath,
            media_type: mediaType
        )
        
        try await client
            .rpc("rpc_post_message", params: params)
            .execute()
    }
    
    // MARK: - Location Tracking
    
    /// Publish current location to operation
    nonisolated func publishLocation(
        operationId: UUID,
        lat: Double,
        lon: Double,
        accuracy: Double,
        speed: Double?,
        heading: Double?
    ) async throws {
        struct PublishLocationParams: Encodable, Sendable {
            let operation_id: String
            let lat: Double
            let lon: Double
            let accuracy_m: Double
            let speed_mps: Double?
            let heading_deg: Double?
        }
        
        let params = PublishLocationParams(
            operation_id: operationId.uuidString,
            lat: lat,
            lon: lon,
            accuracy_m: accuracy,
            speed_mps: speed,
            heading_deg: heading
        )
        
        try await client
            .rpc("rpc_publish_location", params: params)
            .execute()
    }
    
    // MARK: - Export (Placeholder)
    
    /// Tag segments for export
    nonisolated func tagExportSegments(operationId: UUID, segments: [[String: Any]]) async throws {
        struct TagExportParams: Encodable, Sendable {
            let operation_id: String
            let segments_json: String
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: segments)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
        
        let params = TagExportParams(
            operation_id: operationId.uuidString,
            segments_json: jsonString
        )
        
        try await client
            .rpc("rpc_tag_export_segments", params: params)
            .execute()
    }
    
    // MARK: - Location Assignments
    
    /// Assign a location to a team member
    nonisolated func assignLocation(
        operationId: UUID,
        assignedToUserId: UUID,
        lat: Double,
        lon: Double,
        label: String?,
        notes: String?
    ) async throws -> AssignmentResponse {
        struct AssignLocationParams: Encodable, Sendable {
            let operation_id: String
            let assigned_to_user_id: String
            let lat: Double
            let lon: Double
            let label: String?
            let notes: String?
        }
        
        let params = AssignLocationParams(
            operation_id: operationId.uuidString,
            assigned_to_user_id: assignedToUserId.uuidString,
            lat: lat,
            lon: lon,
            label: label,
            notes: notes
        )
        
        return try await client
            .rpc("rpc_assign_location", params: params)
            .execute()
            .value
    }
    
    /// Update assignment status (en_route, arrived, etc.)
    nonisolated func updateAssignmentStatus(
        assignmentId: UUID,
        status: String
    ) async throws -> AssignmentStatusResponse {
        struct UpdateStatusParams: Encodable, Sendable {
            let assignment_id: String
            let new_status: String
        }
        
        let params = UpdateStatusParams(
            assignment_id: assignmentId.uuidString,
            new_status: status
        )
        
        return try await client
            .rpc("rpc_update_assignment_status", params: params)
            .execute()
            .value
    }
    
    /// Get all assignments for an operation
    nonisolated func getOperationAssignments(operationId: UUID) async throws -> [AssignedLocation] {
        struct GetAssignmentsParams: Encodable, Sendable {
            let operation_id: String
        }
        
        let params = GetAssignmentsParams(
            operation_id: operationId.uuidString
        )
        
        let rawData = try await client
            .rpc("rpc_get_operation_assignments", params: params)
            .execute()
            .data
        
        // Decode from JSON array
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Fallback without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string: \(dateString)"
            )
        }
        
        return try decoder.decode([AssignedLocation].self, from: rawData)
    }
    
    /// Cancel an assignment
    nonisolated func cancelAssignment(assignmentId: UUID) async throws {
        struct CancelParams: Encodable, Sendable {
            let assignment_id: String
        }
        
        let params = CancelParams(
            assignment_id: assignmentId.uuidString
        )
        
        try await client
            .rpc("rpc_cancel_assignment", params: params)
            .execute()
    }
    
    /// Request PDF export
    nonisolated func requestExportPDF(operationId: UUID, includeMaps: Bool) async throws -> UUID {
        struct RequestExportParams: Encodable, Sendable {
            let operation_id: String
            let include_maps_bool: Bool
        }
        
        struct ExportResponse: Decodable, Sendable {
            let export_id: String
        }
        
        let params = RequestExportParams(
            operation_id: operationId.uuidString,
            include_maps_bool: includeMaps
        )
        
        let response: ExportResponse = try await client
            .rpc("rpc_request_export_pdf", params: params)
            .execute()
            .value
        
        guard let uuid = UUID(uuidString: response.export_id) else {
            throw SupabaseRPCError.invalidResponse("Invalid export ID format")
        }
        
        return uuid
    }
    
    // MARK: - Targets
    
    /// Create person target
    nonisolated func createPersonTarget(
        operationId: UUID,
        firstName: String,
        lastName: String,
        phone: String?,
        images: [[String: Any]] = []
    ) async throws -> UUID {
        struct Params: Encodable, Sendable {
            let operation_id: String
            let first_name: String
            let last_name: String
            let phone: String?
            let images: [EncodableImageItem]
        }
        
        struct Response: Decodable, Sendable {
            let target_id: String
        }
        
        let params = Params(
            operation_id: operationId.uuidString,
            first_name: firstName,
            last_name: lastName,
            phone: phone,
            images: EncodableImageItem.fromArray(images)
        )
        
        let response: Response = try await client
            .rpc("rpc_create_person_target", params: params)
            .execute()
            .value
        
        guard let uuid = UUID(uuidString: response.target_id) else {
            throw SupabaseRPCError.invalidResponse("Invalid target ID format")
        }
        
        return uuid
    }
    
    /// Create vehicle target
    nonisolated func createVehicleTarget(
        operationId: UUID,
        make: String?,
        model: String?,
        color: String?,
        plate: String?,
        images: [[String: Any]] = []
    ) async throws -> UUID {
        struct Params: Encodable, Sendable {
            let operation_id: String
            let make: String?
            let model: String?
            let color: String?
            let plate: String?
            let images: [EncodableImageItem]
        }
        
        struct Response: Decodable, Sendable {
            let target_id: String
        }
        
        let params = Params(
            operation_id: operationId.uuidString,
            make: make,
            model: model,
            color: color,
            plate: plate,
            images: EncodableImageItem.fromArray(images)
        )
        
        let response: Response = try await client
            .rpc("rpc_create_vehicle_target", params: params)
            .execute()
            .value
        
        guard let uuid = UUID(uuidString: response.target_id) else {
            throw SupabaseRPCError.invalidResponse("Invalid target ID format")
        }
        
        return uuid
    }
    
    /// Create location target
    nonisolated func createLocationTarget(
        operationId: UUID,
        address: String,
        label: String?,
        city: String?,
        zipCode: String?,
        latitude: Double?,
        longitude: Double?,
        images: [[String: Any]] = []
    ) async throws -> UUID {
        struct Params: Encodable, Sendable {
            let operation_id: String
            let address: String
            let label: String?
            let city: String?
            let zip_code: String?
            let latitude: Double?
            let longitude: Double?
            let images: [EncodableImageItem]
        }
        
        struct Response: Decodable, Sendable {
            let target_id: String
        }
        
        let params = Params(
            operation_id: operationId.uuidString,
            address: address,
            label: label,
            city: city,
            zip_code: zipCode,
            latitude: latitude,
            longitude: longitude,
            images: EncodableImageItem.fromArray(images)
        )
        
        let response: Response = try await client
            .rpc("rpc_create_location_target", params: params)
            .execute()
            .value
        
        guard let uuid = UUID(uuidString: response.target_id) else {
            throw SupabaseRPCError.invalidResponse("Invalid target ID format")
        }
        
        return uuid
    }
    
    /// Update target images
    nonisolated func updateTargetImages(targetId: UUID, images: [[String: Any]]) async throws {
        struct Params: Encodable, Sendable {
            let target_id: String
            let images: [EncodableImageItem]
        }
        
        struct Response: Decodable, Sendable {
            let success: Bool
        }
        
        let params = Params(
            target_id: targetId.uuidString,
            images: EncodableImageItem.fromArray(images)
        )
        
        let _: Response = try await client
            .rpc("rpc_update_target_images", params: params)
            .execute()
            .value
        
        print("✅ Target images updated")
    }
    
    /// Delete target
    nonisolated func deleteTarget(targetId: UUID) async throws {
        struct Params: Encodable, Sendable {
            let target_id: String
        }
        
        struct Response: Decodable, Sendable {
            let success: Bool
        }
        
        let params = Params(target_id: targetId.uuidString)
        
        let _: Response = try await client
            .rpc("rpc_delete_target", params: params)
            .execute()
            .value
        
        print("✅ Target deleted")
    }
    
    /// Delete staging point
    nonisolated func deleteStagingPoint(stagingId: UUID) async throws {
        struct Params: Encodable, Sendable {
            let staging_id: String
        }
        
        struct Response: Decodable, Sendable {
            let success: Bool
        }
        
        let params = Params(staging_id: stagingId.uuidString)
        
        let _: Response = try await client
            .rpc("rpc_delete_staging_point", params: params)
            .execute()
            .value
        
        print("✅ Staging point deleted")
    }
    
    /// Create staging point
    nonisolated func createStagingPoint(
        operationId: UUID,
        label: String,
        latitude: Double,
        longitude: Double
    ) async throws -> UUID {
        struct Params: Encodable, Sendable {
            let operation_id: String
            let label: String
            let latitude: Double
            let longitude: Double
        }
        
        struct Response: Decodable, Sendable {
            let staging_id: String
        }
        
        let params = Params(
            operation_id: operationId.uuidString,
            label: label,
            latitude: latitude,
            longitude: longitude
        )
        
        let response: Response = try await client
            .rpc("rpc_create_staging_point", params: params)
            .execute()
            .value
        
        guard let uuid = UUID(uuidString: response.staging_id) else {
            throw SupabaseRPCError.invalidResponse("Invalid staging ID format")
        }
        
        return uuid
    }
    
    /// Get targets and staging for an operation
    nonisolated func getOperationTargets(operationId: UUID) async throws -> (targets: [OpTarget], staging: [StagingPoint]) {
        struct Params: Encodable, Sendable {
            let operation_id: String
        }
        
        struct TargetResponse: Decodable {
            let targets: [TargetData]
            let staging: [StagingData]
        }
        
        struct TargetData: Decodable {
            let id: String
            let type: String
            let person: PersonData?
            let vehicle: VehicleData?
            let location: LocationData?
        }
        
        struct PersonData: Decodable {
            let first_name: String
            let last_name: String
            let phone_number: String?
            let notes: String?
            let images: [ImageData]?
        }
        
        struct VehicleData: Decodable {
            let make: String?
            let model: String?
            let color: String?
            let plate: String?
            let notes: String?
            let images: [ImageData]?
        }
        
        struct LocationData: Decodable {
            let label: String?
            let address: String
            let latitude: Double?
            let longitude: Double?
            let notes: String?
            let images: [ImageData]?
        }
        
        struct ImageData: Decodable {
            let id: String
            let storage_kind: String
            let remote_url: String?
            let local_path: String?
            let filename: String
            let pixel_width: Int?
            let pixel_height: Int?
            let byte_size: Int?
            let created_at: String
            let caption: String?
        }
        
        struct StagingData: Decodable {
            let id: String
            let label: String
            let latitude: Double
            let longitude: Double
        }
        
        let params = Params(operation_id: operationId.uuidString)
        
        // Get raw response data for debugging
        let rawData = try await client
            .rpc("rpc_get_operation_targets", params: params)
            .execute()
            .data
        
        if let jsonString = String(data: rawData, encoding: .utf8) {
            print("🔍 RAW JSON Response:\n\(jsonString)")
        }
        
        let response: TargetResponse = try JSONDecoder().decode(TargetResponse.self, from: rawData)
        
        print("🔍 RPC Response: \(response.targets.count) targets, \(response.staging.count) staging")
        
        // Convert to OpTarget objects
        var targets: [OpTarget] = []
        for targetData in response.targets {
            guard let targetId = UUID(uuidString: targetData.id) else { continue }
            
            print("   🎯 Target from DB: \(targetData.type) - \(targetData.id)")
            
            switch targetData.type {
            case "person":
                if let person = targetData.person {
                    var target = OpTarget(
                        id: targetId,
                        kind: .person,
                        personName: "\(person.first_name ?? "") \(person.last_name ?? "")".trimmingCharacters(in: .whitespaces),
                        phone: person.phone_number
                    )
                    target.images = parseImages(person.images)
                    targets.append(target)
                    print("      Person: \(target.label) - \(target.images.count) image(s)")
                }
            case "vehicle":
                if let vehicle = targetData.vehicle {
                    var target = OpTarget(
                        id: targetId,
                        kind: .vehicle,
                        vehicleMake: vehicle.make,
                        vehicleModel: vehicle.model,
                        vehicleColor: vehicle.color,
                        licensePlate: vehicle.plate
                    )
                    target.images = parseImages(vehicle.images)
                    targets.append(target)
                    print("      Vehicle: \(target.label) - \(target.images.count) image(s)")
                }
            case "location":
                if let location = targetData.location {
                    var target = OpTarget(
                        id: targetId,
                        kind: .location,
                        locationName: location.label,
                        locationAddress: location.address
                    )
                    // Set coordinates from database
                    target.locationLat = location.latitude
                    target.locationLng = location.longitude
                    // Set label from database (prioritize custom label)
                    target.label = location.label ?? location.address
                    target.images = parseImages(location.images)
                    targets.append(target)
                    print("      Location: \(target.label) - has coordinates: \(target.coordinate != nil) - lat:\(location.latitude ?? 0), lng:\(location.longitude ?? 0) - \(target.images.count) image(s)")
                }
            default:
                break
            }
        }
        
        print("✅ Converted \(targets.count) targets")
        
        // Convert to StagingPoint objects
        var staging: [StagingPoint] = []
        for stagingData in response.staging {
            guard let stagingId = UUID(uuidString: stagingData.id) else {
                print("⚠️ Invalid staging ID: \(stagingData.id)")
                continue
            }
            
            print("   📍 Staging from DB: \(stagingData.label) at (\(stagingData.latitude), \(stagingData.longitude))")
            
            let point = StagingPoint(
                id: stagingId,
                label: stagingData.label,
                address: "", // Address stored as coordinates in database
                lat: stagingData.latitude,
                lng: stagingData.longitude
            )
            staging.append(point)
        }
        
        print("✅ Converted \(staging.count) staging points")
        return (targets, staging)
        
        // Helper function to parse images
        func parseImages(_ imageDataArray: [ImageData]?) -> [OpTargetImage] {
            guard let imageDataArray = imageDataArray else { return [] }
            
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            return imageDataArray.compactMap { imageData in
                guard let imageId = UUID(uuidString: imageData.id) else { return nil }
                
                let storageKind: OpTargetImage.StorageKind = imageData.storage_kind == "remoteURL" ? .remoteURL : .localFile
                let remoteURL = imageData.remote_url.flatMap { URL(string: $0) }
                let createdAt = dateFormatter.date(from: imageData.created_at) ?? Date()
                
                return OpTargetImage(
                    id: imageId,
                    storageKind: storageKind,
                    localPath: imageData.local_path,
                    remoteURL: remoteURL,
                    filename: imageData.filename,
                    pixelWidth: imageData.pixel_width,
                    pixelHeight: imageData.pixel_height,
                    byteSize: imageData.byte_size,
                    createdAt: createdAt,
                    caption: imageData.caption
                )
            }
        }
    }
    
    /// Get all members of an operation (for assignment purposes)
    nonisolated func getOperationMembers(operationId: UUID) async throws -> [User] {
        print("🔍 getOperationMembers: Querying operation_members for operation \(operationId)")
        
        // First, get all member user IDs for this operation
        struct MemberRecord: Decodable, Sendable {
            let user_id: String
            let left_at: String?
        }
        
        let members: [MemberRecord] = try await client
            .from("operation_members")
            .select("user_id, left_at")
            .eq("operation_id", value: operationId.uuidString)
            .execute()
            .value
        
        print("📊 Retrieved \(members.count) total member records from operation_members")
        for (index, member) in members.enumerated() {
            print("   [\(index + 1)] user_id: \(member.user_id), left_at: \(member.left_at ?? "nil")")
        }
        
        // Filter to active members only
        let activeUserIds = members
            .filter { $0.left_at == nil }
            .compactMap { UUID(uuidString: $0.user_id) }
        
        print("📋 Filtered to \(activeUserIds.count) active member IDs (left_at = nil)")
        
        guard !activeUserIds.isEmpty else {
            print("⚠️ No active members found for operation \(operationId)")
            return []
        }
        
        print("🔄 Fetching user details for \(activeUserIds.count) members...")
        
        // Now fetch user details for these IDs
        struct UserRecord: Decodable, Sendable {
            let id: String
            let email: String?
            let first_name: String?
            let last_name: String?
            let full_name: String?
            let callsign: String?
            let phone_number: String?
            let vehicle_type: String?
            let vehicle_color: String?
        }
        
        let userIdStrings = activeUserIds.map { $0.uuidString }
        let users: [UserRecord] = try await client
            .from("users")
            .select("id, email, first_name, last_name, full_name, callsign, phone_number, vehicle_type, vehicle_color")
            .in("id", values: userIdStrings)
            .execute()
            .value
        
        print("✅ Fetched \(users.count) user records")
        
        return users.compactMap { userRecord -> User? in
            guard let userId = UUID(uuidString: userRecord.id) else { return nil }
            
            // Parse vehicle type
            let vehicleType: VehicleType
            if let typeString = userRecord.vehicle_type {
                vehicleType = VehicleType(rawValue: typeString) ?? .sedan
            } else {
                vehicleType = .sedan
            }
            
            print("   User: \(userRecord.full_name ?? "no name"), callsign: \(userRecord.callsign ?? "none"), email: \(userRecord.email ?? "none"), phone: \(userRecord.phone_number ?? "none")")
            
            return User(
                id: userId,
                email: userRecord.email ?? "",
                teamId: UUID(), // Not needed for assignment
                agencyId: UUID(), // Not needed for assignment
                firstName: userRecord.first_name,
                lastName: userRecord.last_name,
                callsign: userRecord.callsign,
                phoneNumber: userRecord.phone_number,
                vehicleType: vehicleType,
                vehicleColor: userRecord.vehicle_color ?? "#808080"
            )
        }
    }
    
    // MARK: - Fetch Operations
    
    /// Get all active operations in the system
    nonisolated func getAllActiveOperations() async throws -> [(operation: Operation, isMember: Bool)] {
        struct Response: Decodable {
            let id: String
            let name: String
            let incident_number: String?
            let status: String
            let created_at: String
            let started_at: String?
            let ended_at: String?
            let case_agent_id: String
            let team_id: String
            let agency_id: String
            let is_member: Bool
        }
        
        let responses: [Response] = try await client
            .rpc("rpc_get_all_active_operations")
            .execute()
            .value
        
        print("🔄 Loaded \(responses.count) active operations from database")
        
        // Convert to Operation objects with membership status
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var results: [(operation: Operation, isMember: Bool)] = []
        
        for response in responses {
            guard let id = UUID(uuidString: response.id),
                  let caseAgentId = UUID(uuidString: response.case_agent_id),
                  let teamId = UUID(uuidString: response.team_id),
                  let agencyId = UUID(uuidString: response.agency_id),
                  let createdAt = dateFormatter.date(from: response.created_at) else {
                print("      ⚠️ Skipping operation with invalid data: \(response.name)")
                continue
            }
            
            let state: OperationState
            switch response.status {
            case "active": state = .active
            case "ended": state = .ended
            default: state = .active  // Default to active
            }
            
            let operation = Operation(
                id: id,
                name: response.name,
                incidentNumber: response.incident_number,
                state: state,
                createdAt: createdAt,
                startsAt: response.started_at.flatMap { dateFormatter.date(from: $0) },
                endsAt: response.ended_at.flatMap { dateFormatter.date(from: $0) },
                createdByUserId: caseAgentId,
                teamId: teamId,
                agencyId: agencyId
            )
            
            results.append((operation: operation, isMember: response.is_member))
            print("  ✅ \(operation.name) - Member: \(response.is_member ? "Yes" : "No")")
        }
        
        print("✅ Loaded \(results.count) active operations")
        return results
    }
    
    // MARK: - Request to Join
    
    /// Request to join an operation
    nonisolated func requestJoinOperation(operationId: UUID) async throws {
        struct Params: Encodable, Sendable {
            let operation_id: String
        }
        
        struct Response: Decodable, Sendable {
            let request_id: String
        }
        
        let params = Params(operation_id: operationId.uuidString)
        
        let _: Response = try await client
            .rpc("rpc_request_join_operation", params: params)
            .execute()
            .value
        
        print("✅ Join request sent for operation: \(operationId)")
    }
    
    // MARK: - Join Requests
    
    /// Get pending join requests for an operation (case agent only)
    nonisolated func getPendingJoinRequests(operationId: UUID) async throws -> [JoinRequest] {
        struct Response: Decodable {
            let id: String
            let requester_user_id: String
            let created_at: String
        }
        
        let responses: [Response] = try await client
            .from("join_requests")
            .select("id, requester_user_id, created_at")
            .eq("operation_id", value: operationId.uuidString)
            .eq("status", value: "pending")
            .order("created_at", ascending: true)
            .execute()
            .value
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return responses.compactMap { response -> JoinRequest? in
            guard let id = UUID(uuidString: response.id),
                  let requesterId = UUID(uuidString: response.requester_user_id),
                  let createdAt = dateFormatter.date(from: response.created_at) else {
                return nil
            }
            
            return JoinRequest(
                id: id,
                operationId: operationId,
                requesterUserId: requesterId,
                status: .pending,
                createdAt: createdAt
            )
        }
    }
    
    /// Approve a join request and add user to operation
    nonisolated func approveJoinRequest(requestId: UUID, operationId: UUID) async throws {
        struct Params: Encodable, Sendable {
            let request_id: String
            let operation_id: String
        }
        
        struct Response: Decodable, Sendable {
            let success: Bool
        }
        
        let params = Params(
            request_id: requestId.uuidString,
            operation_id: operationId.uuidString
        )
        
        let _: Response = try await client
            .rpc("rpc_approve_join_request", params: params)
            .execute()
            .value
        
        print("✅ Join request approved")
    }
    
    /// Reject a join request
    nonisolated func rejectJoinRequest(requestId: UUID) async throws {
        struct Params: Encodable, Sendable {
            let request_id: String
        }
        
        struct Response: Decodable, Sendable {
            let success: Bool
        }
        
        let params = Params(request_id: requestId.uuidString)
        
        let _: Response = try await client
            .rpc("rpc_reject_join_request", params: params)
            .execute()
            .value
        
        print("✅ Join request rejected")
    }
    
    // MARK: - Team Management
    
    /// Get team roster with operation status
    nonisolated func getTeamRoster() async throws -> [TeamMember] {
        struct Response: Decodable {
            let id: String
            let full_name: String
            let email: String
            let callsign: String?
            let in_operation: Bool
            let operation_id: String?
        }
        
        let responses: [Response] = try await client
            .rpc("rpc_get_team_roster")
            .execute()
            .value
        
        print("🔄 Loaded \(responses.count) team members")
        
        return responses.compactMap { response in
            guard let userId = UUID(uuidString: response.id) else {
                print("⚠️ Skipping team member with invalid ID: \(response.id)")
                return nil
            }
            
            let operationId = response.operation_id.flatMap { UUID(uuidString: $0) }
            
            return TeamMember(
                id: userId,
                fullName: response.full_name,
                email: response.email,
                callsign: response.callsign,
                inOperation: response.in_operation,
                operationId: operationId
            )
        }
    }
    
    /// Add multiple members to an operation
    nonisolated func addOperationMembers(operationId: UUID, memberIds: [UUID]) async throws -> Int {
        struct Params: Encodable, Sendable {
            let p_operation_id: String
            let p_member_user_ids: [String]
        }
        
        struct Response: Decodable, Sendable {
            let added_count: Int
        }
        
        let params = Params(
            p_operation_id: operationId.uuidString,
            p_member_user_ids: memberIds.map { $0.uuidString }
        )
        
        let response: Response = try await client
            .rpc("rpc_add_operation_members", params: params)
            .execute()
            .value
        
        print("✅ Added \(response.added_count) members to operation")
        return response.added_count
    }
    
    /// Update operation details (name, incident number)
    nonisolated func updateOperation(operationId: UUID, name: String, incidentNumber: String?) async throws {
        struct Params: Encodable, Sendable {
            let operation_id: String
            let name: String
            let incident_number: String?
        }
        
        struct Response: Decodable, Sendable {
            let success: Bool
        }
        
        let params = Params(
            operation_id: operationId.uuidString,
            name: name,
            incident_number: incidentNumber
        )
        
        let _: Response = try await client
            .rpc("rpc_update_operation", params: params)
            .execute()
            .value
        
        print("✅ Operation updated")
    }
    
    /// Get previous (ended) operations
    nonisolated func getPreviousOperations() async throws -> [Operation] {
        struct Response: Decodable {
            let id: String
            let name: String
            let incident_number: String?
            let status: String
            let created_at: String
            let started_at: String?
            let ended_at: String?
            let case_agent_id: String
            let team_id: String
            let agency_id: String
        }
        
        let responses: [Response] = try await client
            .rpc("rpc_get_previous_operations")
            .execute()
            .value
        
        print("🔄 Loaded \(responses.count) previous operations")
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return responses.compactMap { response in
            guard let id = UUID(uuidString: response.id),
                  let caseAgentId = UUID(uuidString: response.case_agent_id),
                  let teamId = UUID(uuidString: response.team_id),
                  let agencyId = UUID(uuidString: response.agency_id),
                  let createdAt = dateFormatter.date(from: response.created_at) else {
                return nil
            }
            
            return Operation(
                id: id,
                name: response.name,
                incidentNumber: response.incident_number,
                state: .ended,
                createdAt: createdAt,
                startsAt: response.started_at.flatMap { dateFormatter.date(from: $0) },
                endsAt: response.ended_at.flatMap { dateFormatter.date(from: $0) },
                createdByUserId: caseAgentId,
                teamId: teamId,
                agencyId: agencyId
            )
        }
    }
    
    /// Get all draft operations for the current user
    nonisolated func getDraftOperations() async throws -> [Operation] {
        struct Response: Decodable {
            let id: String
            let name: String
            let incident_number: String?
            let created_at: String
            let updated_at: String?
            let case_agent_id: String
            let team_id: String
            let agency_id: String
        }
        
        let responses: [Response] = try await client
            .rpc("rpc_get_draft_operations")
            .execute()
            .value
        
        print("🔄 Loaded \(responses.count) draft operations")
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return responses.compactMap { response in
            guard let id = UUID(uuidString: response.id),
                  let caseAgentId = UUID(uuidString: response.case_agent_id),
                  let teamId = UUID(uuidString: response.team_id),
                  let agencyId = UUID(uuidString: response.agency_id),
                  let createdAt = dateFormatter.date(from: response.created_at) else {
                return nil
            }
            
            return Operation(
                id: id,
                name: response.name,
                incidentNumber: response.incident_number,
                state: .draft,
                createdAt: createdAt,
                updatedAt: response.updated_at.flatMap { dateFormatter.date(from: $0) },
                startsAt: nil,
                endsAt: nil,
                createdByUserId: caseAgentId,
                teamId: teamId,
                agencyId: agencyId,
                isDraft: true
            )
        }
    }
    
    // MARK: - Template Functions
    
    /// Save an operation as a template
    nonisolated func saveOperationAsTemplate(
        name: String,
        description: String?,
        isPublic: Bool,
        targets: [OpTarget],
        staging: [StagingPoint]
    ) async throws -> UUID {
        struct Params: Encodable, Sendable {
            let p_name: String
            let p_description: String?
            let p_is_public: Bool
            let p_targets: [[String: AnyCodable]]
            let p_staging: [[String: AnyCodable]]
        }
        
        struct Response: Decodable, Sendable {
            let template_id: String
        }
        
        // Convert targets to JSON-compatible format
        let targetsJson = targets.map { target -> [String: AnyCodable] in
            var dict: [String: AnyCodable] = [
                "kind": AnyCodable(target.kind.rawValue)
            ]
            
            switch target.kind {
            case .person:
                if let firstName = target.personFirstName {
                    dict["person_first_name"] = AnyCodable(firstName)
                }
                if let lastName = target.personLastName {
                    dict["person_last_name"] = AnyCodable(lastName)
                }
                if let phone = target.phone {
                    dict["phone"] = AnyCodable(phone)
                }
            case .vehicle:
                if let make = target.vehicleMake {
                    dict["vehicle_make"] = AnyCodable(make)
                }
                if let model = target.vehicleModel {
                    dict["vehicle_model"] = AnyCodable(model)
                }
                if let color = target.vehicleColor {
                    dict["vehicle_color"] = AnyCodable(color)
                }
                if let plate = target.licensePlate {
                    dict["license_plate"] = AnyCodable(plate)
                }
            case .location:
                if let name = target.locationName {
                    dict["location_name"] = AnyCodable(name)
                }
                if let address = target.locationAddress {
                    dict["location_address"] = AnyCodable(address)
                }
                if let lat = target.locationLat {
                    dict["location_lat"] = AnyCodable(lat)
                }
                if let lng = target.locationLng {
                    dict["location_lng"] = AnyCodable(lng)
                }
            }
            
            return dict
        }
        
        // Convert staging to JSON-compatible format
        let stagingJson = staging.compactMap { stage -> [String: AnyCodable]? in
            guard let lat = stage.lat, let lng = stage.lng else { return nil }
            return [
                "label": AnyCodable(stage.label),
                "address": AnyCodable(stage.address),
                "latitude": AnyCodable(lat),
                "longitude": AnyCodable(lng)
            ]
        }
        
        let params = Params(
            p_name: name,
            p_description: description,
            p_is_public: isPublic,
            p_targets: targetsJson,
            p_staging: stagingJson
        )
        
        let response: Response = try await client
            .rpc("rpc_save_operation_as_template", params: params)
            .execute()
            .value
        
        guard let uuid = UUID(uuidString: response.template_id) else {
            throw SupabaseRPCError.invalidResponse("Invalid template ID format")
        }
        
        return uuid
    }
    
    /// Get templates (personal or agency-wide)
    nonisolated func getTemplates(scope: String) async throws -> [OperationTemplate] {
        struct Params: Encodable, Sendable {
            let p_scope: String
        }
        
        struct Response: Decodable, Sendable {
            let id: String
            let name: String
            let description: String?
            let created_by_user_id: String
            let is_public: Bool
            let created_at: String
            let updated_at: String?
            let target_count: Int
            let staging_count: Int
        }
        
        let params = Params(p_scope: scope)
        
        let responses: [Response] = try await client
            .rpc("rpc_get_templates", params: params)
            .execute()
            .value
        
        print("🔄 Loaded \(responses.count) raw template responses (scope: \(scope))")
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let templates = responses.compactMap { response -> OperationTemplate? in
            print("📋 Processing template: \(response.name)")
            print("   ID: \(response.id)")
            print("   Created by: \(response.created_by_user_id)")
            print("   Created at: \(response.created_at)")
            print("   Target count: \(response.target_count)")
            
            guard let id = UUID(uuidString: response.id) else {
                print("   ❌ Failed to parse template ID")
                return nil
            }
            
            guard let createdByUserId = UUID(uuidString: response.created_by_user_id) else {
                print("   ❌ Failed to parse created_by_user_id")
                return nil
            }
            
            guard let createdAt = dateFormatter.date(from: response.created_at) else {
                print("   ❌ Failed to parse created_at date: \(response.created_at)")
                return nil
            }
            
            print("   ✅ Template parsed successfully")
            
            return OperationTemplate(
                id: id,
                name: response.name,
                description: response.description,
                createdByUserId: createdByUserId,
                teamId: UUID(), // Not returned in list view
                agencyId: UUID(), // Not returned in list view
                createdAt: createdAt,
                updatedAt: response.updated_at.flatMap { dateFormatter.date(from: $0) },
                isPublic: response.is_public,
                targets: [], // Load separately when template is selected
                staging: []  // Load separately when template is selected
            )
        }
        
        print("✅ Successfully parsed \(templates.count) templates")
        return templates
    }
    
    /// Get full template details including targets and staging points
    nonisolated func getTemplateDetails(templateId: UUID) async throws -> OperationTemplate {
        struct Params: Encodable, Sendable {
            let p_template_id: String
        }
        
        struct TargetResponse: Decodable, Sendable {
            let id: String?
            let kind: String
            let person_first_name: String?
            let person_last_name: String?
            let phone: String?
            let vehicle_make: String?
            let vehicle_model: String?
            let vehicle_color: String?
            let license_plate: String?
            let location_name: String?
            let location_address: String?
            let location_lat: Double?
            let location_lng: Double?
        }
        
        struct StagingResponse: Decodable, Sendable {
            let id: String?
            let label: String
            let address: String?
            let latitude: Double
            let longitude: Double
        }
        
        struct Response: Decodable, Sendable {
            let id: String
            let name: String
            let description: String?
            let is_public: Bool
            let created_at: String
            let updated_at: String?
            let targets: [TargetResponse]
            let staging: [StagingResponse]
        }
        
        let params = Params(p_template_id: templateId.uuidString)
        
        let response: Response = try await client
            .rpc("rpc_get_template_details", params: params)
            .execute()
            .value
        
        print("🔄 Loaded template details: \(response.name)")
        print("   Targets: \(response.targets.count)")
        print("   Staging: \(response.staging.count)")
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let id = UUID(uuidString: response.id) else {
            throw SupabaseRPCError.invalidResponse("Invalid template ID")
        }
        
        guard let createdAt = dateFormatter.date(from: response.created_at) else {
            throw SupabaseRPCError.invalidResponse("Invalid created_at date")
        }
        
        // Parse targets
        let targets = response.targets.compactMap { targetResp -> OpTarget? in
            guard let kind = OpTargetKind(rawValue: targetResp.kind) else {
                print("⚠️ Unknown target kind: \(targetResp.kind)")
                return nil
            }
            
            let targetId = targetResp.id.flatMap { UUID(uuidString: $0) } ?? UUID()
            
            // Determine label based on kind
            let label: String
            switch kind {
            case .person:
                let name = [targetResp.person_first_name, targetResp.person_last_name]
                    .compactMap { $0 }
                    .joined(separator: " ")
                label = name.isEmpty ? "Unknown Person" : name
            case .vehicle:
                let desc = [targetResp.vehicle_color, targetResp.vehicle_make, targetResp.vehicle_model]
                    .compactMap { $0 }
                    .joined(separator: " ")
                label = desc.isEmpty ? (targetResp.license_plate ?? "Unknown Vehicle") : desc
            case .location:
                label = targetResp.location_name ?? targetResp.location_address ?? "Unknown Location"
            }
            
            // Create target with all fields
            var target = OpTarget(
                id: targetId,
                kind: kind,
                label: label,
                notes: nil
            )
            
            // Set person fields
            target.personFirstName = targetResp.person_first_name
            target.personLastName = targetResp.person_last_name
            target.personPhone = targetResp.phone
            
            // Set vehicle fields
            target.vehicleMake = targetResp.vehicle_make
            target.vehicleModel = targetResp.vehicle_model
            target.vehicleColor = targetResp.vehicle_color
            target.vehiclePlate = targetResp.license_plate
            
            // Set location fields
            target.locationName = targetResp.location_name
            target.locationAddress = targetResp.location_address
            target.locationLat = targetResp.location_lat
            target.locationLng = targetResp.location_lng
            
            return target
        }
        
        // Parse staging points
        let staging = response.staging.compactMap { stagingResp -> StagingPoint? in
            let stagingId = stagingResp.id.flatMap { UUID(uuidString: $0) } ?? UUID()
            
            print("   📍 Staging from DB: label='\(stagingResp.label)', address='\(stagingResp.address ?? "nil")', lat=\(stagingResp.latitude), lng=\(stagingResp.longitude)")
            
            return StagingPoint(
                id: stagingId,
                label: stagingResp.label,
                address: stagingResp.address ?? "",
                lat: stagingResp.latitude,
                lng: stagingResp.longitude
            )
        }
        
        print("✅ Parsed \(targets.count) targets and \(staging.count) staging points")
        
        return OperationTemplate(
            id: id,
            name: response.name,
            description: response.description,
            createdByUserId: UUID(), // Not needed for template application
            teamId: UUID(), // Not needed
            agencyId: UUID(), // Not needed
            createdAt: createdAt,
            updatedAt: response.updated_at.flatMap { dateFormatter.date(from: $0) },
            isPublic: response.is_public,
            targets: targets,
            staging: staging
        )
    }
}

// MARK: - Supporting Models

// Helper for encoding mixed types
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            try container.encodeNil()
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = ""
        }
    }
}

// MARK: - Supporting Models

struct TeamMember: Identifiable, Decodable {
    let id: UUID
    let fullName: String
    let email: String
    let callsign: String?
    let inOperation: Bool
    let operationId: UUID?
}

enum SupabaseRPCError: LocalizedError {
    case invalidResponse(String)
    case operationNotFound
    case unauthorized
    case operationEnded
    case inviteExpired
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .operationNotFound:
            return "Operation not found"
        case .unauthorized:
            return "You are not authorized to perform this action"
        case .operationEnded:
            return "This operation has ended"
        case .inviteExpired:
            return "This invite has expired"
        }
    }
}
