import Foundation
import Supabase
import Combine
import MapKit
import SwiftUI

final class AssignmentService: ObservableObject {
    static let shared = AssignmentService()

    @Published var assignedLocations: [AssignedLocation] = []
    @Published var activeOperationId: UUID?

    private var rpcService: SupabaseRPCService
    private var realtimeService: RealtimeService
    private var cancellables = Set<AnyCancellable>()

    private init(rpcService: SupabaseRPCService = .shared, realtimeService: RealtimeService = .shared) {
        self.rpcService = rpcService
        self.realtimeService = realtimeService

        // Observe active operation changes from RealtimeService
        realtimeService.$activeOperationId
            .sink { [weak self] newOperationId in
                guard let self else { return }
                if self.activeOperationId != newOperationId {
                    self.activeOperationId = newOperationId
                    Task { await self.setupRealtimeSubscription(for: newOperationId) }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// Assigns a new location to a team member.
    func assignLocation(
        operationId: UUID,
        assignedToUserId: UUID,
        coordinate: CLLocationCoordinate2D,
        label: String?,
        notes: String?
    ) async throws -> AssignedLocation {
        print("Attempting to assign location for operation \(operationId) to user \(assignedToUserId)")
        let response = try await rpcService.assignLocation(
            operationId: operationId,
            assignedToUserId: assignedToUserId,
            lat: coordinate.latitude,
            lon: coordinate.longitude,
            label: label,
            notes: notes
        )
        print("✅ Location assigned: \(response.assignment_id)")

        // Immediately fetch all assignments to update local state
        // This ensures the UI is updated even before realtime kicks in
        await fetchAssignments(for: operationId)

        // Find and return the newly assigned location
        guard let newAssignment = assignedLocations.first(where: { $0.id.uuidString == response.assignment_id }) else {
            throw AssignmentError.notFound("Newly assigned location not found after fetch.")
        }
        return newAssignment
    }

    /// Updates the status of an assigned location.
    func updateAssignmentStatus(assignmentId: UUID, status: AssignmentStatus) async throws {
        print("Attempting to update assignment \(assignmentId) status to \(status.rawValue)")
        _ = try await rpcService.updateAssignmentStatus(
            assignmentId: assignmentId,
            status: status.rawValue
        )
        print("✅ Assignment \(assignmentId) status updated to \(status.rawValue)")
        await fetchAssignments(for: activeOperationId) // Refresh all to ensure consistency
    }

    /// Cancels an assigned location.
    func cancelAssignment(assignmentId: UUID) async throws {
        print("Attempting to cancel assignment \(assignmentId)")
        try await rpcService.cancelAssignment(assignmentId: assignmentId)
        print("✅ Assignment \(assignmentId) cancelled")
        await fetchAssignments(for: activeOperationId) // Refresh all to ensure consistency
    }

    /// Fetches all assigned locations for the current active operation.
    func fetchAssignments(for operationId: UUID?) async {
        guard let operationId = operationId else {
            await MainActor.run { self.assignedLocations = [] }
            return
        }
        print("Fetching assigned locations for operation \(operationId)")
        do {
            let fetched = try await rpcService.getOperationAssignments(operationId: operationId)
            await MainActor.run {
                self.assignedLocations = fetched
                print("✅ Fetched \(fetched.count) assigned locations.")
            }
        } catch {
            print("❌ Failed to fetch assigned locations: \(error)")
            await MainActor.run { self.assignedLocations = [] }
        }
    }

    // MARK: - Team Member Functions
    
    /// Acknowledge assignment and set status to en_route
    func acknowledgeAssignment(assignmentId: UUID) async throws {
        try await updateAssignmentStatus(assignmentId: assignmentId, status: .enRoute)
    }
    
    /// Mark assignment as arrived
    func markArrived(assignmentId: UUID) async throws {
        try await updateAssignmentStatus(assignmentId: assignmentId, status: .arrived)
    }
    
    /// Open Apple Maps with turn-by-turn directions to assignment
    func startNavigation(to assignment: AssignedLocation) {
        print("🧭 Starting navigation to \(assignment.label ?? "assignment")")
        
        let placemark = MKPlacemark(coordinate: assignment.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = assignment.label ?? "Assigned Location"
        
        let launchOptions = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
        
        // Auto-acknowledge if not already
        if assignment.status == .assigned {
            Task {
                try? await acknowledgeAssignment(assignmentId: assignment.id)
            }
        }
    }
    
    // MARK: - Distance Calculation
    
    /// Calculate distance from user location to assignment
    func distance(from userLocation: CLLocation, to assignment: AssignedLocation) -> CLLocationDistance {
        let assignedLocation = CLLocation(
            latitude: assignment.latitude,
            longitude: assignment.longitude
        )
        return userLocation.distance(from: assignedLocation)
    }
    
    /// Format distance as readable string
    func distanceString(from userLocation: CLLocation, to assignment: AssignedLocation) -> String {
        let dist = distance(from: userLocation, to: assignment)
        
        if dist < 1000 {
            return String(format: "%.0f m", dist)
        } else {
            return String(format: "%.1f km", dist / 1000)
        }
    }

    // MARK: - Realtime Subscription

    private func setupRealtimeSubscription(for operationId: UUID?) async {
        // Unsubscribe from previous channel if any
        realtimeService.unsubscribe(channelName: "db-changes-assigned-locations")

        guard let operationId = operationId else {
            await MainActor.run { self.assignedLocations = [] }
            return
        }

        print("Setting up realtime subscription for assigned_locations on operation \(operationId)")

        let channel = SupabaseClient.shared.client.channel("db-changes-assigned-locations")

        let insertChanges = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "assigned_locations",
            filter: "operation_id=eq.\(operationId.uuidString)"
        )

        let updateChanges = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "assigned_locations",
            filter: "operation_id=eq.\(operationId.uuidString)"
        )

        let deleteChanges = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "assigned_locations",
            filter: "operation_id=eq.\(operationId.uuidString)"
        )

        Task {
            for await change in insertChanges {
                print("⚡️ Realtime: New assigned location inserted: \(change.record.id)")
                await handleAssignmentChange(change.record)
            }
        }
        .store(in: &cancellables) // Store the task to cancel on deinit

        Task {
            for await change in updateChanges {
                print("⚡️ Realtime: Assigned location updated: \(change.record.id)")
                await handleAssignmentChange(change.record)
            }
        }
        .store(in: &cancellables)

        Task {
            for await change in deleteChanges {
                print("⚡️ Realtime: Assigned location deleted: \(change.oldRecord.id)")
                await handleAssignmentDelete(change.oldRecord)
            }
        }
        .store(in: &cancellables)

        await channel.subscribe()
        print("✅ Realtime subscription for assigned_locations active.")

        // Initial fetch after subscription is set up
        await fetchAssignments(for: operationId)
    }

    @MainActor
    private func handleAssignmentChange(_ record: AssignedLocation) {
        if let index = assignedLocations.firstIndex(where: { $0.id == record.id }) {
            assignedLocations[index] = record // Update existing
        } else {
            assignedLocations.append(record) // Add new
        }
    }

    @MainActor
    private func handleAssignmentDelete(_ oldRecord: [String: Any]) {
        if let idString = oldRecord["id"] as? String, let id = UUID(uuidString: idString) {
            assignedLocations.removeAll { $0.id == id }
        }
    }

    // MARK: - Error Handling

    enum AssignmentError: LocalizedError {
        case notFound(String)
        case unknown(String)

        var errorDescription: String? {
            switch self {
            case .notFound(let message): return "Assignment Not Found: \(message)"
            case .unknown(let message): return "Unknown Assignment Error: \(message)"
            }
        }
    }
}
