import Foundation
import CoreLocation

// MARK: - Assigned Location Model

struct AssignedLocation: Identifiable, Codable, Sendable {
    let id: UUID
    let operationId: UUID
    let assignedByUserId: UUID
    let assignedToUserId: UUID
    let lat: Double
    let lon: Double
    let label: String?
    let notes: String?
    var status: AssignmentStatus
    let assignedAt: Date
    var acknowledgedAt: Date?
    var arrivedAt: Date?
    
    // Additional fields from RPC response
    var assignedToCallsign: String?
    var assignedToFullName: String?
    
    enum AssignmentStatus: String, Codable, Sendable {
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
            case .assigned: return "mappin.circle"
            case .enRoute: return "arrow.triangle.turn.up.right.circle"
            case .arrived: return "checkmark.circle"
            case .cancelled: return "xmark.circle"
            }
        }
        
        var color: String {
            switch self {
            case .assigned: return "blue"
            case .enRoute: return "orange"
            case .arrived: return "green"
            case .cancelled: return "gray"
            }
        }
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    var displayName: String {
        assignedToCallsign ?? assignedToFullName ?? "Unknown"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case operationId = "operation_id"
        case assignedByUserId = "assigned_by_user_id"
        case assignedToUserId = "assigned_to_user_id"
        case lat, lon, label, notes, status
        case assignedAt = "assigned_at"
        case acknowledgedAt = "acknowledged_at"
        case arrivedAt = "arrived_at"
        case assignedToCallsign = "assigned_to_callsign"
        case assignedToFullName = "assigned_to_full_name"
    }
}

// MARK: - Assignment Response Models

struct AssignmentResponse: Codable {
    let assignmentId: UUID
    let assignedToCallsign: String?
    let assignedToFullName: String?
    let success: Bool
    
    enum CodingKeys: String, CodingKey {
        case assignmentId = "assignment_id"
        case assignedToCallsign = "assigned_to_callsign"
        case assignedToFullName = "assigned_to_full_name"
        case success
    }
}

struct AssignmentStatusResponse: Codable {
    let success: Bool
    let status: String
}

