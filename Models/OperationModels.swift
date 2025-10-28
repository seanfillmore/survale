//
//  OperationModels.swift
//  Survale
//
//  Core operation-related models and type definitions.
//

import Foundation
import CoreLocation

// MARK: - StagingPoint

/// Represents a staging location for an operation (e.g., meeting point, safe house)
struct StagingPoint: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var label: String
    var address: String
    var lat: Double?
    var lng: Double?
    
    nonisolated init(
        id: UUID = UUID(),
        label: String,
        address: String,
        lat: Double? = nil,
        lng: Double? = nil
    ) {
        self.id = id
        self.label = label
        self.address = address
        self.lat = lat
        self.lng = lng
    }
    
    nonisolated var coordinate: CLLocationCoordinate2D? {
        guard let lat = lat, let lng = lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}
