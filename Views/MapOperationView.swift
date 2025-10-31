import SwiftUI
import MapKit

struct MapOperationView: View {
    @Binding var navigationTarget: MapNavigationTarget?
    
    // CRITICAL: Only observe services that publish UI-relevant data
    @ObservedObject private var loc = LocationService.shared
    @ObservedObject private var realtimeService = RealtimeService.shared
    @ObservedObject private var assignmentService = AssignmentService.shared
    @ObservedObject private var routeService = RouteService.shared  // MUST observe for route polyline updates
    
    @EnvironmentObject var appState: AppState
    
    // OPTIMIZATION: Access directly without observation (no @Published properties used in UI)
    private let store = OperationStore.shared
    private let dataCache = OperationDataCache.shared
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    @State private var targets: [OpTarget] = []
    @State private var stagingPoints: [StagingPoint] = []
    @State private var showTrails = false
    @State private var locationTrails: [UUID: [LocationPoint]] = [:]
    @State private var currentMapStyleType: MapStyleType = .standard
    @State private var isMapReady = false // Defer heavy rendering
    
    // Assignment-related state
    @State private var assignmentData: AssignmentData?
    @State private var teamMembers: [User] = []
    
    // Polling timer for location updates
    @State private var locationPollingTimer: Timer?
    
    // Info card state
    @State private var selectedTarget: OpTarget?
    @State private var selectedStaging: StagingPoint?
    @State private var selectedMember: User?
    @State private var showingDirections = false
    
