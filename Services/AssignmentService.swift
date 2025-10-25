import Foundation
import CoreLocation
import MapKit
import SwiftUI

@MainActor
final class AssignmentService: ObservableObject {
    static let shared = AssignmentService()
    
    @Published var assignments: [AssignedLocation] = []
    @Published var myAssignment: AssignedLocation?
    @Published var showAssignmentNotification = false
    
    private init() {}
    
    // MARK: - Case Agent Functions
    
    /// Assign a location to a team member
    func assignLocation(
        operationId: UUID,
        toUserId: UUID,
        coordinate: CLLocationCoordinate2D,
        label: String?,
        notes: String?
    ) async throws {
        print("📍 Assigning location to user \(toUserId)")
        
        let response = try await SupabaseRPCService.shared.assignLocation(
            operationId: operationId,
            assignedToUserId: toUserId,
            lat: coordinate.latitude,
            lon: coordinate.longitude,
            label: label,
            notes: notes
        )
        
        print("✅ Assignment created: \(response.assignmentId)")
        
        // Refresh assignments
        try await loadAssignments(for: operationId)
    }
    
    /// Cancel an assignment
    func cancelAssignment(assignmentId: UUID, operationId: UUID) async throws {
        print("🗑️ Cancelling assignment \(assignmentId)")
        
        try await SupabaseRPCService.shared.cancelAssignment(
            assignmentId: assignmentId
        )
        
        print("✅ Assignment cancelled")
        
        // Refresh assignments
        try await loadAssignments(for: operationId)
    }
    
    // MARK: - Team Member Functions
    
    /// Acknowledge assignment and set status to en_route
    func acknowledgeAssignment(assignmentId: UUID) async throws {
        print("✋ Acknowledging assignment \(assignmentId)")
        
        _ = try await SupabaseRPCService.shared.updateAssignmentStatus(
            assignmentId: assignmentId,
            status: "en_route"
        )
        
        print("✅ Status updated to en_route")
        
        // Update local state
        if let index = assignments.firstIndex(where: { $0.id == assignmentId }) {
            assignments[index].status = .enRoute
            assignments[index].acknowledgedAt = Date()
        }
        
        if myAssignment?.id == assignmentId {
            myAssignment?.status = .enRoute
            myAssignment?.acknowledgedAt = Date()
        }
    }
    
    /// Mark assignment as arrived
    func markArrived(assignmentId: UUID) async throws {
        print("🎯 Marking arrived at assignment \(assignmentId)")
        
        _ = try await SupabaseRPCService.shared.updateAssignmentStatus(
            assignmentId: assignmentId,
            status: "arrived"
        )
        
        print("✅ Status updated to arrived")
        
        // Update local state
        if let index = assignments.firstIndex(where: { $0.id == assignmentId }) {
            assignments[index].status = .arrived
            assignments[index].arrivedAt = Date()
        }
        
        if myAssignment?.id == assignmentId {
            myAssignment?.status = .arrived
            myAssignment?.arrivedAt = Date()
            
            // Clear my assignment after a delay
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                myAssignment = nil
                showAssignmentNotification = false
            }
        }
    }
    
    // MARK: - Navigation
    
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
    
    // MARK: - Data Loading
    
    /// Load all assignments for an operation
    func loadAssignments(for operationId: UUID) async throws {
        print("📥 Loading assignments for operation \(operationId)")
        
        let loaded = try await SupabaseRPCService.shared.getOperationAssignments(
            operationId: operationId
        )
        
        assignments = loaded
        
        print("✅ Loaded \(loaded.count) assignment(s)")
        
        // Find my assignment
        if let userId = AppState.shared.currentUserID {
            let myActiveAssignments = assignments.filter { 
                $0.assignedToUserId == userId && 
                ($0.status == .assigned || $0.status == .enRoute)
            }
            
            if let newAssignment = myActiveAssignments.first {
                // Check if this is a new assignment
                if myAssignment?.id != newAssignment.id {
                    myAssignment = newAssignment
                    showAssignmentNotification = true
                    print("🔔 New assignment received: \(newAssignment.label ?? "Unknown")")
                } else {
                    myAssignment = newAssignment
                }
            } else if myAssignment != nil {
                // Clear assignment if no longer active
                myAssignment = nil
                showAssignmentNotification = false
            }
        }
    }
    
    /// Clear all assignment data (when leaving operation)
    func clearAssignments() {
        assignments = []
        myAssignment = nil
        showAssignmentNotification = false
        print("🗑️ Cleared all assignments")
    }
    
    // MARK: - Distance Calculation
    
    /// Calculate distance from user location to assignment
    func distance(from userLocation: CLLocation, to assignment: AssignedLocation) -> CLLocationDistance {
        let assignedLocation = CLLocation(
            latitude: assignment.lat,
            longitude: assignment.lon
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
    
    /// Check if user is near the assigned location
    func isNearAssignment(
        userLocation: CLLocation,
        assignment: AssignedLocation,
        threshold: CLLocationDistance = 50 // 50 meters
    ) -> Bool {
        distance(from: userLocation, to: assignment) <= threshold
    }
    
    // MARK: - Real-time Updates
    
    /// Subscribe to assignment updates for an operation
    func subscribeToAssignments(operationId: UUID) {
        // TODO: Implement Postgres Changes subscription
        // Subscribe to INSERT/UPDATE on assigned_locations table
        print("🔔 Subscribing to assignment updates for operation \(operationId)")
    }
    
    /// Unsubscribe from assignment updates
    func unsubscribeFromAssignments() {
        // TODO: Implement unsubscribe
        print("🔕 Unsubscribing from assignment updates")
    }
}

