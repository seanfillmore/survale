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
    
    // Publish every 3-5 seconds (using 4 seconds as middle ground)
    private let publishInterval: TimeInterval = 4.0

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
    
    /// Start publishing location updates for an operation
    func startPublishing(operationId: UUID, userId: UUID) {
        self.activeOperationId = operationId
        self.currentUserId = userId
        self.isPublishing = true
        
        // Ensure location tracking is active
        start()
        
        // Start timer for periodic publishing
        publishTimer?.invalidate()
        publishTimer = Timer.scheduledTimer(
            withTimeInterval: publishInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.publishCurrentLocation()
            }
        }
        
        // Publish immediately
        Task {
            await publishCurrentLocation()
        }
    }
    
    /// Stop publishing location updates
    func stopPublishing() {
        publishTimer?.invalidate()
        publishTimer = nil
        activeOperationId = nil
        currentUserId = nil
        isPublishing = false
    }
    
    private func publishCurrentLocation() async {
        guard let operationId = activeOperationId,
              let _ = currentUserId,  // Verify user ID is set
              let location = lastLocation else {
            return
        }
        
        // Publish location via RPC (which inserts into database and triggers realtime notifications)
        do {
            try await SupabaseRPCService.shared.publishLocation(
                operationId: operationId,
                lat: location.coordinate.latitude,
                lon: location.coordinate.longitude,
                accuracy: location.horizontalAccuracy,
                speed: location.speed >= 0 ? location.speed : nil,
                heading: location.course >= 0 ? location.course : nil
            )
            // Database insert will automatically trigger Postgres Changes subscription
            // in RealtimeService, notifying all connected clients
        } catch {
            print("Failed to publish location to database: \(error)")
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