    struct AssignmentData: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
        let operationId: UUID
        let teamMembers: [User]  // Capture team members when sheet is presented
    }
    
    enum MapStyleType {
        case standard, hybrid, satellite
    }
    
    // Haptic generator for map interactions (heavy for stronger feedback)
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let warningHaptic = UINotificationFeedbackGenerator()

    var body: some View {
        contentView
            .navigationTitle("Map")
    }
    
    // MARK: - Main Content View
    
    @ViewBuilder
    private var contentView: some View {
        mainContent
            .sheet(item: $assignmentData) { data in
                AssignLocationSheet(
                    coordinate: data.coordinate,
                    operationId: data.operationId,
                    teamMembers: data.teamMembers
                )
            }
            .sheet(item: $selectedTarget) { target in
                TargetInfoSheet(target: target)
            }
            .sheet(item: $selectedStaging) { staging in
                StagingInfoSheet(staging: staging)
            }
            .sheet(item: $selectedMember) { member in
                TeamMemberInfoSheet(member: member, assignmentService: assignmentService, routeService: routeService, operationId: appState.activeOperationID)
            }
            .sheet(isPresented: $showingDirections) {
                if let myAssignment = currentUserAssignment,
                   let routeInfo = routeService.getRoute(for: myAssignment.id) {
                    DirectionsSheet(routeInfo: routeInfo, assignment: myAssignment)
                }
            }
            .task {
                await loadInitialData()
            }
            .onAppear {
                handleViewAppear()
            }
            .onDisappear {
                stopPolling()
            }
            .onChange(of: appState.activeOperationID) { _, _ in
                handleOperationChange()
            }
            .onChange(of: assignmentService.assignedLocations) { _, _ in
                handleAssignmentsChange()
            }
            .onChange(of: loc.lastLocation) { _, _ in
                handleLocationChange()
            }
            .onChange(of: navigationTarget) { _, newTarget in
                handleNavigationTarget(newTarget)
            }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            headerSection
            
            if appState.activeOperationID == nil {
                emptyStateView
            } else {
                mapContentView
            }
        }
    }
    
    @ViewBuilder
    private var mapContentView: some View {
        // Debug: Show staging point count
        if !stagingPoints.isEmpty {
            Text("Showing \(stagingPoints.count) staging point(s)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        
        MapReader { proxy in
            Map(position: $mapPosition, interactionModes: .all) {
                    // User location (distinct from team members, unless hidden)
                    if let userLocation = loc.lastLocation,
                       let currentUserId = appState.currentUserID,
                       !appState.hiddenUserIds.contains(currentUserId) {
                        Annotation("You", coordinate: userLocation.coordinate) {
                            VehicleMarker(
                                vehicleType: appState.currentUser?.vehicleType ?? .sedan,
                                color: appState.currentUser?.vehicleColor ?? "blue",
                                heading: userLocation.course >= 0 ? userLocation.course : nil,
                                isCurrentUser: true
                            )
                        }
                    }
                    
                    // Team member locations (excluding current user and hidden users)
                    ForEach(Array(realtimeService.memberLocations.keys), id: \.self) { userId in
                        if userId != appState.currentUserID,
                           !appState.hiddenUserIds.contains(userId), // Filter out hidden users
                           let memberLocation = realtimeService.memberLocations[userId],
                           let lastLocation = memberLocation.lastLocation,
                           memberLocation.isActive {
                            Annotation(memberLocation.callsign ?? "Unit", coordinate: CLLocationCoordinate2D(
                                latitude: lastLocation.latitude,
                                longitude: lastLocation.longitude
                            )) {
                                Button {
                                    // Find the full user object for this member
                                    if let member = teamMembers.first(where: { $0.id == userId }) {
                                        selectedMember = member
                                    }
                                } label: {
                                    VehicleMarker(
                                        vehicleType: memberLocation.vehicleType,
                                        color: memberLocation.vehicleColor ?? "gray",
                                        heading: lastLocation.heading,
                                        isCurrentUser: false
                                    )
                                }
                            }
                        }
                    }
                    
                    // Location trails (if enabled, excluding hidden users)
                    if showTrails {
                        ForEach(Array(locationTrails.keys), id: \.self) { userId in
                            if !appState.hiddenUserIds.contains(userId), // Filter out hidden users
                               let trail = locationTrails[userId], trail.count > 1 {
                                MapPolyline(coordinates: trail.map { point in
                                    CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
                                })
                                .stroke(userId == appState.currentUserID ? .blue : .gray, lineWidth: 2)
                            }
                        }
                    }
                    
                    // Target locations with status indicators (excluding hidden targets)
                    // Only render targets after map is ready (deferred rendering)
                    if isMapReady {
                        ForEach(targets) { target in
                            if let coordinate = target.coordinate,
                               !appState.hiddenTargetIds.contains(target.id) { // Filter out hidden targets
                                Annotation(target.label, coordinate: coordinate) {
                                    Button {
                                        selectedTarget = target
                                    } label: {
                                        TargetMarker(target: target)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Staging points (green pins, excluding hidden staging points)
                    if isMapReady {
                        ForEach(stagingPoints) { staging in
                            if let coordinate = staging.coordinate,
                               !appState.hiddenStagingIds.contains(staging.id) { // Filter out hidden staging points
                                Annotation(staging.label, coordinate: coordinate) {
                                    Button {
                                        selectedStaging = staging
                                    } label: {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(.white)
                                            .padding(8)
                                            .background(.green, in: Circle())
                                            .shadow(radius: 3)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Assignment markers (blue pins with assigned member info)
                    // Hide "arrived" assignments to reduce clutter - user's real-time location shows their position
                    ForEach(assignmentService.assignedLocations.filter { $0.status != .arrived }) { assignment in
                        Annotation(
                            assignment.label ?? "Assignment",
                            coordinate: assignment.coordinate
                        ) {
                            Button {
                                // Find the assigned team member and show their info
                                let assignedUserId = assignment.assignedToUserId
                                if let member = teamMembers.first(where: { $0.id == assignedUserId }) {
                                    selectedMember = member
                                }
                            } label: {
                                VStack(spacing: 2) {
                                    Image(systemName: assignment.status.icon)
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(assignment.status.color, in: Circle())
                                    
                                    // Show callsign
                                    if let callsign = assignment.assignedToCallsign {
                                        Text(callsign)
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.white)
                                            .foregroundStyle(.primary)
                                            .cornerRadius(4)
                                    }
                                    
                                    // Show ETA when en route (for both case agent and assigned user)
                                    if assignment.status == .enRoute {
                                        if let routeInfo = routeService.getRoute(for: assignment.id) {
                                            Text(routeInfo.travelTimeText)
                                                .font(.caption2.bold())
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(assignment.status.color)
                                                .cornerRadius(4)
                                        } else {
                                            // Debug: Route not found
                                            let _ = print("⚠️ ETA not showing - assignment \(assignment.id) is enRoute but no route info found")
                                            let _ = print("   Available routes: \(routeService.getAllRoutes().count) total")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Route polylines - show for current user's assignment
                    // Even if user is case agent, they can still have an assignment and need navigation
                    if let myAssignment = currentUserAssignment {
                        if let routeInfo = routeService.getRoute(for: myAssignment.id) {
                            let _ = print("🔵 Drawing route polyline for assignment \(myAssignment.id)")
                            let _ = print("   Polyline points: \(routeInfo.polyline.pointCount)")
                            MapPolyline(routeInfo.polyline)
                                .stroke(.blue, lineWidth: 4)
                        } else {
                            let _ = print("⚠️ No route found for assignment \(myAssignment.id)")
                            let _ = print("   Available routes: \(routeService.activeRoutes.keys.map { $0.uuidString })")
                        }
                    } else {
                        let _ = print("⚠️ Not showing route - no current user assignment")
                }
            }
            .mapStyle(mapStyle)
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                    .onEnded { value in
                        print("🎯 Long press gesture ended: \(value)")
                        guard case .second(true, let drag?) = value else {
                            print("⚠️ Gesture pattern didn't match")
                            return
                        }
                        
                        guard let coordinate = proxy.convert(drag.location, from: .local) else {
                            print("⚠️ Could not convert tap location to coordinate")
                            return
                        }
                        
                        print("✅ Long press succeeded at coordinate: \(coordinate)")
                        
                        // Check permissions first
                        if !isCaseAgent {
                            print("⚠️ User is not case agent, showing warning haptic")
                            warningHaptic.prepare()
                            warningHaptic.notificationOccurred(.warning)
                            return
                        }
                        
                        // Trigger haptic IMMEDIATELY and SYNCHRONOUSLY before any other operations
                        print("📳 Triggering haptic NOW (before sheet)")
                        hapticGenerator.prepare()
                        hapticGenerator.impactOccurred()
                        print("📳 Haptic triggered, now presenting sheet")
                        
                        // Present sheet immediately after haptic (synchronous)
                        handleMapLongPress(at: coordinate)
                        print("✅ Sheet presentation triggered")
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
                    // Turn-by-turn directions button (only when navigating)
                    if let myAssignment = currentUserAssignment,
                       routeService.getRoute(for: myAssignment.id) != nil {
                        Button {
                            showingDirections = true
                        } label: {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.green)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                    }
                    
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
    
    /// Load data from cache if available, otherwise fetch fresh (for smooth tab switching)
    private func loadFromCacheOrFetch() async {
        guard let operationID = appState.activeOperationID else {
            print("⚠️ No active operation ID - cannot load data")
            return
        }
        
        // Try to load from cache first (instant)
        let cachedTargets = dataCache.getTargets(for: operationID)
        let cachedStaging = dataCache.getStagingPoints(for: operationID)
        let cachedMembers = dataCache.getTeamMembers(for: operationID)
        
        if !cachedTargets.isEmpty || !cachedStaging.isEmpty {
            print("✅ Loading from cache - \(cachedTargets.count) targets, \(cachedStaging.count) staging, \(cachedMembers.count) members")
            targets = cachedTargets
            stagingPoints = cachedStaging
            teamMembers = cachedMembers
            
            // Always refresh team members in background (they change frequently)
            Task {
                await loadTeamMembers()
            }
        } else {
            print("🔄 Cache miss - loading fresh data")
            await loadTargets()
            await loadTeamMembers()
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
        
        // Add all visible target coordinates (excluding hidden targets)
        for target in targets {
            if let coord = target.coordinate,
               !appState.hiddenTargetIds.contains(target.id) { // Filter out hidden targets
                coordinates.append(coord)
            }
        }
        
        // Add all visible staging point coordinates (excluding hidden staging points)
        for staging in stagingPoints {
            if let coord = staging.coordinate,
               !appState.hiddenStagingIds.contains(staging.id) { // Filter out hidden staging points
                coordinates.append(coord)
            }
        }
        
        guard !coordinates.isEmpty else {
            print("⚠️ No visible targets or staging points to zoom to")
            return
        }
        
        // Calculate bounding box
        let region = calculateRegion(for: coordinates)
        
        withAnimation {
            mapPosition = .region(region)
        }
        
        print("🎯 Zoomed to \(coordinates.count) visible target location(s)")
    }
    
    private func zoomToTeamMembers() {
        var coordinates: [CLLocationCoordinate2D] = []
        
        // Add current user location (if not hidden)
        if let userLocation = loc.lastLocation,
           let currentUserId = appState.currentUserID,
           !appState.hiddenUserIds.contains(currentUserId) {
            coordinates.append(userLocation.coordinate)
        }
        
        // Add all visible team member locations (excluding hidden users)
        for (userId, memberLocation) in realtimeService.memberLocations {
            if userId != appState.currentUserID,
               !appState.hiddenUserIds.contains(userId), // Filter out hidden users
               let lastLocation = memberLocation.lastLocation,
               memberLocation.isActive {
                coordinates.append(CLLocationCoordinate2D(
                    latitude: lastLocation.latitude,
                    longitude: lastLocation.longitude
                ))
            }
        }
        
        guard !coordinates.isEmpty else {
            print("⚠️ No visible team members to zoom to")
            return
        }
        
        // Calculate bounding box
        let region = calculateRegion(for: coordinates)
        
        withAnimation {
            mapPosition = .region(region)
        }
        
        print("👥 Zoomed to \(coordinates.count) visible team member(s)")
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
        guard let userId = appState.currentUserID else {
            print("⚠️ No current user ID for assignment filtering")
            return nil
        }
        
        let myAssignment = assignmentService.assignedLocations.first { assignment in
            assignment.assignedToUserId == userId &&
            assignment.status != .arrived &&
            assignment.status != .cancelled
        }
        
        if myAssignment != nil {
            print("✅ Found assignment for current user \(userId)")
        } else if !assignmentService.assignedLocations.isEmpty {
            print("ℹ️ No assignment for current user \(userId)")
            print("   Available assignments for users: \(assignmentService.assignedLocations.map { $0.assignedToUserId })")
        }
        
        return myAssignment
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
        
        // Create assignment data to trigger sheet (capture current team members)
        assignmentData = AssignmentData(
            coordinate: coordinate,
            operationId: operationId,
            teamMembers: teamMembers
        )
        
        print("   Created assignment data with coord: \(coordinate.latitude), opId: \(operationId), members: \(teamMembers.count)")
    }
    
    private func loadTeamMembers() async {
        guard let operationId = appState.activeOperationID else {
            print("⚠️ Cannot load team members: no active operation")
            return
        }
        
        print("🔄 MapOperationView: Fetching team members for operation \(operationId)")
        
        do {
            let members = try await SupabaseRPCService.shared.getOperationMembers(operationId: operationId)
            print("✅ MapOperationView: Received \(members.count) team members from database")
            for (index, member) in members.enumerated() {
                print("   [\(index + 1)] \(member.callsign ?? "No callsign") - \(member.email)")
            }
            
            await MainActor.run {
                self.teamMembers = members
                print("✅ MapOperationView: Updated local teamMembers array to \(members.count) members")
                
                // Update RealtimeService with team members for populating MemberLocation user data
                realtimeService.setTeamMembers(members)
            }
        } catch {
            print("❌ MapOperationView: Failed to load team members: \(error)")
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var headerSection: some View {
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
    }
    
    private var emptyStateView: some View {
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
    }
    
    // MARK: - Lifecycle Handlers
    
    private func loadInitialData() async {
        // Load cached data immediately (synchronous, instant)
        if let operationId = appState.activeOperationID {
            targets = dataCache.getTargets(for: operationId)
            stagingPoints = dataCache.getStagingPoints(for: operationId)
            teamMembers = dataCache.getTeamMembers(for: operationId)
        }
        
        // Defer heavy operations slightly to let view render
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Now do the heavy lifting in background
        await subscribeToRealtimeUpdates()
        
        // Load assignments and team members
        if let operationId = appState.activeOperationID {
            await assignmentService.fetchAssignments(for: operationId)
            await assignmentService.subscribeToAssignments(operationId: operationId)
            await loadTeamMembers()
        }
        
        // Calculate route for user's active assignment
        await calculateRouteForCurrentUser()
    }
    
    private func handleViewAppear() {
        // Prepare haptic generators early for instant response
        hapticGenerator.prepare()
        warningHaptic.prepare()
        
        // Start polling for location updates
        startPolling()
        
        // Allow view to render first, then load data
        Task {
            // Tiny delay to let tab animation complete
            try? await Task.sleep(nanoseconds: 16_000_000) // 16ms (1 frame at 60fps)
            
            // Load from cache immediately (no await, instant)
            if let operationId = appState.activeOperationID {
                targets = dataCache.getTargets(for: operationId)
                stagingPoints = dataCache.getStagingPoints(for: operationId)
                teamMembers = dataCache.getTeamMembers(for: operationId)
                
                // Start background refresh
                await loadFromCacheOrFetch()
                
                // Always load fresh team members to ensure accurate assignment list
                await loadTeamMembers()
            }
            
            // Defer map rendering until data is loaded
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            isMapReady = true
        }
    }
    
    private func handleOperationChange() {
        // Clear map when operation changes
        isMapReady = false
    }
    
    private func handleAssignmentsChange() {
        // Recalculate route when assignments change
        Task {
            await updateRouteForCurrentUser()
        }
    }
    
    private func handleLocationChange() {
        // Update route when user moves
        Task {
            await updateRouteForCurrentUser()
        }
    }
    
    private func handleNavigationTarget(_ newTarget: MapNavigationTarget?) {
        guard let target = newTarget else { return }
        
        // Navigate to the provided coordinate
        zoomToLocation(coordinate: target.coordinate, label: target.label)
        
        // Clear the navigation target
        navigationTarget = nil
    }
    
    // MARK: - Helper Functions
    
    private func iconForTargetKind(_ kind: OpTargetKind) -> String {
        switch kind {
        case .person: return "person.fill"
        case .vehicle: return "car.fill"
        case .location: return "mappin.circle.fill"
        }
    }
    
    // MARK: - Route Calculation
    
    /// Calculate route for current user's active assignment
    private func calculateRouteForCurrentUser() async {
        guard let assignment = currentUserAssignment,
              let userLocation = loc.lastLocation?.coordinate else {
            return
        }
        
        // Only calculate routes for assigned or en route status
        guard assignment.status == .assigned || assignment.status == .enRoute else {
            return
        }
        
        do {
            let _ = try await routeService.calculateRoute(from: userLocation, to: assignment)
            print("🗺️ Route calculated for current user")
        } catch {
            print("❌ Failed to calculate route: \(error)")
        }
    }
    
    /// Update route when location changes
    private func updateRouteForCurrentUser() async {
        guard let assignment = currentUserAssignment,
              let userLocation = loc.lastLocation?.coordinate else {
            // Clear route if no assignment or location
            if let assignment = currentUserAssignment {
                routeService.clearRoute(assignmentId: assignment.id)
            }
            return
        }
        
        // Only update routes for en route status
        guard assignment.status == .enRoute else {
            return
        }
        
        do {
            try await routeService.updateRoute(assignmentId: assignment.id, from: userLocation)
        } catch {
            print("❌ Failed to update route: \(error)")
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

// MARK: - Directions Sheet

struct DirectionsSheet: View {
    let routeInfo: RouteInfo
    let assignment: AssignedLocation
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    routeSummarySection
                    directionsListSection
                }
                .padding()
            }
            .navigationTitle("Turn-by-Turn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Route Summary
    
    private var routeSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Route to \(assignment.label ?? "Assignment")")
                .font(.title2.bold())
            
            HStack(spacing: 20) {
                routeStatItem(icon: "arrow.triangle.branch", text: routeInfo.distanceText)
                routeStatItem(icon: "clock", text: routeInfo.travelTimeText)
                routeStatItem(icon: "flag.checkered", text: "ETA: \(routeInfo.etaText)")
            }
            .padding(.vertical, 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func routeStatItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
            Text(text)
                .font(.subheadline)
        }
    }
    
    // MARK: - Directions List
    
    private var directionsListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Directions")
                .font(.headline)
                .padding(.horizontal)
                .padding(.bottom, 8)
            
            ForEach(Array(routeInfo.steps.enumerated()), id: \.offset) { index, step in
                directionStepRow(index: index, step: step)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func directionStepRow(index: Int, step: MKRoute.Step) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                stepNumberBadge(index: index)
                stepInstructions(step: step)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            if index < routeInfo.steps.count - 1 {
                Divider()
                    .padding(.leading, 56)
            }
        }
    }
    
    private func stepNumberBadge(index: Int) -> some View {
        ZStack {
            Circle()
                .fill(stepColor(for: index))
                .frame(width: 32, height: 32)
            
            stepIcon(for: index)
        }
    }
    
    private func stepColor(for index: Int) -> Color {
        if index == 0 {
            return .green
        } else if index == routeInfo.steps.count - 1 {
            return .red
        } else {
            return .blue
        }
    }
    
    @ViewBuilder
    private func stepIcon(for index: Int) -> some View {
        if index == 0 {
            Image(systemName: "location.fill")
                .font(.caption)
                .foregroundStyle(.white)
        } else if index == routeInfo.steps.count - 1 {
            Image(systemName: "flag.fill")
                .font(.caption)
                .foregroundStyle(.white)
        } else {
            Text("\(index)")
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
    }
    
    private func stepInstructions(step: MKRoute.Step) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(step.instructions.isEmpty ? "Continue on route" : step.instructions)
                .font(.body)
            
            if step.distance > 0 {
                Text(formatDistance(step.distance))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return formatter.string(fromDistance: distance)
    }
    
    // MARK: - Polling for location updates
    
    private func startPolling() {
        // Stop any existing timer
        stopPolling()
        
        guard let operationId = appState.activeOperationID else { return }
        
        print("🔄 Starting location polling for operation \(operationId)")
        
        // Poll immediately
        Task {
            await realtimeService.pollLocations(operationId: operationId)
        }
        
        // Then poll every 5 seconds
        locationPollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self,
                  let operationId = appState.activeOperationID else { return }
            Task { @MainActor in
                await self.realtimeService.pollLocations(operationId: operationId)
            }
        }
    }
    
    private func stopPolling() {
        locationPollingTimer?.invalidate()
        locationPollingTimer = nil
    }
}
