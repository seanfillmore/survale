//
//  OperationStore.swift
//  Survale
//
//  Created by Sean Fillmore on 10/17/25.
//
import SwiftUI
import Combine

@MainActor
final class OperationStore: ObservableObject {
    static let shared = OperationStore()
    
    @Published var operations: [Operation] = []
    @Published var previousOperations: [Operation] = []  // Ended operations
    @Published var memberOperationIds: Set<UUID> = []  // Track which operations user is a member of
    @Published var isLoading = false
    @Published var error: String?
    
    private let rpcService = SupabaseRPCService.shared
    private let dbService = DatabaseService.shared
    
    private init() {}
    
    /// Check if user is a member of an operation
    func isMember(of operationId: UUID) -> Bool {
        memberOperationIds.contains(operationId)
    }
    
    // MARK: - Create Operation
    
    /// Create a new operation (draft state)
    func create(
        name: String,
        incidentNumber: String? = nil,
        userId: UUID,
        teamId: UUID,
        agencyId: UUID,
        targets: [OpTarget] = [],
        staging: [StagingPoint] = []
    ) async throws -> Operation {
        isLoading = true
        error = nil
        
        do {
            // Call RPC to create operation on server
            let operationId = try await rpcService.createOperation(
                name: name,
                incidentNumber: incidentNumber
            )
            
            // Create local operation object
            let operation = Operation(
                id: operationId,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Operation" : name,
                incidentNumber: incidentNumber,
                state: .active,  // Operations are active by default
                createdAt: Date(),
                startsAt: Date(),  // Active from creation
                endsAt: nil,
                createdByUserId: userId,
                teamId: teamId,
                agencyId: agencyId,
                targets: targets,
                staging: staging
            )
            
            // Add to local list
            operations.insert(operation, at: 0)
            
            // Add creator as member (they created it, so they're automatically a member)
            memberOperationIds.insert(operationId)
            print("✅ Added operation \(operationId) to memberOperationIds")
            
            // Save targets to database
            print("💾 Saving \(targets.count) targets and \(staging.count) staging points to database...")
            
            for target in targets {
                do {
                    // Convert OpTargetImage to dictionary for RPC
                    let imagesDicts = target.images.map { img -> [String: Any] in
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        
                        var dict: [String: Any] = [
                            "id": img.id.uuidString,
                            "storage_kind": img.storageKind.rawValue,
                            "filename": img.filename,
                            "created_at": formatter.string(from: img.createdAt)
                        ]
                        if let url = img.remoteURL {
                            dict["remote_url"] = url.absoluteString
                        }
                        if let localPath = img.localPath {
                            dict["local_path"] = localPath
                        }
                        if let caption = img.caption {
                            dict["caption"] = caption
                        }
                        if let width = img.pixelWidth {
                            dict["pixel_width"] = width
                        }
                        if let height = img.pixelHeight {
                            dict["pixel_height"] = height
                        }
                        if let size = img.byteSize {
                            dict["byte_size"] = size
                        }
                        return dict
                    }
                    
                    switch target.kind {
                    case .person:
                        _ = try await rpcService.createPersonTarget(
                            operationId: operationId,
                            firstName: target.personFirstName ?? "",
                            lastName: target.personLastName ?? "",
                            phone: target.phone,
                            images: imagesDicts
                        )
                    case .vehicle:
                        _ = try await rpcService.createVehicleTarget(
                            operationId: operationId,
                            make: target.vehicleMake,
                            model: target.vehicleModel,
                            color: target.vehicleColor,
                            plate: target.licensePlate,
                            images: imagesDicts
                        )
                    case .location:
                        _ = try await rpcService.createLocationTarget(
                            operationId: operationId,
                            address: target.locationAddress ?? "",
                            label: target.locationName,
                            city: nil,
                            zipCode: nil,
                            latitude: target.locationLat,
                            longitude: target.locationLng,
                            images: imagesDicts
                        )
                    }
                    print("  ✅ Saved target: \(target.label) (\(target.images.count) image(s))")
                } catch {
                    print("  ⚠️ Failed to save target \(target.label): \(error)")
                }
            }
            
            // Save staging points to database
            for stage in staging {
                // Staging points need coordinates - skip if not geocoded yet
                guard let lat = stage.lat, let lng = stage.lng else {
                    print("  ⚠️ Skipping staging point \(stage.label): no coordinates (address needs to be geocoded)")
                    continue
                }
                
                do {
                    _ = try await rpcService.createStagingPoint(
                        operationId: operationId,
                        label: stage.label,
                        latitude: lat,
                        longitude: lng
                    )
                    print("  ✅ Saved staging point: \(stage.label)")
                } catch {
                    print("  ⚠️ Failed to save staging point \(stage.label): \(error)")
                }
            }
            
            isLoading = false
            return operation
            
        } catch {
            isLoading = false
            self.error = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Operation Lifecycle
    
    /// Start an operation (changes to active state)
    func startOperation(_ operationId: UUID) async throws {
        isLoading = true
        error = nil
        
        do {
            try await rpcService.startOperation(operationId: operationId)
            
            // Update local state
            if let index = operations.firstIndex(where: { $0.id == operationId }) {
                operations[index].state = .active
                operations[index].startsAt = Date()
            }
            
            isLoading = false
        } catch {
            isLoading = false
            self.error = error.localizedDescription
            throw error
        }
    }
    
    /// End an operation (changes to ended state)
    func endOperation(_ operationId: UUID) async throws {
        isLoading = true
        error = nil
        
        do {
            try await rpcService.endOperation(operationId: operationId)
            
            // Update local state
            if let index = operations.firstIndex(where: { $0.id == operationId }) {
                operations[index].state = .ended
                operations[index].endsAt = Date()
            }
            
            isLoading = false
        } catch {
            isLoading = false
            self.error = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Load Operations
    
    /// Load all active operations (with membership info)
    func loadOperations(for userID: UUID) async {
        isLoading = true
        error = nil
        
        do {
            print("🔄 Loading all active operations...")
            let results = try await rpcService.getAllActiveOperations()
            
            // Also load previous (ended) operations
            print("🔄 Loading previous operations...")
            let previousOps = try await rpcService.getPreviousOperations()
            
            await MainActor.run {
                self.operations = results.map { $0.operation }
                self.previousOperations = previousOps
                self.memberOperationIds = Set(results.filter { $0.isMember }.map { $0.operation.id })
                
                print("✅ Loaded \(results.count) active operations, \(previousOps.count) previous operations")
                
                // Find which operation user is a member of
                if let myOperation = results.first(where: { $0.isMember }) {
                    print("   👤 You are in: \(myOperation.operation.name)")
                } else {
                    print("   ℹ️ You are not in any active operation")
                }
                
                for result in results {
                    let memberStatus = result.isMember ? "✅ Member" : "⭕️ Not member"
                    print("   • \(result.operation.name) - \(memberStatus)")
                }
                
                self.isLoading = false
            }
        } catch {
            print("❌ Failed to load operations: \(error)")
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// Clear all operations (for logout)
    func clearOperations() async {
        await MainActor.run {
            self.operations = []
            self.previousOperations = []
            self.memberOperationIds = []
            self.isLoading = false
            self.error = nil
        }
    }
    
    // MARK: - Find Operations
    
    func find(byId id: UUID) -> Operation? {
        operations.first { $0.id == id }
    }
    
    // MARK: - Member Management
    
    /// Invite a user to an operation
    func inviteUser(operationId: UUID, inviteeUserId: UUID) async throws {
        let expiresAt = Date().addingTimeInterval(3600) // 1 hour
        try await rpcService.inviteUser(
            operationId: operationId,
            inviteeUserId: inviteeUserId,
            expiresAt: expiresAt
        )
    }
    
    /// Accept an invite
    func acceptInvite(_ inviteId: UUID) async throws {
        try await rpcService.acceptInvite(inviteId: inviteId)
    }
    
    /// Request to join an operation
    func requestJoin(operationId: UUID) async throws {
        try await rpcService.requestJoin(operationId: operationId)
    }
    
    /// Approve or deny a join request (CA only)
    func approveJoin(requestId: UUID, approve: Bool) async throws {
        try await rpcService.approveJoin(requestId: requestId, approve: approve)
    }
}

// MARK: - Errors

enum OperationStoreError: LocalizedError {
    case notAuthenticated
    case invalidUserId
    case operationNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to perform this action"
        case .invalidUserId:
            return "Invalid user ID"
        case .operationNotFound:
            return "Operation not found"
        }
    }
}
