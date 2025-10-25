import Foundation
import MapKit // For CLLocationCoordinate2D
import SwiftUI

// MARK: - Assignment Status Enum

enum AssignmentStatus: String, Codable, CaseIterable, Sendable {
    case assigned = "assigned"
    case enRoute = "en_route"
    case arrived = "arrived"
    case cancelled = "cancelled"

    var displayName: String {
        switch self {
        case .assigned: return "Assigned"
        case .enRoute: return "En Route"
        case .arrived: return "Arrived"
        case .cancelled: return "Cancelled"
        }
    }

    var icon: String {
        switch self {
        case .assigned: return "mappin.circle.fill"
        case .enRoute: return "car.fill"
        case .arrived: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .assigned: return .blue
        case .enRoute: return .orange
        case .arrived: return .green
        case .cancelled: return .red
        }
    }
}

// MARK: - Assigned Location Model

struct AssignedLocation: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let operationId: UUID
    let assignedByUserId: UUID
    let assignedToUserId: UUID
    let latitude: Double
    let longitude: Double
    let label: String?
    let notes: String?
    var status: AssignmentStatus
    let assignedAt: Date
    var updatedAt: Date?
    var completedAt: Date?

    // User details (fetched via JOIN in RPC)
    var assignedToUserName: String?
    var assignedToCallsign: String?
    var assignedByUserName: String?
    var assignedByCallsign: String?

    enum CodingKeys: String, CodingKey {
        case id
        case operationId = "operation_id"
        case assignedByUserId = "assigned_by_user_id"
        case assignedToUserId = "assigned_to_user_id"
        case latitude = "lat"
        case longitude = "lon"
        case label
        case notes
        case status
        case assignedAt = "assigned_at"
        case updatedAt = "updated_at"
        case completedAt = "completed_at"
        case assignedToUserName = "assigned_to_user_name"
        case assignedToCallsign = "assigned_to_callsign"
        case assignedByUserName = "assigned_by_user_name"
        case assignedByCallsign = "assigned_by_callsign"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var displayName: String {
        label ?? "\(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude))"
    }
}
