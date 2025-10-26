import Foundation
import Supabase
import Combine

@MainActor
final class SupabaseAuthService {
    static let shared = SupabaseAuthService()

    private let client: SupabaseClient
    private var authChangeTask: Task<Void, Never>?
    private weak var appState: AppState?

    private init() {
        client = SupabaseClient(
            supabaseURL: Secrets.supabaseURL,
            supabaseKey: Secrets.anonKey
        )
    }
    
    // Set AppState reference for user ID updates
    func setAppState(_ appState: AppState) {
        self.appState = appState
    }

    
    // Expose client for DB/Storage later (nonisolated for use in non-MainActor contexts)
    nonisolated var supabase: SupabaseClient { 
        // Safe because SupabaseClient is thread-safe and client is immutable after init
        client 
    }

    // SIGN IN (email + password)
    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(
            email: email,
            password: password
        )
        // auth state listener will flip AppState for you
    }

    // SIGN OUT
    func signOut() async throws {
        try await client.auth.signOut()
        
        // Stop location publishing immediately
        await MainActor.run {
            LocationService.shared.stopPublishing()
        }
        
        // Clear user context and active operation
        await MainActor.run {
            appState?.currentUser = nil
            appState?.currentTeam = nil
            appState?.currentAgency = nil
            appState?.activeOperationID = nil
            appState?.activeOperation = nil
        }
        
        // Clear operations from store
        await OperationStore.shared.clearOperations()
    }

    // QUICK SYNC CHECK (no refresh)
    func isLoggedIn() -> Bool {
        client.auth.currentSession != nil
    }

    // AUTH STATE LISTENER
    func startAuthListener(onChange: @escaping (Bool) -> Void) {
        authChangeTask?.cancel()
        authChangeTask = Task { [weak self] in
            guard let self else { return }
            for await _ in self.client.auth.authStateChanges {
                // Use currentSession here to avoid async/throwing access
                let authed = self.client.auth.currentSession != nil
                let userId = self.client.auth.currentUser?.id
                await MainActor.run { 
                    onChange(authed)
                    // Also update AppState if it's available
                    if let appState = self.appState, let userId = userId {
                        if let uuid = UUID(uuidString: userId.uuidString) {
                            appState.currentUserID = uuid
                            
                            // Fetch full user context
                            Task {
                                await self.loadUserContext(userId: uuid)
                            }
                        }
                    }
                }
            }
        }
        // Fire initial state
        onChange(isLoggedIn())
    }
    
    // MARK: - Load User Context
    
    /// Load full user, team, and agency data
    private func loadUserContext(userId: UUID) async {
        print("📥 Loading user context for userId: \(userId.uuidString)")
        
        do {
            // Fetch user data
            struct UserResponse: Decodable {
                let id: String
                let email: String
                let team_id: String
                let agency_id: String
                let callsign: String?
                let vehicle_type: String
                let vehicle_color: String
                let created_at: String
            }
            
            print("   Fetching user from database...")
            let userResponse: UserResponse = try await client
                .from("users")
                .select("*")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            print("   ✅ User found: \(userResponse.email)")
            
            guard let teamId = UUID(uuidString: userResponse.team_id),
                  let agencyId = UUID(uuidString: userResponse.agency_id) else {
                print("Invalid team or agency ID")
                return
            }
            
            // Create user object
            let user = User(
                id: userId,
                email: userResponse.email,
                teamId: teamId,
                agencyId: agencyId,
                callsign: userResponse.callsign,
                vehicleType: VehicleType(rawValue: userResponse.vehicle_type) ?? .sedan,
                vehicleColor: userResponse.vehicle_color,
                createdAt: ISO8601DateFormatter().date(from: userResponse.created_at) ?? Date()
            )
            
            // Fetch team data
            struct TeamResponse: Decodable {
                let id: String
                let agency_id: String
                let name: String
                let created_at: String
            }
            
            let teamResponse: TeamResponse = try await client
                .from("teams")
                .select("*")
                .eq("id", value: teamId.uuidString)
                .single()
                .execute()
                .value
            
            let team = Team(
                id: teamId,
                agencyId: agencyId,
                name: teamResponse.name,
                createdAt: ISO8601DateFormatter().date(from: teamResponse.created_at) ?? Date()
            )
            
            // Fetch agency data
            struct AgencyResponse: Decodable {
                let id: String
                let name: String
                let created_at: String
            }
            
            let agencyResponse: AgencyResponse = try await client
                .from("agencies")
                .select("*")
                .eq("id", value: agencyId.uuidString)
                .single()
                .execute()
                .value
            
            let agency = Agency(
                id: agencyId,
                name: agencyResponse.name,
                createdAt: ISO8601DateFormatter().date(from: agencyResponse.created_at) ?? Date()
            )
            
            // Update AppState
            await MainActor.run {
                self.appState?.currentUser = user
                self.appState?.currentTeam = team
                self.appState?.currentAgency = agency
            }
            
            // Load operations for this user
            print("📥 Loading operations for user...")
            await OperationStore.shared.loadOperations(for: userId)
            
            // Check if user has an active operation and restore it
            if let activeOp = OperationStore.shared.operations.first(where: { $0.state == .active }) {
                print("✅ Found active operation: \(activeOp.name)")
                await MainActor.run {
                    self.appState?.activeOperationID = activeOp.id
                    self.appState?.activeOperation = activeOp
                }
            } else {
                print("ℹ️ No active operation found")
            }
            
        } catch {
            print("❌ Failed to load user context: \(error)")
            print("   This usually means:")
            print("   1. User record doesn't exist in 'users' table")
            print("   2. User is not assigned to a team/agency")
            print("   3. Database connection issue")
            print("   → You need to create the user record in the database")
        }
    }
    
}

