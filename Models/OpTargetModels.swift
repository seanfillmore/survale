//
//  OpTargetModels.swift
//  Survale
//
//  Created by You on 10/18/25.
//

import Foundation
import CoreLocation
import SwiftUI

/// Status of a target during an operation
enum OpTargetStatus: String, Codable, CaseIterable {
    case pending = "pending"    // Target identified but not yet under surveillance
    case active = "active"      // Currently under active surveillance
    case clear = "clear"        // Verified clear/no activity
    
    var color: Color {
        switch self {
        case .pending: return .yellow
        case .active: return .red
        case .clear: return .green
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
}

/// A persistable description of an image that belongs to an OpTarget.
struct OpTargetImage: Identifiable, Equatable, Codable, Hashable, Sendable {
    enum StorageKind: String, Codable { case localFile, remoteURL }

    let id: UUID
    var storageKind: StorageKind
    var localPath: String?
    var remoteURL: URL?

    var filename: String
    var pixelWidth: Int?
    var pixelHeight: Int?
    var byteSize: Int?
    var createdAt: Date
    var caption: String?

    // Small cached thumb for fast grids (optional)
    var thumbLocalPath: String?

    nonisolated init(
        id: UUID = UUID(),
        storageKind: StorageKind,
        localPath: String?,
        remoteURL: URL?,
        filename: String,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        byteSize: Int? = nil,
        createdAt: Date = .now,
        caption: String? = nil,
        thumbLocalPath: String? = nil
    ) {
        self.id = id
        self.storageKind = storageKind
        self.localPath = localPath
        self.remoteURL = remoteURL
        self.filename = filename
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.byteSize = byteSize
        self.createdAt = createdAt
        self.caption = caption
        self.thumbLocalPath = thumbLocalPath
    }
}

/// Updated target model with an images array.
struct OpTarget: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var kind: OpTargetKind
    var label: String
    var notes: String?
    var status: OpTargetStatus = .pending  // Default to pending

    // Person
    var personFirstName: String?
    var personLastName: String?
    var personPhone: String?

    // Vehicle
    var vehicleMake: String?
    var vehicleModel: String?
    var vehicleColor: String?
    var vehiclePlate: String?

    // Location
    var locationLat: Double?
    var locationLng: Double?
    var locationName: String?
    var locationAddress: String?  // Full address string for database storage

    // Media
    var images: [OpTargetImage] = []
    
    // Convenience properties for consistency with older code
    var personName: String? {
        get {
            guard let first = personFirstName else { return nil }
            if let last = personLastName {
                return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
            }
            return first
        }
        set {
            // Split on first space
            if let name = newValue {
                let components = name.components(separatedBy: " ")
                personFirstName = components.first
                personLastName = components.count > 1 ? components.dropFirst().joined(separator: " ") : nil
            } else {
                personFirstName = nil
                personLastName = nil
            }
        }
    }
    
    var phone: String? {
        get { personPhone }
        set { personPhone = newValue }
    }
    
    var licensePlate: String? {
        get { vehiclePlate }
        set { vehiclePlate = newValue }
    }
}

extension OpTarget {
    nonisolated var coordinate: CLLocationCoordinate2D? {
        guard let lat = locationLat, let lng = locationLng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    
    // Convenience initializers
    nonisolated init(id: UUID = UUID(), kind: OpTargetKind, personName: String?, phone: String?) {
        self.id = id
        self.kind = kind
        self.label = personName ?? "Unknown Person"
        // Split name into first/last for storage
        if let name = personName {
            let components = name.components(separatedBy: " ")
            self.personFirstName = components.first
            self.personLastName = components.count > 1 ? components.dropFirst().joined(separator: " ") : nil
        } else {
            self.personFirstName = nil
            self.personLastName = nil
        }
        self.personPhone = phone
    }
    
    nonisolated init(id: UUID = UUID(), kind: OpTargetKind, vehicleMake: String?, vehicleModel: String?, vehicleColor: String?, licensePlate: String?) {
        self.id = id
        self.kind = kind
        let desc = [vehicleColor, vehicleMake, vehicleModel].compactMap { $0 }.joined(separator: " ")
        self.label = desc.isEmpty ? (licensePlate ?? "Unknown Vehicle") : desc
        self.vehicleMake = vehicleMake
        self.vehicleModel = vehicleModel
        self.vehicleColor = vehicleColor
        self.vehiclePlate = licensePlate  // Direct stored property
    }
    
    nonisolated init(id: UUID = UUID(), kind: OpTargetKind, locationName: String?, locationAddress: String?) {
        self.id = id
        self.kind = kind
        self.label = locationName ?? locationAddress ?? "Unknown Location"
        self.locationName = locationName
        self.locationAddress = locationAddress
    }
}

extension OpTargetImage {
    var createdAtFormatted: String? {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .none
        return df.string(from: createdAt)
    }
}
