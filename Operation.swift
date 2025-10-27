//
//  Operation.swift
//  Survale
//
//  Created by Sean Fillmore on 10/17/25.
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

// MARK: - Operation

struct Operation: Identifiable, Equatable {
    let id: UUID
    var name: String
    var incidentNumber: String?
    var state: OperationState
    var createdAt: Date
    var updatedAt: Date?
    var startsAt: Date?  // When operation goes active
    var endsAt: Date?    // When operation ends
    var createdByUserId: UUID
    var teamId: UUID
    var agencyId: UUID
    var isDraft: Bool
    
    // Related data (not stored in operations table)
    var targets: [OpTarget]
    var staging: [StagingPoint]
    
    init(
        id: UUID = UUID(),
        name: String,
        incidentNumber: String? = nil,
        state: OperationState = .active,  // Operations are active by default when created
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        startsAt: Date? = nil,
        endsAt: Date? = nil,
        createdByUserId: UUID,
        teamId: UUID,
        agencyId: UUID,
        isDraft: Bool = false,
        targets: [OpTarget] = [],
        staging: [StagingPoint] = []
    ) {
        self.id = id
        self.name = name
        self.incidentNumber = incidentNumber
        self.state = state
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.createdByUserId = createdByUserId
        self.teamId = teamId
        self.agencyId = agencyId
        self.isDraft = isDraft
        self.targets = targets
        self.staging = staging
    }

    static func mock(_ name: String) -> Operation {
        .init(
            id: UUID(),
            name: name,
            state: .active,
            createdAt: Date(),
            startsAt: nil,
            endsAt: nil,
            createdByUserId: UUID(),
            teamId: UUID(),
            agencyId: UUID(),
            targets: [],
            staging: []
        )
    }
}

// MARK: - Draft Metadata

struct DraftMetadata: Identifiable, Codable, Equatable {
    let id: UUID
    let operationId: UUID
    let createdByUserId: UUID
    var lastEditedAt: Date
    var completionPercentage: Int
    
    init(
        id: UUID = UUID(),
        operationId: UUID,
        createdByUserId: UUID,
        lastEditedAt: Date = Date(),
        completionPercentage: Int = 0
    ) {
        self.id = id
        self.operationId = operationId
        self.createdByUserId = createdByUserId
        self.lastEditedAt = lastEditedAt
        self.completionPercentage = completionPercentage
    }
}

// MARK: - Operation Member

struct OperationMember: Identifiable, Codable, Equatable {
    let id: UUID
    var operationId: UUID
    var userId: UUID
    var role: MemberRole
    var joinedAt: Date
    var leftAt: Date?
    var isActive: Bool  // Currently connected/tracking
    
    init(
        id: UUID = UUID(),
        operationId: UUID,
        userId: UUID,
        role: MemberRole,
        joinedAt: Date = Date(),
        leftAt: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.operationId = operationId
        self.userId = userId
        self.role = role
        self.joinedAt = joinedAt
        self.leftAt = leftAt
        self.isActive = isActive
    }
}

// MARK: - Operation Invite

struct OperationInvite: Identifiable, Codable, Equatable {
    let id: UUID
    var operationId: UUID
    var inviterUserId: UUID
    var inviteeUserId: UUID
    var status: InviteStatus
    var createdAt: Date
    var expiresAt: Date
    var respondedAt: Date?
    
    init(
        id: UUID = UUID(),
        operationId: UUID,
        inviterUserId: UUID,
        inviteeUserId: UUID,
        status: InviteStatus = .pending,
        createdAt: Date = Date(),
        expiresAt: Date = Date().addingTimeInterval(3600), // 1 hour
        respondedAt: Date? = nil
    ) {
        self.id = id
        self.operationId = operationId
        self.inviterUserId = inviterUserId
        self.inviteeUserId = inviteeUserId
        self.status = status
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.respondedAt = respondedAt
    }
}

// MARK: - Join Request

struct JoinRequest: Identifiable, Codable, Equatable {
    let id: UUID
    var operationId: UUID
    var requesterUserId: UUID
    var status: JoinRequestStatus
    var createdAt: Date
    var expiresAt: Date
    var respondedAt: Date?
    var respondedByUserId: UUID?
    
