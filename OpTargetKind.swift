//
//  OpTargetKind.swift
//  Survale
//
//  Created by You on 10/18/25.
//

import Foundation

/// The type of target being tracked in an operation.
enum OpTargetKind: String, CaseIterable, Codable, Identifiable {
    case person
    case vehicle
    case location

    var id: String { rawValue }

    /// A human-readable display label for UI use.
    var displayName: String {
        switch self {
        case .person: return "Person"
        case .vehicle: return "Vehicle"
        case .location: return "Location"
        }
    }

    /// A small SF Symbol suggestion you can use in list rows or tabs.
    var iconName: String {
        switch self {
        case .person: return "person.fill"
        case .vehicle: return "car.fill"
        case .location: return "mappin.and.ellipse"
        }
    }
}