// MARK: - DatabaseService

@MainActor
final class DatabaseService: ObservableObject {
    static let shared = DatabaseService()
    
    private let client: SupabaseClient
    
    private init() {
        self.client = SupabaseAuthService.shared.supabase
    }
    
    // MARK: - Operations
    
    // Note: Operation CRUD functions moved to SupabaseRPCService
    // These old direct database access functions are no longer used
    
    // MARK: - Targets
    
    func createTarget(_ target: OpTarget, operationID: UUID) async throws {
        let formatter = ISO8601DateFormatter()
        
        struct TargetData: Encodable {
            let id: String
            let operation_id: String
            let kind: String
            let label: String
            let notes: String?
            let person_first_name: String?
            let person_last_name: String?
            let person_phone: String?
            let vehicle_make: String?
            let vehicle_model: String?
            let vehicle_color: String?
            let vehicle_plate: String?
            let location_lat: Double?
            let location_lng: Double?
            let location_name: String?
            let created_at: String
        }
        
        let targetData = TargetData(
            id: target.id.uuidString,
            operation_id: operationID.uuidString,
            kind: target.kind.rawValue,
            label: target.label,
            notes: target.notes,
            person_first_name: target.personFirstName,
            person_last_name: target.personLastName,
            person_phone: target.personPhone,
            vehicle_make: target.vehicleMake,
            vehicle_model: target.vehicleModel,
            vehicle_color: target.vehicleColor,
            vehicle_plate: target.vehiclePlate,
            location_lat: target.locationLat,
            location_lng: target.locationLng,
            location_name: target.locationName,
            created_at: formatter.string(from: Date())
        )
        
        try await client
            .from("targets")
            .insert(targetData)
            .execute()
    }
    
    func fetchTargets(for operationID: UUID) async throws -> [OpTarget] {
        _ = try await client
            .from("targets")
            .select("*")
            .eq("operation_id", value: operationID.uuidString)
            .order("created_at", ascending: false)
            .execute()
        
        // TODO: Parse response into OpTarget objects
        return []
    }
    
    // MARK: - Chat Messages
    
    func sendMessage(_ message: String, operationID: UUID, userID: UUID, mediaPath: String? = nil, mediaType: String = "text") async throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        struct MessageData: Encodable {
            let id: String
            let operation_id: String
            let sender_user_id: String  // Database uses 'sender_user_id' not 'user_id'
            let body_text: String        // Database uses 'body_text' not 'content'
            let media_path: String?      // Storage path for media
            let media_type: String       // 'text', 'image', or 'video'
            let created_at: String
        }
        
