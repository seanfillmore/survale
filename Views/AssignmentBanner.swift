import SwiftUI
import CoreLocation

struct AssignmentBanner: View {
    let assignment: AssignedLocation
    @StateObject private var locationService = LocationService.shared
    @State private var showingDetails = false
    
    var distanceText: String {
        guard let userLocation = locationService.lastLocation else {
            return "Calculating..."
        }
        return AssignmentService.shared.distanceString(
            from: userLocation,
            to: assignment
        )
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
                        
                        Text(distanceText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                lat: 34.0522,
                lon: -118.2437,
                label: "North Entry Point",
                notes: "Cover the north entrance",
                status: .assigned,
                assignedAt: Date(),
                assignedToCallsign: "ALPHA-1",
                assignedToFullName: "John Doe"
            )
        )
        
        AssignmentBanner(
            assignment: AssignedLocation(
                id: UUID(),
                operationId: UUID(),
                assignedByUserId: UUID(),
                assignedToUserId: UUID(),
                lat: 34.0522,
                lon: -118.2437,
                label: "Observation Post 2",
                notes: nil,
                status: .enRoute,
                assignedAt: Date(),
                acknowledgedAt: Date(),
                assignedToCallsign: "BRAVO-2",
                assignedToFullName: "Jane Smith"
            )
        )
    }
    .padding()
}

