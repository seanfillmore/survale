import SwiftUI
import MapKit

struct InAppNavigationView: View {
    let assignment: AssignedLocation
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationService = LocationService.shared
    @StateObject private var routeService = RouteService.shared
    @State private var cameraPosition: MapCameraPosition
    @State private var isFollowingUser = true
    @State private var showingAllSteps = false
    
    init(assignment: AssignedLocation) {
        self.assignment = assignment
        
        // Initialize camera to user location or assignment location
        if let userLocation = LocationService.shared.lastLocation {
            _cameraPosition = State(initialValue: .region(
                MKCoordinateRegion(
                    center: userLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            ))
        } else {
            _cameraPosition = State(initialValue: .region(
                MKCoordinateRegion(
                    center: assignment.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            ))
        }
    }
    
    var routeInfo: RouteInfo? {
        routeService.getRoute(for: assignment.id)
    }
    
    var body: some View {
        ZStack {
            // Map with route
            Map(position: $cameraPosition) {
                // User location
                if let userLocation = locationService.lastLocation {
                    Annotation("You", coordinate: userLocation.coordinate) {
                        ZStack {
                            Circle()
                                .fill(.blue)
                                .frame(width: 20, height: 20)
                            Circle()
                                .stroke(.white, lineWidth: 3)
                                .frame(width: 20, height: 20)
                        }
                    }
                }
                
                // Destination
                Marker(assignment.label ?? "Destination", systemImage: "mappin.circle.fill", coordinate: assignment.coordinate)
                    .tint(.red)
                
                // Route polyline
                if let routeInfo = routeInfo {
                    MapPolyline(routeInfo.polyline)
                        .stroke(.blue, lineWidth: 6)
                }
            }
            .mapStyle(.standard)
            .ignoresSafeArea()
            
            // Navigation instructions overlay
            VStack(spacing: 0) {
                // Top instruction card
                if let routeInfo = routeInfo, let instruction = routeInfo.nextTurnInstruction {
                    navigationInstructionCard(instruction: instruction, distance: routeInfo.distanceToNextTurn)
                        .padding()
                }
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: 12) {
                    // Distance and ETA
                    if let routeInfo = routeInfo {
                        HStack(spacing: 20) {
                            VStack(spacing: 4) {
                                Text(routeInfo.distanceText)
                                    .font(.title2.bold())
                                Text("Distance")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Divider()
                                .frame(height: 40)
                            
                            VStack(spacing: 4) {
                                Text(routeInfo.travelTimeText)
                                    .font(.title2.bold())
                                Text("ETA")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        // Recenter button
                        Button {
                            recenterOnUser()
                        } label: {
                            Image(systemName: isFollowingUser ? "location.fill" : "location")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 50, height: 50)
                                .background(isFollowingUser ? .blue : .gray)
                                .clipShape(Circle())
                        }
                        
                        // Show all steps button
                        Button {
                            showingAllSteps = true
                        } label: {
                            Image(systemName: "list.bullet")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 50, height: 50)
                                .background(.blue)
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        // End navigation button
                        Button {
                            dismiss()
                        } label: {
                            Text("End")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(.red)
                                .cornerRadius(25)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingAllSteps) {
            if let routeInfo = routeInfo {
                TurnByTurnStepsView(steps: routeInfo.steps)
            }
        }
        .onChange(of: locationService.lastLocation) { _, newLocation in
            if isFollowingUser, let location = newLocation {
                withAnimation {
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private func navigationInstructionCard(instruction: String, distance: CLLocationDistance?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let distance = distance {
                Text(formatDistance(distance))
                    .font(.title.bold())
                    .foregroundStyle(.blue)
            }
            
            Text(instruction)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(radius: 4)
    }
    
    private func recenterOnUser() {
        isFollowingUser = true
        if let userLocation = locationService.lastLocation {
            withAnimation {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: userLocation.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )
            }
        }
    }
    
    private func formatDistance(_ meters: CLLocationDistance) -> String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return "In \(formatter.string(fromDistance: meters))"
    }
}

// MARK: - Turn-by-Turn Steps View

struct TurnByTurnStepsView: View {
    let steps: [MKRoute.Step]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        // Step number
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(.blue)
                            .clipShape(Circle())
                        
                        // Step details
                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.instructions)
                                .font(.body)
                            
                            if step.distance > 0 {
                                Text(formatDistance(step.distance))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Turn-by-Turn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDistance(_ meters: CLLocationDistance) -> String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return formatter.string(fromDistance: meters)
    }
}

// MARK: - Preview

#Preview {
    InAppNavigationView(
        assignment: AssignedLocation(
            id: UUID(),
            operationId: UUID(),
            assignedByUserId: UUID(),
            assignedToUserId: UUID(),
            latitude: 34.0522,
            longitude: -118.2437,
            label: "North Entry Point",
            notes: "Cover the north entrance",
            status: .enRoute,
            assignedAt: Date(),
            assignedToCallsign: "ALPHA-1"
        )
    )
}