    init(
        id: UUID = UUID(),
        operationId: UUID,
        requesterUserId: UUID,
        status: JoinRequestStatus = .pending,
        createdAt: Date = Date(),
        expiresAt: Date = Date().addingTimeInterval(3600), // 1 hour
        respondedAt: Date? = nil,
        respondedByUserId: UUID? = nil
    ) {
        self.id = id
        self.operationId = operationId
        self.requesterUserId = requesterUserId
        self.status = status
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.respondedAt = respondedAt
        self.respondedByUserId = respondedByUserId
    }
}

// MARK: - Location Point

/// Represents a single location update from a user
struct LocationPoint: Identifiable, Equatable {
    let id: UUID
    var userId: UUID
    var operationId: UUID
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var accuracy: Double  // meters
    var speed: Double?    // meters per second
    var heading: Double?  // degrees (0-360)
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        operationId: UUID,
        timestamp: Date = Date(),
        latitude: Double,
        longitude: Double,
        accuracy: Double,
        speed: Double? = nil,
        heading: Double? = nil
    ) {
        self.id = id
        self.userId = userId
        self.operationId = operationId
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.speed = speed
        self.heading = heading
    }
}

// MARK: - LocationPoint Codable
extension LocationPoint: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case operationId = "operation_id"
        case timestamp = "ts"            // Database uses 'ts' not 'timestamp'
        case latitude = "lat"            // Database uses 'lat' not 'latitude'
        case longitude = "lon"           // Database uses 'lon' not 'longitude'
        case accuracy = "accuracy_m"     // Database uses 'accuracy_m' not 'accuracy'
        case speed = "speed_mps"         // Database uses 'speed_mps' not 'speed'
        case heading = "heading_deg"     // Database uses 'heading_deg' not 'heading'
    }
}

// MARK: - Member Location (Live State)

/// Current location state for a team member
struct MemberLocation: Identifiable, Equatable {
    let id: UUID  // userId
    var user: User?
    var lastLocation: LocationPoint?
    var isActive: Bool  // Currently publishing location
    var lastUpdate: Date?
    
    init(
        id: UUID,
        user: User? = nil,
        lastLocation: LocationPoint? = nil,
        isActive: Bool = false,
        lastUpdate: Date? = nil
    ) {
        self.id = id
        self.user = user
        self.lastLocation = lastLocation
        self.isActive = isActive
        self.lastUpdate = lastUpdate
    }
    
    // Convenience computed properties
    var callsign: String? {
        user?.callsign
    }
    
    var vehicleType: VehicleType {
        user?.vehicleType ?? .sedan
    }
    
    var vehicleColor: String? {
        user?.vehicleColor
    }
}

// MARK: - Codable Conformance

extension Operation: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case incidentNumber = "incident_number"
        case state = "status"  // Database uses 'status' not 'state'
        case createdAt = "created_at"
        case startsAt = "started_at"  // Database uses 'started_at' not 'starts_at'
        case endsAt = "ended_at"      // Database uses 'ended_at' not 'ends_at'
        case createdByUserId = "case_agent_id"  // Database uses 'case_agent_id' not 'created_by_user_id'
        case teamId = "team_id"
        case agencyId = "agency_id"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        incidentNumber = try container.decodeIfPresent(String.self, forKey: .incidentNumber)
        state = try container.decode(OperationState.self, forKey: .state)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        startsAt = try container.decodeIfPresent(Date.self, forKey: .startsAt)
        endsAt = try container.decodeIfPresent(Date.self, forKey: .endsAt)
        createdByUserId = try container.decode(UUID.self, forKey: .createdByUserId)
        teamId = try container.decode(UUID.self, forKey: .teamId)
        agencyId = try container.decode(UUID.self, forKey: .agencyId)
        
        // Initialize related data as empty - will be loaded separately
        targets = []
        staging = []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(incidentNumber, forKey: .incidentNumber)
        try container.encode(state, forKey: .state)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(startsAt, forKey: .startsAt)
        try container.encodeIfPresent(endsAt, forKey: .endsAt)
        try container.encode(createdByUserId, forKey: .createdByUserId)
        try container.encode(teamId, forKey: .teamId)
        try container.encode(agencyId, forKey: .agencyId)
        
        // Don't encode targets and staging - they're stored in separate tables
    }
}


