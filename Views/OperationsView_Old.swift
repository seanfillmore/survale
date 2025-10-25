import SwiftUI

struct OperationsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var store = OperationStore.shared
    @State private var showingCreate = false
    @State private var showingEdit = false
    @State private var operationToEdit: Operation?
    @State private var showingEndConfirm = false

    var body: some View {
        NavigationStack {
            List {
                // Show current active operation banner if user is in one
                if let activeOpId = appState.activeOperationID,
                   let activeOp = store.operations.first(where: { $0.id == activeOpId }) {
                    Section {
                        Button {
                            print("👆 Button tapped!")
                            operationToEdit = activeOp
                            showingEdit = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Your Active Operation")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Text(activeOp.name)
                                        .font(.headline)
                                }
                                
                                Spacer()
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            // Only case agent can end the operation
                            if let userId = appState.currentUserID, activeOp.createdByUserId == userId {
                                Button(role: .destructive) {
                                    print("🛑 End button tapped")
                                    showingEndConfirm = true
                                } label: {
                                    Label("End", systemImage: "stop.circle")
                                }
                            }
                        }
                        .onAppear {
                            print("🎯 Active operation banner appeared")
                            print("   Current user ID: \(String(describing: appState.currentUserID))")
                            print("   Case agent ID: \(activeOp.createdByUserId)")
                            print("   Is case agent: \(appState.currentUserID == activeOp.createdByUserId)")
                        }
                    }
                }
                
                Section("Active Operations") {
                    if store.operations.isEmpty {
                        Text("No active operations")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.operations) { op in
                            OperationRow(
                                operation: op,
                                isMember: store.isMember(of: op.id),
                                isCurrentActive: appState.activeOperationID == op.id,
                                onTap: {
                                    // Only allow setting active if user is a member
                                    if store.isMember(of: op.id) {
                                        appState.activeOperationID = op.id
                                    }
                                }
                            )
                        }
                    }
                }
                
                // Previous (ended) operations
                if !store.previousOperations.isEmpty {
                    Section("Previous Operations") {
                        ForEach(store.previousOperations) { op in
                            NavigationLink(destination: OperationDetailView(operation: op)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(op.name)
                                        .font(.headline)
                                    
                                    if let incidentNumber = op.incidentNumber {
                                        Text("Incident / Case Number: \(incidentNumber)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    if let endedAt = op.endsAt {
                                        Text("Ended: \(endedAt.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .refreshable {
                // Pull-to-refresh
                if let userID = appState.currentUserID {
                    await store.loadOperations(for: userID)
                }
            }
            .navigationTitle("Operations")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }

            .sheet(isPresented: $showingCreate) { CreateOperationView() }
            .sheet(isPresented: $showingEdit) {
                if let operation = operationToEdit {
                    EditOperationView(operation: operation)
                }
            }
            .alert("End Operation", isPresented: $showingEndConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("End Operation", role: .destructive) {
                    Task {
                        await endCurrentOperation()
                    }
                }
            } message: {
                Text("Are you sure you want to end this operation? All members will be removed and the operation will be moved to Previous Operations.")
            }
            .task {
                // Load operations when view appears and user is authenticated
                if let userID = appState.currentUserID {
                    await store.loadOperations(for: userID)
                }
            }
            .onChange(of: showingCreate) { oldValue, newValue in
                // Reload operations when create sheet is dismissed
                if oldValue && !newValue {
                    Task {
                        if let userID = appState.currentUserID {
                            await store.loadOperations(for: userID)
                        }
                    }
                }
            }
            .onChange(of: showingEdit) { oldValue, newValue in
                // Reload operations when edit sheet is dismissed
                if oldValue && !newValue {
                    Task {
                        if let userID = appState.currentUserID {
                            await store.loadOperations(for: userID)
                        }
                    }
                }
            }
        }
    }
    
    private func endCurrentOperation() async {
        guard let activeOpId = appState.activeOperationID else { return }
        
        do {
            try await store.endOperation(activeOpId)
            
            // Clear active operation from app state
            await MainActor.run {
                appState.activeOperationID = nil
                appState.activeOperation = nil
            }
            
            // Reload operations
            if let userID = appState.currentUserID {
                await store.loadOperations(for: userID)
            }
            
            print("✅ Operation ended successfully")
        } catch {
            print("❌ Failed to end operation: \(error)")
            // TODO: Show user-facing error
        }
    }
}

// MARK: - Operation Row

struct OperationRow: View {
    let operation: Operation
    let isMember: Bool
    let isCurrentActive: Bool
    let onTap: () -> Void
    
    @State private var showingRequestAlert = false
    @State private var requestSent = false
    
    var body: some View {
        HStack {
            // Left side: Operation info
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(operation.name)
                        .font(.headline)
                    
                    Text("Incident / Case Number: \(operation.incidentNumber ?? "N/A")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Right side: Badges/Buttons
            HStack(spacing: 8) {
                if isMember {
                    // Show "You're in" badge
                    Text("Member")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.2))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    if isCurrentActive {
                        // Show "Active" badge
                        Text("Active")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                } else if requestSent {
                    // Show "Requested" badge
                    Text("Requested")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    // Show "Request" button
                    Button {
                        showingRequestAlert = true
                    } label: {
                        Text("Request")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.gray.opacity(0.2))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .alert("Request to Join", isPresented: $showingRequestAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Request") {
                Task {
                    await sendJoinRequest()
                }
            }
        } message: {
            Text("Request to join \"\(operation.name)\"? The operation creator will be notified.")
        }
    }
    
    private func sendJoinRequest() async {
        do {
            try await SupabaseRPCService.shared.requestJoinOperation(operationId: operation.id)
            await MainActor.run {
                requestSent = true
            }
        } catch {
            print("❌ Failed to send join request: \(error)")
        }
    }
}
