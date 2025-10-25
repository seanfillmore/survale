//
//  CoreModels.swift
//  Survale
//
//  Core data models for multi-tenant architecture
//

import Foundation

// MARK: - Agency

/// Represents a law enforcement agency (top-level tenant)
struct Agency: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

// MARK: - Team

/// Represents a team within an agency (e.g., "Narcotics Unit")
struct Team: Identifiable, Codable, Equatable {
    let id: UUID
    var agencyId: UUID
    var name: String
    var createdAt: Date
    
    init(id: UUID = UUID(), agencyId: UUID, name: String, createdAt: Date = Date()) {
        self.id = id
        self.agencyId = agencyId
        self.name = name
        self.createdAt = createdAt
    }
}

// MARK: - User

/// Represents a user in the system
struct User: Identifiable, Codable, Equatable {
    let id: UUID  // matches auth.uid
    var email: String
    var teamId: UUID  // primary team
    var agencyId: UUID
    var callsign: String?
    var vehicleType: VehicleType
    var vehicleColor: String  // hex color code
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        email: String,
        teamId: UUID,
        agencyId: UUID,
        callsign: String? = nil,
        vehicleType: VehicleType = .sedan,
        vehicleColor: String = "#0000FF",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.teamId = teamId
        self.agencyId = agencyId
        self.callsign = callsign
        self.vehicleType = vehicleType
        self.vehicleColor = vehicleColor
        self.createdAt = createdAt
    }
}

// MARK: - Vehicle Type

enum VehicleType: String, Codable, CaseIterable {
    case sedan
    case suv
    case pickup
    
    var displayName: String {
        switch self {
        case .sedan: return "Sedan"
        case .suv: return "SUV"
        case .pickup: return "Pickup"
        }
    }
    
    var iconName: String {
        switch self {
        case .sedan: return "car.fill"
        case .suv: return "suv.side.fill"
        case .pickup: return "pickup.side.fill"
        }
    }
}

// MARK: - Operation State

enum OperationState: String, Codable {
    case draft      // Created but not started
    case active     // Currently running
    case ended      // Completed
    
    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .active: return "Active"
        case .ended: return "Ended"
        }
    }
}

// MARK: - Operation Member Role

enum MemberRole: String, Codable {
    case caseAgent = "case_agent"  // CA - creator/leader
    case member                     // Regular member
    
    var displayName: String {
        switch self {
        case .caseAgent: return "Case Agent"
        case .member: return "Member"
        }
    }
}

// MARK: - Invite Status

enum InviteStatus: String, Codable {
    case pending
    case accepted
    case declined
    case expired
}

// MARK: - Join Request Status

enum JoinRequestStatus: String, Codable {
    case pending
    case approved
    case denied
    case expired
}

