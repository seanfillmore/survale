import SwiftUI
import MapKit

struct MapOperationView: View {
    @Binding var navigationTarget: MapNavigationTarget?
    
    @ObservedObject private var loc = LocationService.shared
    @ObservedObject private var realtimeService = RealtimeService.shared
    @EnvironmentObject var appState: AppState
    @ObservedObject private var store = OperationStore.shared
    @ObservedObject private var assignmentService = AssignmentService.shared
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    @State private var targets: [OpTarget] = []
    @State private var stagingPoints: [StagingPoint] = []
    @State private var showTrails = false
    @State private var locationTrails: [UUID: [LocationPoint]] = [:]
    @State private var currentMapStyleType: MapStyleType = .standard
    
    // Assignment-related state
    @State private var showingAssignmentSheet = false
    @State private var assignmentCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    @State private var assignmentOperationId: UUID = UUID()
    @State private var teamMembers: [User] = []
    
    enum MapStyleType {
        case standard, hybrid, satellite
    }

    var body: some View {
        VStack(spacing: 0) {
            // Show assignment banner for current user's assignments
            if let myAssignment = currentUserAssignment {
                AssignmentBanner(assignment: myAssignment)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(uiColor: .systemBackground))
            }
            
            if needsPermissionUI {
                permissionCard
            }
            
            if appState.activeOperationID == nil {
                VStack(spacing: 12) {
                    Image(systemName: "map.circle")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    
                    Text("No active operation")
                        .font(.headline)
                    
                    Text("Create or join an operation in the Ops tab to see the map.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
            } else {
                // Debug: Show staging point count
                if !stagingPoints.isEmpty {
                    Text("Showing \(stagingPoints.count) staging point(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                
                MapReader { proxy in
                    Map(position: $mapPosition, interactionModes: .all) {
                    // User location (distinct from team members)
                    if let userLocation = loc.lastLocation {
                        Annotation("You", coordinate: userLocation.coordinate) {
                            VehicleMarker(
                                vehicleType: appState.currentUser?.vehicleType ?? .sedan,
                                color: appState.currentUser?.vehicleColor ?? "blue",
                                heading: userLocation.course >= 0 ? userLocation.course : nil,
                                isCurrentUser: true
                            )
                        }
                    }
                    
                    // Team member locations
                    ForEach(Array(realtimeService.memberLocations.keys), id: \.self) { userId in
                        if userId != appState.currentUserID,
                           let memberLocation = realtimeService.memberLocations[userId],
                           let lastLocation = memberLocation.lastLocation,
                           memberLocation.isActive {
                            Annotation(memberLocation.callsign ?? "Unit", coordinate: CLLocationCoordinate2D(
                                latitude: lastLocation.latitude,
                                longitude: lastLocation.longitude
                            )) {
                                VehicleMarker(
                                    vehicleType: memberLocation.vehicleType,
                                    color: memberLocation.vehicleColor ?? "gray",
                                    heading: lastLocation.heading,
                                    isCurrentUser: false
                                )
                            }
                        }
                    }
                    
                    // Location trails (if enabled)
                    if showTrails {
                        ForEach(Array(locationTrails.keys), id: \.self) { userId in
                            if let trail = locationTrails[userId], trail.count > 1 {
                                MapPolyline(coordinates: trail.map { point in
                                    CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
                                })
                                .stroke(userId == appState.currentUserID ? .blue : .gray, lineWidth: 2)
                            }
                        }
                    }
                    
                    // Target locations (red pins)
                    ForEach(targets) { target in
                        if let coordinate = target.coordinate {
                            Marker(target.label, systemImage: "target", coordinate: coordinate)
                                .tint(.red)
                        }
                    }
                    
                    // Staging points (green pins)
                    ForEach(stagingPoints) { staging in
                        if let coordinate = staging.coordinate {
                            Marker(staging.label, systemImage: "mappin.circle.fill", coordinate: coordinate)
                                .tint(.green)
                        }
                    }
                    
                    // Assignment markers (blue pins with assigned member info)
                    ForEach(assignmentService.assignedLocations) { assignment in
                        Annotation(
                            assignment.label ?? "Assignment",
                            coordinate: assignment.coordinate
                        ) {
                            VStack(spacing: 2) {
                                Image(systemName: assignment.status.icon)
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(assignment.status.color, in: Circle())
                                if let callsign = assignment.assignedToCallsign {
                                    Text(callsign)
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.white)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    }
                    .mapStyle(mapStyle)
                    .gesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                            .onEnded { value in
                                guard case .second(true, let drag?) = value else { return }
                                guard isCaseAgent else {
                                    print("⚠️ Only case agents can assign locations")
                                    return
                                }
                                if let coordinate = proxy.convert(drag.location, from: .local) {
                                    handleMapLongPress(at: coordinate)
                                }
                            }
                    )
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .overlay(alignment: .topLeading) {
                    // Map type switcher
                    Button {
                        cycleMapStyle()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: mapStyleIcon)
                                .font(.title3)
                            Text(mapStyleLabel)
                                .font(.caption2)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.8))
                        .cornerRadius(8)
                        .shadow(radius: 4)
                    }
                    .padding(.leading, 12)
                    .padding(.top, 12)
                }
                .overlay(alignment: .bottomTrailing) {
                    VStack(spacing: 12) {
                        // Zoom to targets button
                        Button {
                            zoomToTargets()
                        } label: {
                            Image(systemName: "target")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.red)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        
                        // Zoom to team members button
                        Button {
                            zoomToTeamMembers()
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                    }
                    .padding(.trailing, 12)
                    .padding(.bottom, 20)
                }
                } // Close MapReader
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { showTrails.toggle() }) {
                            Image(systemName: showTrails ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        }
                    }
                }
            }
        }
        .navigationTitle("Map")
        .sheet(isPresented: $showingAssignmentSheet) {
            AssignLocationSheet(
                coordinate: assignmentCoordinate,
                operationId: assignmentOperationId,
                teamMembers: teamMembers
            )
        }
        .task {
            await loadTargets()
            await loadTeamMembers()
            await subscribeToRealtimeUpdates()
        }
        .onAppear {
            // Reload targets when returning to map
            Task {
                await loadTargets()
                await loadTeamMembers()
            }
        }
        .onDisappear {
            Task {
                await realtimeService.unsubscribeAll()
                loc.stopPublishing()
            }
        }
        .onChange(of: navigationTarget) { _, newTarget in
            if let target = newTarget {
                zoomToLocation(coordinate: target.coordinate, label: target.label)
                // Clear the target after zooming
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    navigationTarget = nil
                }
            }
        }
    }

