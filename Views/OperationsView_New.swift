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
                // Active operation banner
                if let activeOp = activeOperation {
                    activeOperationBanner(activeOp)
                }
                
                // All active operations
                activeOperationsSection
                
                // Previous operations
                if !store.previousOperations.isEmpty {
                    previousOperationsSection
                }
            }
            .refreshable {
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
            .sheet(isPresented: $showingCreate) {
                CreateOperationView()
            }
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
                if let userID = appState.currentUserID {
                    await store.loadOperations(for: userID)
                }
            }
            .onChange(of: showingCreate) { oldValue, newValue in
                if oldValue && !newValue {
                    Task {
                        if let userID = appState.currentUserID {
                            await store.loadOperations(for: userID)
                        }
                    }
                }
            }
            .onChange(of: showingEdit) { oldValue, newValue in
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
    
    // MARK: - Computed Properties
    
    private var activeOperation: Operation? {
        guard let activeOpId = appState.activeOperationID else { return nil }
        return store.operations.first(where: { $0.id == activeOpId })
    }
    
    private var isCaseAgent: Bool {
        guard let userId = appState.currentUserID,
              let activeOp = activeOperation else {
            return false
        }
        return activeOp.createdByUserId == userId
    }
    
    // MARK: - View Builders
    
    @ViewBuilder
    private func activeOperationBanner(_ operation: Operation) -> some View {
        Section {
            Button {
                print("👆 Tapped active operation")
                operationToEdit = operation
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
                        
                        Text(operation.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if isCaseAgent {
                Button(role: .destructive) {
                    print("🛑 End button tapped")
                    showingEndConfirm = true
                } label: {
                    Label("End", systemImage: "stop.circle")
                }
            }
        }
    }
    
    @ViewBuilder
    private var activeOperationsSection: some View {
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
                            if store.isMember(of: op.id) {
                                appState.activeOperationID = op.id
                            }
                        }
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var previousOperationsSection: some View {
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
    
    // MARK: - Actions
    
    private func endCurrentOperation() async {
        guard let activeOpId = appState.activeOperationID else { return }
        
        do {
            try await store.endOperation(activeOpId)
            
            await MainActor.run {
                appState.activeOperationID = nil
                appState.activeOperation = nil
            }
            
            if let userID = appState.currentUserID {
                await store.loadOperations(for: userID)
            }
            
            print("✅ Operation ended successfully")
        } catch {
            print("❌ Failed to end operation: \(error)")
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
            
            HStack(spacing: 8) {
                if isMember {
                    Text("Member")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.2))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    if isCurrentActive {
                        Text("Active")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                } else if requestSent {
                    Text("Requested")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
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