        let messageId = UUID().uuidString
        let messageData = MessageData(
            id: messageId,
            operation_id: operationID.uuidString,
            sender_user_id: userID.uuidString,
            body_text: message,
            media_path: mediaPath,
            media_type: mediaType,
            created_at: formatter.string(from: Date())
        )
        
        print("💬 DatabaseService: Inserting message \(messageId) to op_messages")
        print("   Operation: \(operationID)")
        print("   User: \(userID)")
        print("   Text: '\(message)'")
        
        let response = try await client
            .from("op_messages")  // Database uses 'op_messages' not 'messages'
            .insert(messageData)
            .execute()
        
        print("✅ DatabaseService: Message inserted successfully")
        print("   Response status: \(response.response.statusCode)")
    }
    
    func fetchMessages(for operationID: UUID) async throws -> [ChatMessage] {
        // First, check if user is a member of the operation
        struct MembershipCheck: Decodable {
            let user_id: String
        }
        
        // Check membership by fetching all members and filtering for active ones
        struct MembershipRow: Decodable {
            let user_id: String
            let left_at: String?
        }
        
        let membershipResponse = try await client
            .from("operation_members")
            .select("user_id, left_at")
            .eq("operation_id", value: operationID.uuidString)
            .eq("user_id", value: (try await client.auth.session).user.id.uuidString)
            .execute()
        
        let allMemberships = try JSONDecoder().decode([MembershipRow].self, from: membershipResponse.data)
        let activeMemberships = allMemberships.filter { $0.left_at == nil }
        
        guard !activeMemberships.isEmpty else {
            print("⚠️ User is not a member of operation \(operationID) - returning empty messages")
            return []  // User is not a member, return empty array
        }
        
        print("✅ User is a member of operation \(operationID) - fetching messages")
        
        struct MessageRow: Decodable {
            let id: String
            let operation_id: String
            let sender_user_id: String
            let body_text: String
            let created_at: String
            
            // Optional fields for JOIN if we add it later
            let user_name: String?
        }
        
        let response = try await client
            .from("op_messages")
            .select("*, users!sender_user_id(full_name)")
            .eq("operation_id", value: operationID.uuidString)
            .order("created_at", ascending: true)
            .execute()
        
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Parse raw JSON to get user names from JOIN
        struct MessageWithUser: Decodable {
            let id: String
            let operation_id: String
            let sender_user_id: String
            let body_text: String
            let created_at: String
            let media_path: String?
            let media_type: String?
            let users: UserInfo?
            
            struct UserInfo: Decodable {
                let full_name: String?
            }
        }
        
        let messagesWithUser = try decoder.decode([MessageWithUser].self, from: response.data)
        
        return messagesWithUser.compactMap { msg in
            guard let operationId = UUID(uuidString: msg.operation_id),
                  let createdAt = formatter.date(from: msg.created_at) else {
                return nil
            }
            
            return ChatMessage(
                id: msg.id,
                operationID: operationId,
                userID: msg.sender_user_id,
                content: msg.body_text,
                createdAt: createdAt,
                userName: msg.users?.full_name,
                mediaPath: msg.media_path,
                mediaType: msg.media_type ?? "text"
            )
        }
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable, Codable {
    let id: String
    let operationID: UUID
    let userID: String
    let content: String
    let createdAt: Date
    let userName: String? // Optional display name
    let mediaPath: String? // Storage path for media
    let mediaType: String  // 'text', 'image', or 'video'
    
    enum CodingKeys: String, CodingKey {
        case id
        case operationID = "operation_id"
        case userID = "sender_user_id"  // Database uses 'sender_user_id' not 'user_id'
        case content = "body_text"       // Database uses 'body_text' not 'content'
        case createdAt = "created_at"
        case userName = "user_name"
        case mediaPath = "media_path"
        case mediaType = "media_type"
    }
}
