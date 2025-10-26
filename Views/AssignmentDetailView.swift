import SwiftUI
import MapKit

struct AssignmentDetailView: View {
    let assignment: AssignedLocation
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationService = LocationService.shared
    @State private var cameraPosition: MapCameraPosition
    @State private var showingInAppNavigation = false
    
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
                        // In-app navigation button
                        Button {
                            showingInAppNavigation = true
                        } label: {
                            HStack {
                                Image(systemName: "map.fill")
                                    .font(.title3)
                                Text("Navigate In-App")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }
                        
                        // Apple Maps navigation button
                        Button {
                            startAppleMapsNavigation()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                    .font(.title3)
                                Text("Open in Apple Maps")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .cornerRadius(12)
                        }
                        
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
        .fullScreenCover(isPresented: $showingInAppNavigation) {
            InAppNavigationView(assignment: assignment)
        }
    }
    
    private func startAppleMapsNavigation() {
        AssignmentService.shared.startNavigation(to: assignment)
        dismiss()
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

