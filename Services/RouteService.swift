import Foundation
import MapKit
import Combine

/// Service for calculating and managing navigation routes
@MainActor
final class RouteService: ObservableObject {
    static let shared = RouteService()
    
    @Published var activeRoutes: [UUID: RouteInfo] = [:] // assignmentId -> RouteInfo
    
    private init() {}
    
    // MARK: - Route Calculation
    
    /// Calculate route from user's location to assignment
    func calculateRoute(
        from userLocation: CLLocationCoordinate2D,
        to assignment: AssignedLocation
    ) async throws -> RouteInfo {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: assignment.coordinate))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        let response = try await directions.calculate()
        
        guard let route = response.routes.first else {
            throw RouteError.noRouteFound
        }
        
        let routeInfo = RouteInfo(
            assignmentId: assignment.id,
            route: route,
            destination: assignment.coordinate,
            destinationLabel: assignment.label
        )
        
        // Store the route
        activeRoutes[assignment.id] = routeInfo
        
        print("📍 Route calculated: \(routeInfo.distanceText) • \(routeInfo.etaText)")
        
        return routeInfo
    }
    
    /// Recalculate route when user location changes
    func updateRoute(
        assignmentId: UUID,
        from userLocation: CLLocationCoordinate2D
    ) async throws {
        guard let existingRoute = activeRoutes[assignmentId] else {
            print("⚠️ No active route for assignment \(assignmentId)")
            return
        }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: existingRoute.destination))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        let response = try await directions.calculate()
        
        guard let route = response.routes.first else {
            throw RouteError.noRouteFound
        }
        
        let updatedRoute = RouteInfo(
            assignmentId: assignmentId,
            route: route,
            destination: existingRoute.destination,
            destinationLabel: existingRoute.destinationLabel
        )
        
        activeRoutes[assignmentId] = updatedRoute
    }
    
    /// Clear route for a specific assignment
    func clearRoute(assignmentId: UUID) {
        activeRoutes.removeValue(forKey: assignmentId)
        print("🗑️ Cleared route for assignment \(assignmentId)")
    }
    
    /// Clear all routes
    func clearAllRoutes() {
        activeRoutes.removeAll()
        print("🗑️ Cleared all routes")
    }
    
    // MARK: - Route Info Access
    
    /// Get route info for an assignment
    func getRoute(for assignmentId: UUID) -> RouteInfo? {
        return activeRoutes[assignmentId]
    }
    
    /// Get all active routes (for case agent dashboard)
    func getAllRoutes() -> [RouteInfo] {
        return Array(activeRoutes.values)
    }
}

// MARK: - Models

/// Information about a calculated route
struct RouteInfo: Identifiable {
    let id: UUID
    let assignmentId: UUID
    let route: MKRoute
    let destination: CLLocationCoordinate2D
    let destinationLabel: String?
    let calculatedAt: Date
    
    init(assignmentId: UUID, route: MKRoute, destination: CLLocationCoordinate2D, destinationLabel: String?) {
        self.id = UUID()
        self.assignmentId = assignmentId
        self.route = route
        self.destination = destination
        self.destinationLabel = destinationLabel
        self.calculatedAt = Date()
    }
    
    /// Distance in meters
    var distance: CLLocationDistance {
        route.distance
    }
    
    /// Expected travel time in seconds
    var expectedTravelTime: TimeInterval {
        route.expectedTravelTime
    }
    
    /// Distance as human-readable string
    var distanceText: String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return formatter.string(fromDistance: distance)
    }
    
    /// ETA as human-readable string
    var etaText: String {
        let eta = calculatedAt.addingTimeInterval(expectedTravelTime)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: eta)
    }
    
    /// Travel time as human-readable string
    var travelTimeText: String {
        let minutes = Int(expectedTravelTime / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) hr"
            } else {
                return "\(hours) hr \(remainingMinutes) min"
            }
        }
    }
    
    /// Get route polyline for map display
    var polyline: MKPolyline {
        route.polyline
    }
    
    /// Get array of steps for turn-by-turn instructions
    var steps: [MKRoute.Step] {
        route.steps
    }
    
    /// Get next turn instruction (first non-trivial step)
    var nextTurnInstruction: String? {
        // Skip the first step (usually "Head to [destination]")
        guard steps.count > 1 else { return nil }
        
        for step in steps.dropFirst() {
            let instruction = step.instructions
            if !instruction.isEmpty && instruction.lowercased() != "arrive at your destination" {
                return instruction
            }
        }
        
        return "Continue to destination"
    }
    
    /// Distance to next turn in meters
    var distanceToNextTurn: CLLocationDistance? {
        guard steps.count > 1 else { return nil }
        return steps[1].distance
    }
}

enum RouteError: LocalizedError {
    case noRouteFound
    case calculationFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .noRouteFound:
            return "No route could be found to this location"
        case .calculationFailed(let error):
            return "Route calculation failed: \(error.localizedDescription)"
        }
    }
}

