//
//  LocationServices.swift
//  Survale
//
//  Created by Sean Fillmore on 10/17/25.
//
import CoreLocation
import Combine

@MainActor
final class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    @Published var authorization: CLAuthorizationStatus = .notDetermined
    @Published var lastLocation: CLLocation?
    @Published var isPublishing = false

    private let manager = CLLocationManager()
    private var publishTimer: Timer?
    private var activeOperationId: UUID?
    private var currentUserId: UUID?
    
    // ADAPTIVE PUBLISHING: Movement-based instead of time-based
    private var lastPublishedLocation: CLLocation?
    private var lastPublishedTime: Date?
    
    // Publish based on movement distance (meters) or minimum time (seconds)
    private let minimumDistance: CLLocationDistance = 10.0  // 10 meters
    private let minimumTime: TimeInterval = 30.0  // 30 seconds fallback
    private let maxTime: TimeInterval = 60.0  // 60 seconds maximum
    
    // Timer interval for checking (not publishing - we check more frequently but publish less)
    private let checkInterval: TimeInterval = 5.0  // Check every 5 seconds

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5 // meters
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }

    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlways() {
        // iOS requires WhenInUse first; call this after granted.
        manager.requestAlwaysAuthorization()
    }

    func start() {
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }
    
    // MARK: - Real-time Publishing
    
    /// Start publishing location updates for an operation (adaptive publishing)
    func startPublishing(operationId: UUID, userId: UUID) {
        self.activeOperationId = operationId
        self.currentUserId = userId
        self.isPublishing = true
        
        // Reset tracking
        self.lastPublishedLocation = nil
        self.lastPublishedTime = nil
        
        // Ensure location tracking is active
        start()
        
        // Start timer for checking if we should publish (adaptive)
        publishTimer?.invalidate()
        publishTimer = Timer.scheduledTimer(
            withTimeInterval: checkInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkAndPublishIfNeeded()
            }
        }
        
        // Publish immediately on start
        Task {
            await publishCurrentLocation(force: true)
        }
    }
    
    /// Stop publishing location updates
    func stopPublishing() {
        publishTimer?.invalidate()
        publishTimer = nil
        activeOperationId = nil
        currentUserId = nil
        isPublishing = false
        lastPublishedLocation = nil
        lastPublishedTime = nil
    }
    
    // MARK: - Adaptive Publishing Logic
    
    /// Check if we should publish based on movement and time
    private func checkAndPublishIfNeeded() async {
        guard let currentLocation = lastLocation else { return }
        
        if shouldPublishLocation(currentLocation) {
            await publishCurrentLocation(force: false)
        }
    }
    
    /// Determine if location should be published based on movement and time
    private func shouldPublishLocation(_ newLocation: CLLocation) -> Bool {
        // Always publish first location
        guard let lastPublished = lastPublishedLocation,
              let lastTime = lastPublishedTime else {
            return true
        }
        
        let distance = newLocation.distance(from: lastPublished)
        let timeSince = Date().timeIntervalSince(lastTime)
        
        // Calculate dynamic distance threshold based on speed
        let speed = newLocation.speed >= 0 ? newLocation.speed : 0  // m/s
        let dynamicDistance = speed > 0 ? max(minimumDistance, speed * 5) : minimumDistance
        
        // Publish if:
        // 1. Moved beyond dynamic distance threshold, OR
        // 2. Minimum time elapsed (30s fallback), OR
        // 3. Maximum time exceeded (60s forced update)
        let shouldPublish = distance >= dynamicDistance || 
                           timeSince >= minimumTime || 
                           timeSince >= maxTime
        
        if shouldPublish {
            print("📍 Publishing location: distance=\(String(format: "%.1f", distance))m, time=\(String(format: "%.1f", timeSince))s, speed=\(String(format: "%.1f", speed))m/s")
        }
        
        return shouldPublish
    }
    
    /// Publish current location to database
    private func publishCurrentLocation(force: Bool) async {
        guard let operationId = activeOperationId,
              let _ = currentUserId,
              let location = lastLocation else {
            return
        }
        
        // Update tracking
        lastPublishedLocation = location
        lastPublishedTime = Date()
        
        // Publish location via RPC
        do {
            try await SupabaseRPCService.shared.publishLocation(
                operationId: operationId,
                lat: location.coordinate.latitude,
                lon: location.coordinate.longitude,
                accuracy: location.horizontalAccuracy,
                speed: location.speed >= 0 ? location.speed : nil,
                heading: location.course >= 0 ? location.course : nil
            )
            
            if force {
                print("✅ Force published location (initial or manual)")
            }
        } catch {
            // Only log errors if we still have an active operation
            if activeOperationId != nil {
                print("❌ Failed to publish location to database: \(error)")
            }
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
            start()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }
}

