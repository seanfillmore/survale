import SwiftUI

struct TransferOperationSheet: View {
    let operation: Operation
    let members: [User]
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var selectedUserId: UUID?
    @State private var isTransferring = false
    @State private var error: String?
    
    var body: some View {
        let _ = print("📋 TransferOperationSheet: Received \(members.count) members")
        let _ = members.forEach { member in
            print("   Member: \(member.callsign ?? "no callsign") (\(member.email)) - ID: \(member.id)")
        }
        let _ = print("   Current user ID: \(appState.currentUserID?.uuidString ?? "nil")")
        let filteredMembers = members.filter { $0.id != appState.currentUserID }
        let _ = print("   After filtering current user: \(filteredMembers.count) members")
        
        return NavigationView {
            Form {
                Section {
                    Text("Transfer case agent responsibilities to another team member. You will become a regular member of the operation.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Section("Select New Case Agent") {
                    if members.isEmpty {
                        Text("No other members available")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    } else {
                        ForEach(members.filter { $0.id != appState.currentUserID }) { member in
                            Button {
                                selectedUserId = member.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        if let callsign = member.callsign, !callsign.isEmpty {
                                            Text(callsign)
                                                .font(.body)
                                                .foregroundStyle(.primary)
                                        } else if !member.email.isEmpty {
                                            Text(member.email)
                                                .font(.body)
                                                .foregroundStyle(.primary)
                                        } else {
                                            Text("User \(member.id.uuidString.prefix(8))")
                                                .font(.body)
                                                .foregroundStyle(.primary)
                                        }
                                        
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color(hex: member.vehicleColor) ?? .gray)
                                                .frame(width: 10, height: 10)
                                            Text(member.vehicleType.displayName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedUserId == member.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
                
                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
                
                Section {
                    Button {
                        Task {
                            await transferOperation()
                        }
                    } label: {
                        HStack {
                            if isTransferring {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.triangle.swap")
                                Text("Transfer Operation")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(selectedUserId == nil || isTransferring)
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Transfer Operation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func transferOperation() async {
        guard let newCaseAgentId = selectedUserId else { return }
        
        isTransferring = true
        error = nil
        
        do {
            try await SupabaseRPCService.shared.transferOperation(
                operationId: operation.id,
                newCaseAgentId: newCaseAgentId
            )
            
            // Reload operations to reflect the change
            if let userId = appState.currentUserID {
                await OperationStore.shared.loadOperations(for: userId)
            }
            
            print("✅ Operation transferred successfully")
            
            await MainActor.run {
                dismiss()
            }
        } catch {
            print("❌ Failed to transfer operation: \(error)")
            await MainActor.run {
                self.error = "Failed to transfer: \(error.localizedDescription)"
                self.isTransferring = false
            }
        }
    }
}

#Preview {
    TransferOperationSheet(
        operation: Operation(
            id: UUID(),
            name: "Test Operation",
            incidentNumber: "2024-001",
            state: .active,
            createdAt: Date(),
            startsAt: Date(),
            endsAt: nil,
            createdByUserId: UUID(),
            teamId: UUID(),
            agencyId: UUID(),
            targets: [],
            staging: []
        ),
        members: [
            User(
                id: UUID(),
                email: "agent1@example.com",
                teamId: UUID(),
                agencyId: UUID(),
                callsign: "ALPHA-1",
                vehicleType: .sedan,
                vehicleColor: "#FF0000"
            )
        ]
    )
    .environmentObject(AppState())
}

