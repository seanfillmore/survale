import SwiftUI
import CoreLocation

struct AssignmentBanner: View {
    let assignment: AssignedLocation
    @StateObject private var locationService = LocationService.shared
    @StateObject private var routeService = RouteService.shared
    @State private var showingDetails = false
    
    var distanceText: String {
        // Use route distance if available, otherwise straight-line distance
        if let routeInfo = routeService.getRoute(for: assignment.id) {
            return routeInfo.distanceText
        }
        
        guard let userLocation = locationService.lastLocation else {
            return "Calculating..."
        }
        return AssignmentService.shared.distanceString(
            from: userLocation,
            to: assignment
        )
    }
    
    var etaText: String? {
        // Only show ETA if we have a calculated route
        guard let routeInfo = routeService.getRoute(for: assignment.id) else {
            return nil
        }
        return routeInfo.travelTimeText
    }
    
    var statusColor: Color {
        switch assignment.status {
        case .assigned: return .blue
        case .enRoute: return .orange
        case .arrived: return .green
        case .cancelled: return .gray
        }
    }
    
    var body: some View {
        Button {
            showingDetails = true
        } label: {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: assignment.status.icon)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                    .frame(width: 40)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(statusText)
                            .font(.headline)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            if let eta = etaText {
                                Text(eta)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(statusColor)
                            }
                            Text(distanceText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Text(assignment.label ?? "Assigned Location")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(statusColor.opacity(0.1))
            .cornerRadius(12)
        }
        .sheet(isPresented: $showingDetails) {
            AssignmentDetailView(assignment: assignment)
        }
    }
    
    private var statusText: String {
        switch assignment.status {
        case .assigned: return "New Assignment"
        case .enRoute: return "En Route"
        case .arrived: return "Arrived"
        case .cancelled: return "Cancelled"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        AssignmentBanner(
            assignment: AssignedLocation(
                id: UUID(),
                operationId: UUID(),
                assignedByUserId: UUID(),
                assignedToUserId: UUID(),
                latitude: 34.0522,
                longitude: -118.2437,
                label: "North Entry Point",
                notes: "Cover the north entrance",
                status: .assigned,
                assignedAt: Date(),
                assignedToCallsign: "ALPHA-1"
            )
        )
        
        AssignmentBanner(
            assignment: AssignedLocation(
                id: UUID(),
                operationId: UUID(),
                assignedByUserId: UUID(),
                assignedToUserId: UUID(),
                latitude: 34.0522,
                longitude: -118.2437,
                label: "Observation Post 2",
                notes: nil,
                status: .enRoute,
                assignedAt: Date(),
                assignedToCallsign: "BRAVO-2"
            )
        )
    }
    .padding()
}