    private var needsPermissionUI: Bool {
        switch loc.authorization {
        case .notDetermined, .denied, .restricted: return true
        default: return false
        }
    }

    @ViewBuilder private var permissionCard: some View {
        VStack(spacing: 10) {
            Text("Allow Location Access")
                .font(.headline)
            Text("We need your location during operations.")
                .font(.subheadline).foregroundColor(.secondary)
            HStack {
                Button("Allow While Using App") { LocationService.shared.requestWhenInUse() }
                Button("Allow Always") { LocationService.shared.requestAlways() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding([.horizontal, .top])
    }

    // MapKit helpers (modern Map API)
    @State private var mapPosition: MapCameraPosition = .automatic

    private func configureInitialRegion() {
        if let coord = LocationService.shared.lastLocation?.coordinate {
            region = MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }
    }
    
    private func loadTargets() async {
        guard let operationID = appState.activeOperationID else {
            print("⚠️ No active operation ID - cannot load targets")
            return
        }
        
        print("🔄 Loading targets for operation: \(operationID.uuidString)")
        
        do {
            let result = try await SupabaseRPCService.shared.getOperationTargets(operationId: operationID)
            await MainActor.run {
                self.targets = result.targets
                self.stagingPoints = result.staging
                print("📍 Loaded \(result.targets.count) targets and \(result.staging.count) staging points")
                
                // Debug: Show details of each staging point
                for staging in result.staging {
                    if let coord = staging.coordinate {
                        print("   Staging: \(staging.label) at (\(coord.latitude), \(coord.longitude))")
                    } else {
                        print("   ⚠️ Staging: \(staging.label) has NO COORDINATES (lat=\(staging.lat ?? 0), lng=\(staging.lng ?? 0))")
                    }
                }
            }
        } catch {
            print("❌ Failed to load targets: \(error)")
        }
    }
    
    private func subscribeToRealtimeUpdates() async {
        guard let operationID = appState.activeOperationID,
              let userID = appState.currentUserID else { return }
        
        // Start publishing our location
        loc.startPublishing(operationId: operationID, userId: userID)
        
        // Subscribe to location updates
        do {
            try await realtimeService.subscribeToLocations(operationId: operationID) { locationPoint in
                Task { @MainActor in
                    // Add to trail history
                    addToTrail(locationPoint)
                    
                    // Clean up old trail points (older than 10 minutes)
                    cleanupOldTrails()
                }
            }
        } catch {
            print("Failed to subscribe to location updates: \(error)")
        }
    }
    
    private func addToTrail(_ point: LocationPoint) {
        var trail = locationTrails[point.userId] ?? []
        trail.append(point)
        
        // Keep only last 10 minutes
        let tenMinutesAgo = Date().addingTimeInterval(-600)
        trail = trail.filter { $0.timestamp >= tenMinutesAgo }
        
        locationTrails[point.userId] = trail
    }
    
    private func cleanupOldTrails() {
        let tenMinutesAgo = Date().addingTimeInterval(-600)
        
        for (userId, trail) in locationTrails {
            let filteredTrail = trail.filter { $0.timestamp >= tenMinutesAgo }
            if filteredTrail.isEmpty {
                locationTrails.removeValue(forKey: userId)
            } else {
                locationTrails[userId] = filteredTrail
            }
        }
    }
    
    // MARK: - Zoom Functions
    
    private func zoomToTargets() {
        var coordinates: [CLLocationCoordinate2D] = []
        
        // Add all target coordinates
        for target in targets {
            if let coord = target.coordinate {
                coordinates.append(coord)
            }
        }
        
        // Add all staging point coordinates
        for staging in stagingPoints {
            if let coord = staging.coordinate {
                coordinates.append(coord)
            }
        }
        
        guard !coordinates.isEmpty else {
            print("⚠️ No targets or staging points to zoom to")
            return
        }
        
        // Calculate bounding box
        let region = calculateRegion(for: coordinates)
        
        withAnimation {
            mapPosition = .region(region)
        }
        
        print("🎯 Zoomed to \(coordinates.count) target location(s)")
    }
    
    private func zoomToTeamMembers() {
        var coordinates: [CLLocationCoordinate2D] = []
        
        // Add current user location
        if let userLocation = loc.lastLocation {
            coordinates.append(userLocation.coordinate)
        }
        
        // Add all team member locations
        for (userId, memberLocation) in realtimeService.memberLocations {
            if userId != appState.currentUserID,
               let lastLocation = memberLocation.lastLocation,
               memberLocation.isActive {
                coordinates.append(CLLocationCoordinate2D(
                    latitude: lastLocation.latitude,
                    longitude: lastLocation.longitude
                ))
            }
        }
        
        guard !coordinates.isEmpty else {
            print("⚠️ No team members to zoom to")
            return
        }
        
        // Calculate bounding box
        let region = calculateRegion(for: coordinates)
        
        withAnimation {
            mapPosition = .region(region)
        }
        
        print("👥 Zoomed to \(coordinates.count) team member(s)")
    }
    
    private func calculateRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            // Default region if no coordinates
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }
        
        // Find min/max lat/lon
        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }
        
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0
        
        // Calculate center
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        // Calculate span with padding (20% extra)
        let latDelta = max((maxLat - minLat) * 1.4, 0.01) // Minimum span for single point
        let lonDelta = max((maxLon - minLon) * 1.4, 0.01)
        
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }
    
