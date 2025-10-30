import SwiftUI
import MapKit

struct AssignmentDetailView: View {
    let assignment: AssignedLocation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.navigateToMap) private var navigateToMap
    @StateObject private var locationService = LocationService.shared
    @StateObject private var routeService = RouteService.shared
    @State private var cameraPosition: MapCameraPosition
    @State private var isCalculatingRoute = false
    
    init(assignment: AssignedLocation) {
        self.assignment = assignment
        _cameraPosition = State(initialValue: .region(
            MKCoordinateRegion(
                center: assignment.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        ))
    }
    
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
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Map preview
                    Map(position: $cameraPosition) {
                        Marker(
                            assignment.label ?? "Your Assignment",
                            coordinate: assignment.coordinate
                        )
                        .tint(.blue)
                        
                        // Show user location if available
                        if let userLocation = locationService.lastLocation {
                            Marker(
                                "You",
                                coordinate: userLocation.coordinate
                            )
                            .tint(.green)
                        }
                    }
                    .frame(height: 250)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Status badge
                    HStack {
                        Image(systemName: assignment.status.icon)
                        Text(assignment.status.displayName)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(statusColor.opacity(0.15))
                    .cornerRadius(20)
                    
                    // Details
                    VStack(spacing: 16) {
                        if let label = assignment.label {
                            Text(label)
                                .font(.title2.bold())
                        }
                        
                        if let notes = assignment.notes {
                            Text(notes)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundStyle(.blue)
                                Text("Distance: \(distanceText)")
                            }
                            .font(.subheadline)
                            
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundStyle(.blue)
                                Text("Assigned: \(assignment.assignedAt, style: .relative) ago")
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                    
                    // Actions
                    VStack(spacing: 12) {
                        // Navigation button - switches to Map tab and calculates route
                        Button {
                            Task {
                                await startNavigation()
                            }
                        } label: {
                            HStack {
                                if isCalculatingRoute {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "map.fill")
                                        .font(.title3)
                                }
                                Text(isCalculatingRoute ? "Calculating Route..." : "Start Navigation")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isCalculatingRoute)
                        
                        // Status buttons
                        if assignment.status == .assigned {
                            Button {
                                Task {
                                    await acknowledgeAssignment()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle")
                                    Text("I'm On My Way")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.2))
                                .foregroundStyle(.green)
                                .cornerRadius(12)
                            }
                        }
                        
                        if assignment.status == .enRoute {
                            Button {
                                Task {
                                    await markArrived()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("I Am Set")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .cornerRadius(12)
                            }
                        }
                        
                        if assignment.status == .arrived {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Assignment Complete")
                                    .foregroundStyle(.green)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Navigation
    
    private func startNavigation() async {
        guard let userLocation = locationService.lastLocation else {
            print("⚠️ Cannot start navigation - no user location")
            return
        }
        
        isCalculatingRoute = true
        
        print("🗺️ Starting navigation to: \(assignment.label ?? "Unknown")")
        print("   From: (\(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude))")
        print("   To: (\(assignment.coordinate.latitude), \(assignment.coordinate.longitude))")
        
        do {
            let routeInfo = try await routeService.calculateRoute(
                from: userLocation.coordinate,
                to: assignment
            )
            
            print("✅ Route calculated successfully")
            print("   Distance: \(routeInfo.distanceText)")
            print("   Travel time: \(routeInfo.travelTimeText)")
            
            // Switch to Map tab - the map will automatically show the route
            navigateToMap(MapNavigationTarget(
                coordinate: assignment.coordinate,
                label: assignment.label ?? "Your Assignment"
            ))
            
            // Dismiss this view so user sees the map
            dismiss()
            
        } catch {
            print("❌ Route calculation failed: \(error.localizedDescription)")
        }
        
        isCalculatingRoute = false
    }
    
    private func acknowledgeAssignment() async {
        do {
            try await AssignmentService.shared.acknowledgeAssignment(
                assignmentId: assignment.id
            )
            print("✅ Assignment acknowledged")
            // Don't dismiss - let user continue viewing
        } catch {
            print("❌ Error acknowledging assignment: \(error)")
        }
    }
    
    private func markArrived() async {
        do {
            try await AssignmentService.shared.markArrived(
                assignmentId: assignment.id
            )
            print("✅ Marked as arrived")
            
            // Dismiss after a short delay
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        } catch {
            print("❌ Error marking arrived: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    AssignmentDetailView(
        assignment: AssignedLocation(
            id: UUID(),
            operationId: UUID(),
            assignedByUserId: UUID(),
            assignedToUserId: UUID(),
            latitude: 34.0522,
            longitude: -118.2437,
            label: "North Entry Point",
            notes: "Cover the north entrance and monitor all incoming vehicles",
            status: .assigned,
            assignedAt: Date().addingTimeInterval(-300), // 5 minutes ago
            assignedToCallsign: "ALPHA-1"
        )
    )
}

