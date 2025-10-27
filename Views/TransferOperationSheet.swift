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
        NavigationView {
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

// MARK: - Color Extension (if not already defined elsewhere)

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    TransferOperationSheet(
        operation: Operation(
            id: UUID(),
            name: "Test Operation",
            incidentNumber: "2024-001",
            createdByUserId: UUID(),
            status: .active
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