    private func zoomToLocation(coordinate: CLLocationCoordinate2D, label: String) {
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        withAnimation {
            mapPosition = .region(region)
        }
        
        print("🗺️ Zoomed to \(label) at (\(coordinate.latitude), \(coordinate.longitude))")
    }
    
    private var mapStyle: MapStyle {
        switch currentMapStyleType {
        case .standard:
            return .standard
        case .hybrid:
            return .hybrid
        case .satellite:
            return .imagery
        }
    }
    
    private func cycleMapStyle() {
        withAnimation {
            switch currentMapStyleType {
            case .standard:
                currentMapStyleType = .hybrid
            case .hybrid:
                currentMapStyleType = .satellite
            case .satellite:
                currentMapStyleType = .standard
            }
        }
        print("🗺️ Switched to \(mapStyleLabel) map")
    }
    
    private var mapStyleIcon: String {
        switch currentMapStyleType {
        case .standard:
            return "map"
        case .hybrid:
            return "map.fill"
        case .satellite:
            return "globe.americas.fill"
        }
    }
    
    private var mapStyleLabel: String {
        switch currentMapStyleType {
        case .standard:
            return "Standard"
        case .hybrid:
            return "Hybrid"
        case .satellite:
            return "Satellite"
        }
    }
    
    // MARK: - Assignment Functions
    
