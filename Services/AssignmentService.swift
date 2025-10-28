import Foundation
import Supabase
import Combine
import MapKit
import SwiftUI

@MainActor
final class AssignmentService: ObservableObject {
    static let shared = AssignmentService()

    @Published var assignedLocations: [AssignedLocation] = []

    private let client: SupabaseClient
    private var assignmentChannel: RealtimeChannelV2?
    private var currentOperationId: UUID?

    private init() {
        // Use shared client instance to reduce overhead
        self.client = SupabaseClientManager.shared.client
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
        let response = try await SupabaseRPCService.shared.assignLocation(
            operationId: operationId,
            assignedToUserId: assignedToUserId,
            lat: coordinate.latitude,
            lon: coordinate.longitude,
            label: label,
            notes: notes
        )
        print("✅ Location assigned: \(response.assignment_id)")

        // Immediately fetch all assignments to update local state
        await fetchAssignments(for: operationId)

        // Debug: Print all assignment IDs
        print("🔍 Looking for assignment ID: \(response.assignment_id)")
        print("🔍 Available assignments: \(assignedLocations.map { $0.id.uuidString })")

        // Find and return the newly assigned location (case-insensitive comparison)
        guard let newAssignment = assignedLocations.first(where: { 
            $0.id.uuidString.lowercased() == response.assignment_id.lowercased() 
        }) else {
            throw AssignmentError.notFound("Newly assigned location not found after fetch. Looking for \(response.assignment_id), have \(assignedLocations.count) assignments.")
        }
        print("✅ Found newly assigned location!")
        return newAssignment
    }

    /// Updates the status of an assigned location.
    func updateAssignmentStatus(assignmentId: UUID, status: AssignmentStatus) async throws {
        print("Attempting to update assignment \(assignmentId) status to \(status.rawValue)")
        _ = try await SupabaseRPCService.shared.updateAssignmentStatus(
            assignmentId: assignmentId,
            status: status.rawValue
        )
        print("✅ Assignment \(assignmentId) status updated to \(status.rawValue)")
        await fetchAssignments(for: currentOperationId) // Refresh all to ensure consistency
    }

    /// Cancels an assigned location.
    func cancelAssignment(assignmentId: UUID) async throws {
        print("Attempting to cancel assignment \(assignmentId)")
        try await SupabaseRPCService.shared.cancelAssignment(assignmentId: assignmentId)
        print("✅ Assignment \(assignmentId) cancelled")
        await fetchAssignments(for: currentOperationId) // Refresh all to ensure consistency
    }

    /// Fetches all assigned locations for an operation.
    func fetchAssignments(for operationId: UUID?) async {
        guard let operationId = operationId else {
            self.assignedLocations = []
            return
        }
        print("Fetching assigned locations for operation \(operationId)")
        do {
            let fetched = try await SupabaseRPCService.shared.getOperationAssignments(operationId: operationId)
            self.assignedLocations = fetched
            print("✅ Fetched \(fetched.count) assigned locations.")
        } catch {
            print("❌ Failed to fetch assigned locations: \(error)")
            self.assignedLocations = []
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

    /// Subscribe to assignment updates for an operation
    func subscribeToAssignments(operationId: UUID) async {
        // Unsubscribe from previous channel if any
        if let channel = assignmentChannel {
            await channel.unsubscribe()
            assignmentChannel = nil
        }

        currentOperationId = operationId
        
        print("Setting up realtime subscription for assigned_locations on operation \(operationId)")

        let channel = client.channel("db-changes-assigned-locations")

        // Listen for inserts
        _ = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "assigned_locations",
            filter: "operation_id=eq.\(operationId.uuidString)"
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                print("⚡️ Realtime: New assigned location inserted")
                await self.fetchAssignments(for: operationId)
            }
        }

        // Listen for updates
        _ = channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "assigned_locations",
            filter: "operation_id=eq.\(operationId.uuidString)"
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                print("⚡️ Realtime: Assigned location updated")
                await self.fetchAssignments(for: operationId)
            }
        }

        // Listen for deletes
        _ = channel.onPostgresChange(
            DeleteAction.self,
            schema: "public",
            table: "assigned_locations",
            filter: "operation_id=eq.\(operationId.uuidString)"
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                print("⚡️ Realtime: Assigned location deleted")
                await self.fetchAssignments(for: operationId)
            }
        }

        // Subscribe with error handling
        do {
            try await channel.subscribeWithError()
            assignmentChannel = channel
            print("✅ Realtime subscription for assigned_locations active.")
        } catch {
            print("❌ Assignment subscription error: \(error)")
        }

        // Initial fetch after subscription is set up
        await fetchAssignments(for: operationId)
    }
    
    /// Unsubscribe from assignment updates
    func unsubscribeFromAssignments() async {
        if let channel = assignmentChannel {
            await channel.unsubscribe()
            assignmentChannel = nil
            print("🔕 Unsubscribed from assignment updates")
        }
        currentOperationId = nil
        assignedLocations = []
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