    private var currentUserAssignment: AssignedLocation? {
        guard let userId = appState.currentUserID else { return nil }
        return assignmentService.assignedLocations.first { assignment in
            assignment.assignedToUserId == userId &&
            assignment.status != .arrived &&
            assignment.status != .cancelled
        }
    }
    
    private var isCaseAgent: Bool {
        guard let operation = appState.activeOperation else {
            return false
        }
        return operation.createdByUserId == appState.currentUserID
    }
    
    private func handleMapLongPress(at coordinate: CLLocationCoordinate2D) {
        print("🗺️ Long press at coordinate: \(coordinate.latitude), \(coordinate.longitude)")
        print("   Is case agent: \(isCaseAgent)")
        print("   Team members loaded: \(teamMembers.count)")
        print("   Active operation ID: \(appState.activeOperationID?.uuidString ?? "nil")")
        
        // Verify we have required data before showing sheet
        guard let operationId = appState.activeOperationID else {
            print("⚠️ Cannot assign: no active operation")
            return
        }
        
        // Update state variables synchronously
        assignmentCoordinate = coordinate
        assignmentOperationId = operationId
        showingAssignmentSheet = true
        
        print("   Captured - Coord: \(assignmentCoordinate.latitude), OpId: \(assignmentOperationId)")
        print("   Sheet should be showing now: \(showingAssignmentSheet)")
    }
    
    private func loadTeamMembers() async {
        guard let operationId = appState.activeOperationID else { return }
        
        do {
            let members = try await SupabaseRPCService.shared.getOperationMembers(operationId: operationId)
            await MainActor.run {
                self.teamMembers = members
                print("👥 Loaded \(members.count) team members for assignment")
            }
        } catch {
            print("❌ Failed to load team members: \(error)")
        }
    }
}

// MARK: - Vehicle Marker

struct VehicleMarker: View {
    let vehicleType: VehicleType
    let color: String
    let heading: Double?
    let isCurrentUser: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: vehicleIcon)
                .font(.title2)
                .foregroundColor(.white)
                .padding(8)
                .background(vehicleColor, in: Circle())
                .overlay {
                    Circle()
                        .stroke(isCurrentUser ? .blue : .white, lineWidth: isCurrentUser ? 3 : 2)
                }
                .rotationEffect(.degrees(heading ?? 0))
        }
    }
    
    private var vehicleIcon: String {
        switch vehicleType {
        case .sedan:
            return "car.fill"
        case .suv:
            return "suv.side.fill"
        case .pickup:
            return "pickup.side.fill"
        }
    }
    
    private var vehicleColor: Color {
        // Parse color string to Color
        switch color.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "black": return .black
        case "white": return .white
        case "gray", "grey": return .gray
        case "brown": return .brown
        default: return .gray
        }
    }
}

// MARK: - OpTargetKind Extensions

extension OpTargetKind {
    var color: Color {
        switch self {
        case .person: return .green
        case .vehicle: return .orange
        case .location: return .red
        }
    }
}
