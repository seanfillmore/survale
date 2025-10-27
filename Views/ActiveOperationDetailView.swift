//
//  ActiveOperationDetailView.swift
//  Survale
//
//  Read-only detail view for active operations with optional edit button
//

import SwiftUI
import MapKit

struct TransferSheetData: Identifiable {
    let id = UUID()
    let members: [User]
}

struct ActiveOperationDetailView: View {
    let operation: Operation
    
    @EnvironmentObject var appState: AppState
    @State private var targets: [OpTarget] = []
    @State private var staging: [StagingPoint] = []
    @State private var isLoading = true
    @State private var showingEdit = false
    @State private var selectedTarget: OpTarget?
    @State private var selectedStaging: StagingPoint?
    @State private var isMember = false
    @State private var isRequestingJoin = false
    @State private var joinRequestError: String?
    @State private var pendingRequests: [JoinRequest] = []
    @State private var showingJoinRequests = false
    @State private var isRefreshing = false
    @State private var showingEndConfirm = false
    @State private var transferSheetData: TransferSheetData?
    @State private var showingLeaveConfirm = false
    @State private var operationMembers: [User] = []
    @State private var showingCloneOperation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: operationIcon)
                        .font(.system(size: 50))
                        .foregroundStyle(operationColor.gradient)
                    
                    Text(operation.name)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                    
                    if let incidentNumber = operation.incidentNumber {
                        Text("Incident / Case Number: \(incidentNumber)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Status badge
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusText)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(statusColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.15))
                    .cornerRadius(12)
                }
                .padding()
                
                // Quick actions
                if isYourActiveOperation && isMember {
                    // Edit button and join requests for case agent
                    VStack(spacing: 12) {
                        Button {
                            showingEdit = true
                        } label: {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Operation")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .cornerRadius(12)
                        }
                        
                        // Join requests button (case agent only)
                        if isCaseAgent {
                            Button {
                                showingJoinRequests = true
                            } label: {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                    Text("Join Requests")
                                    if !pendingRequests.isEmpty {
                                        Text("(\(pendingRequests.count))")
                                            .font(.caption.bold())
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(pendingRequests.isEmpty ? Color.gray.opacity(0.1) : Color.orange.opacity(0.1))
                                .foregroundColor(pendingRequests.isEmpty ? .secondary : .orange)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                } else if !isMember && operation.state != .ended {
                    // Request to join button for non-members
                    VStack(spacing: 12) {
                        Button {
                            requestToJoin()
                        } label: {
                            HStack {
                                if isRequestingJoin {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "person.badge.plus")
                                    Text("Request to Join")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .foregroundStyle(.green)
                            .cornerRadius(12)
                        }
                        .disabled(isRequestingJoin)
                        
                        if let error = joinRequestError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        
                        Text("You're not a member of this operation. Request to join to see targets and participate.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                }
                
                // Targets Section
                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    if !targets.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "target")
                                    .foregroundStyle(.blue)
                                Text("Targets")
                                    .font(.title2.bold())
                                Spacer()
                                Text("\(targets.count)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                            
                            ForEach(targets) { target in
                                Button {
                                    selectedTarget = target
                                } label: {
                                    TargetDetailCard(target: target)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Staging Points Section
                    if !staging.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "mappin.circle")
                                    .foregroundStyle(.green)
                                Text("Staging Points")
                                    .font(.title2.bold())
                                Spacer()
                                Text("\(staging.count)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                            
                            ForEach(staging) { stage in
                                Button {
                                    selectedStaging = stage
                                } label: {
                                    StagingDetailCard(staging: stage)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    if targets.isEmpty && staging.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary)
                            Text("No targets or staging points yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 40)
                    }
                }
                
                // Operation management buttons
                if isYourActiveOperation && isMember {
                    VStack(spacing: 12) {
                        Divider()
                            .padding(.vertical)
                        
                        // Transfer Operation button (case agent only)
                        if isCaseAgent {
                            Button {
                                Task {
                                    // Reload members to ensure we have the latest data
                                    await loadOperationMembers()
                                    await MainActor.run {
                                        // Set members to trigger sheet presentation
                                        transferSheetData = TransferSheetData(members: operationMembers)
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.triangle.swap")
                                    Text("Transfer Operation")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .foregroundStyle(.orange)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Leave Operation button (team members only, not case agent)
                        if !isCaseAgent {
                            Button {
                                showingLeaveConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Leave Operation")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .foregroundStyle(.orange)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        
                        // End Operation button (case agent only)
                        if isCaseAgent {
                            Button {
                                showingEndConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("End Operation")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .foregroundStyle(.red)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Clone Operation button (for ended operations)
                if operation.state == .ended && isCaseAgent {
                    VStack(spacing: 12) {
                        Divider()
                            .padding(.vertical)
                        
                        Button {
                            showingCloneOperation = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Clone Operation")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        Text("Create a new operation with the same targets and locations")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.bottom)
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Operation Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEdit) {
            EditOperationView(operation: operation)
        }
        .sheet(item: $selectedTarget) { target in
            TargetFullDetailView(target: target)
        }
        .sheet(item: $selectedStaging) { staging in
            StagingFullDetailView(staging: staging)
        }
        .sheet(isPresented: $showingJoinRequests) {
            JoinRequestsSheet(operation: operation, pendingRequests: $pendingRequests)
        }
        .refreshable {
            await refreshData()
        }
        .sheet(item: $transferSheetData) { data in
            TransferOperationSheet(operation: operation, members: data.members)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showingCloneOperation) {
            CreateOperationView(
                clonedOperation: operation,
                clonedTargets: targets,
                clonedStaging: staging
            )
        }
        .alert("Leave Operation", isPresented: $showingLeaveConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Leave", role: .destructive) {
                Task {
                    await leaveOperation()
                }
            }
        } message: {
            Text("Are you sure you want to leave this operation? You will need to request to rejoin if you change your mind.")
        }
        .alert("End Operation", isPresented: $showingEndConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("End Operation", role: .destructive) {
                Task {
                    await endOperation()
                }
            }
        } message: {
            Text("Are you sure you want to end this operation? All members will be removed and the operation will be moved to Previous Operations.")
        }
        .task {
            await loadOperationData()
            await loadOperationMembers()
            if isCaseAgent {
                await loadJoinRequests()
            }
        }
        .onAppear {
            // Refresh data when returning from edit
            Task {
                await refreshData()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isYourActiveOperation: Bool {
        appState.activeOperationID == operation.id
    }
    
    private var isCaseAgent: Bool {
        operation.createdByUserId == appState.currentUserID
    }
    
    private var operationIcon: String {
        if operation.state == .ended {
            return "checkmark.circle.fill"
        } else if isYourActiveOperation {
            return "bolt.circle.fill"
        } else {
            return "doc.text.fill"
        }
    }
    
    private var operationColor: Color {
        if operation.state == .ended {
            return .gray
        } else if isYourActiveOperation {
            return .green
        } else {
            return .blue
        }
    }
    
    private var statusText: String {
        if operation.state == .ended {
            return "Ended"
        } else if isYourActiveOperation {
            return "Your Active Operation"
        } else {
            return "Active"
        }
    }
    
    private var statusColor: Color {
        if operation.state == .ended {
            return .gray
        } else if isYourActiveOperation {
            return .green
        } else {
            return .blue
        }
    }
    
    // MARK: - Data Loading
    
    private func loadOperationData() async {
        isLoading = true
        defer { isLoading = false }
        
        // Check if user is a member using OperationStore
        let memberOperationIds = await OperationStore.shared.memberOperationIds
        let isUserMember = memberOperationIds.contains(operation.id)
        
        await MainActor.run {
            self.isMember = isUserMember
        }
        
        // Load targets if user is a member OR if they're the case agent (for cloning ended operations)
        let shouldLoadTargets = isUserMember || isCaseAgent
        
        guard shouldLoadTargets else {
            print("ℹ️ User is not a member or case agent of operation \(operation.id) - skipping target load")
            return
        }
        
        do {
            let loadedData = try await SupabaseRPCService.shared.getOperationTargets(operationId: operation.id)
            await MainActor.run {
                self.targets = loadedData.targets
                self.staging = loadedData.staging
            }
        } catch {
            print("❌ Failed to load operation data: \(error)")
        }
    }
    
    private func loadOperationMembers() async {
        do {
            let members = try await SupabaseRPCService.shared.getOperationMembers(operationId: operation.id)
            await MainActor.run {
                self.operationMembers = members
            }
        } catch {
            print("❌ Failed to load operation members: \(error)")
        }
    }
    
    private func leaveOperation() async {
        guard let userId = appState.currentUserID else { return }
        
        do {
            try await SupabaseRPCService.shared.leaveOperation(operationId: operation.id, userId: userId)
            
            // Clear active operation from app state
            await MainActor.run {
                appState.activeOperationID = nil
                appState.activeOperation = nil
            }
            
            // Reload operations list
            await OperationStore.shared.loadOperations(for: userId)
            
            print("✅ Left operation successfully")
        } catch {
            print("❌ Failed to leave operation: \(error)")
        }
    }
    
    private func endOperation() async {
        do {
            try await SupabaseRPCService.shared.endOperation(operationId: operation.id)
            
            // Clear active operation from app state
            await MainActor.run {
                appState.activeOperationID = nil
                appState.activeOperation = nil
            }
            
            // Reload operations list
            if let userId = appState.currentUserID {
                await OperationStore.shared.loadOperations(for: userId)
            }
            
            print("✅ Operation ended successfully")
        } catch {
            print("❌ Failed to end operation: \(error)")
        }
    }
    
    private func refreshData() async {
        print("🔄 Refreshing operation data...")
        
        // Check membership status
        let memberOperationIds = await OperationStore.shared.memberOperationIds
        let isUserMember = memberOperationIds.contains(operation.id)
        
        await MainActor.run {
            self.isMember = isUserMember
        }
        
        // Load targets if user is a member OR if they're the case agent (for cloning ended operations)
        let shouldLoadTargets = isUserMember || isCaseAgent
        
        guard shouldLoadTargets else {
            print("ℹ️ User is not a member or case agent - skipping refresh")
            return
        }
        
        do {
            let loadedData = try await SupabaseRPCService.shared.getOperationTargets(operationId: operation.id)
            await MainActor.run {
                self.targets = loadedData.targets
                self.staging = loadedData.staging
                print("✅ Refreshed: \(loadedData.targets.count) targets, \(loadedData.staging.count) staging points")
            }
            
            // Also refresh join requests if case agent
            if isCaseAgent {
                await loadJoinRequests()
            }
        } catch {
            print("❌ Failed to refresh data: \(error)")
        }
    }
    
    private func requestToJoin() {
        isRequestingJoin = true
        joinRequestError = nil
        
        Task {
            do {
                try await SupabaseRPCService.shared.requestJoinOperation(operationId: operation.id)
                await MainActor.run {
                    isRequestingJoin = false
                    joinRequestError = nil
                    // Show success message
                    print("✅ Join request sent for operation: \(operation.name)")
                }
            } catch {
                await MainActor.run {
                    isRequestingJoin = false
                    joinRequestError = "Failed to send request: \(error.localizedDescription)"
                    print("❌ Failed to send join request: \(error)")
                }
            }
        }
    }
    
    private func loadJoinRequests() async {
        do {
            let requests = try await SupabaseRPCService.shared.getPendingJoinRequests(operationId: operation.id)
            await MainActor.run {
                self.pendingRequests = requests
                print("📬 Loaded \(requests.count) pending join request(s)")
            }
        } catch {
            // Ignore cancellation errors (Code -999) - these are normal when views are dismissed
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                print("ℹ️ Join requests load was cancelled (this is normal)")
            } else {
                print("❌ Failed to load join requests: \(error)")
            }
        }
    }
}

// MARK: - Join Requests Sheet

struct JoinRequestsSheet: View {
    let operation: Operation
    @Binding var pendingRequests: [JoinRequest]
    @Environment(\.dismiss) private var dismiss
    @State private var processingRequestId: UUID?
    
    var body: some View {
        NavigationStack {
            List {
                if pendingRequests.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("No Pending Requests")
                            .font(.headline)
                        Text("Users who request to join will appear here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    ForEach(pendingRequests) { request in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("User ID: \(request.requesterUserId.uuidString.prefix(8))...")
                                    .font(.headline)
                                Text(request.createdAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if processingRequestId == request.id {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Button("Approve") {
                                    approveRequest(request)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                
                                Button("Reject") {
                                    rejectRequest(request)
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Join Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func approveRequest(_ request: JoinRequest) {
        processingRequestId = request.id
        Task {
            do {
                try await SupabaseRPCService.shared.approveJoinRequest(requestId: request.id, operationId: operation.id)
                await MainActor.run {
                    pendingRequests.removeAll { $0.id == request.id }
                    processingRequestId = nil
                    print("✅ Approved join request from user \(request.requesterUserId)")
                }
            } catch {
                await MainActor.run {
                    processingRequestId = nil
                    print("❌ Failed to approve request: \(error)")
                }
            }
        }
    }
    
    private func rejectRequest(_ request: JoinRequest) {
        processingRequestId = request.id
        Task {
            do {
                try await SupabaseRPCService.shared.rejectJoinRequest(requestId: request.id)
                await MainActor.run {
                    pendingRequests.removeAll { $0.id == request.id }
                    processingRequestId = nil
                    print("✅ Rejected join request from user \(request.requesterUserId)")
                }
            } catch {
                await MainActor.run {
                    processingRequestId = nil
                    print("❌ Failed to reject request: \(error)")
                }
            }
        }
    }
}

// MARK: - Target Detail Card

struct TargetDetailCard: View {
    let target: OpTarget
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: targetIcon)
                    .foregroundStyle(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(target.label)
                        .font(.headline)
                    
                    Text(targetSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if !target.images.isEmpty {
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundStyle(.secondary)
                        Text("\(target.images.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            if let notes = target.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 30)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var targetIcon: String {
        switch target.kind {
        case .person: return "person.fill"
        case .vehicle: return "car.fill"
        case .location: return "mappin.circle.fill"
        }
    }
    
    private var targetSubtitle: String {
        switch target.kind {
        case .person:
            var parts: [String] = []
            if let name = target.personName {
                parts.append(name)
            }
            if let phone = target.phone {
                parts.append(phone)
            }
            return parts.isEmpty ? "Person" : parts.joined(separator: " • ")
            
        case .vehicle:
            var parts: [String] = []
            if let make = target.vehicleMake {
                parts.append(make)
            }
            if let model = target.vehicleModel {
                parts.append(model)
            }
            if let plate = target.licensePlate {
                parts.append(plate)
            }
            return parts.isEmpty ? "Vehicle" : parts.joined(separator: " • ")
            
        case .location:
            return target.locationAddress ?? "Location"
        }
    }
}

// MARK: - Staging Detail Card

struct StagingDetailCard: View {
    let staging: StagingPoint
    
    var body: some View {
        HStack {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.green)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(staging.label)
                    .font(.headline)
                
                if !staging.address.isEmpty {
                    Text(staging.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let lat = staging.lat, let lng = staging.lng {
                    Text("Coordinates: \(lat, specifier: "%.6f"), \(lng, specifier: "%.6f")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Target Full Detail View

struct TargetFullDetailView: View {
    let target: OpTarget
    @Environment(\.dismiss) private var dismiss
    @Environment(\.navigateToMap) private var navigateToMap
    @State private var showingImageGallery = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: targetIcon)
                            .font(.system(size: 60))
                            .foregroundStyle(.blue.gradient)
                        
                        Text(target.label)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        
                        Text(targetTypeLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(8)
                    }
                    .padding()
                    
                    // Details based on type
                    VStack(alignment: .leading, spacing: 16) {
                        switch target.kind {
                        case .person:
                            if let firstName = target.personFirstName {
                                TargetDetailRow(label: "First Name", value: firstName)
                            }
                            if let lastName = target.personLastName {
                                TargetDetailRow(label: "Last Name", value: lastName)
                            }
                            if let phone = target.phone {
                                TargetDetailRow(label: "Phone", value: phone, icon: "phone.fill")
                            }
                            
                        case .vehicle:
                            if let make = target.vehicleMake {
                                TargetDetailRow(label: "Make", value: make)
                            }
                            if let model = target.vehicleModel {
                                TargetDetailRow(label: "Model", value: model)
                            }
                            if let color = target.vehicleColor {
                                TargetDetailRow(label: "Color", value: color)
                            }
                            if let plate = target.licensePlate {
                                TargetDetailRow(label: "License Plate", value: plate, icon: "number.square.fill")
                            }
                            
                        case .location:
                            if let address = target.locationAddress {
                                TargetDetailRow(label: "Address", value: address, icon: "mappin.circle.fill")
                            }
                            if let name = target.locationName {
                                TargetDetailRow(label: "Custom Label", value: name)
                            }
                            if let lat = target.locationLat, let lng = target.locationLng {
                                TargetDetailRow(label: "Coordinates", value: String(format: "%.6f, %.6f", lat, lng), icon: "location.fill")
                                
                                // View on Map button
                                Button {
                                    let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                                    navigateToMap(MapNavigationTarget(coordinate: coordinate, label: target.label))
                                    dismiss()
                                } label: {
                                    HStack {
                                        Image(systemName: "map.fill")
                                        Text("View on Map")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .cornerRadius(12)
                                }
                                .padding(.top, 8)
                            }
                        }
                        
                        if let notes = target.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Notes", systemImage: "note.text")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                
                                Text(notes)
                                    .font(.body)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Photos section
                    if !target.images.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Photos (\(target.images.count))", systemImage: "photo.on.rectangle.angled")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            // Tappable thumbnail grid
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(target.images) { image in
                                        Button {
                                            showingImageGallery = true
                                        } label: {
                                            ImageThumbnailPreview(image: image)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Target Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingImageGallery) {
                if #available(iOS 16.0, *) {
                    TargetImageGalleryView(images: target.images)
                }
            }
        }
    }
    
    private var targetIcon: String {
        switch target.kind {
        case .person: return "person.fill"
        case .vehicle: return "car.fill"
        case .location: return "mappin.circle.fill"
        }
    }
    
    private var targetTypeLabel: String {
        switch target.kind {
        case .person: return "Person"
        case .vehicle: return "Vehicle"
        case .location: return "Location"
        }
    }
}

// MARK: - Staging Full Detail View

struct StagingFullDetailView: View {
    let staging: StagingPoint
    @Environment(\.dismiss) private var dismiss
    @Environment(\.navigateToMap) private var navigateToMap
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green.gradient)
                        
                        Text(staging.label)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        
                        Text("Staging Point")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(8)
                    }
                    .padding()
                    
                    // Details
                    VStack(alignment: .leading, spacing: 16) {
                        if !staging.address.isEmpty {
                            TargetDetailRow(label: "Address", value: staging.address, icon: "mappin.circle.fill")
                        }
                        
                        if let lat = staging.lat, let lng = staging.lng {
                            TargetDetailRow(label: "Latitude", value: String(format: "%.6f", lat), icon: "location.north.fill")
                            TargetDetailRow(label: "Longitude", value: String(format: "%.6f", lng), icon: "location.fill")
                            
                            // View on Map button (in-app)
                            Button {
                                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                                navigateToMap(MapNavigationTarget(coordinate: coordinate, label: staging.label))
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "map.fill")
                                    Text("View on Map")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .cornerRadius(12)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Staging Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Helper Views

struct TargetDetailRow: View {
    let label: String
    let value: String
    var icon: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(label)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.secondary)
            
            Text(value)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(8)
        }
    }
}

struct ImageThumbnailPreview: View {
    let image: OpTargetImage
    @State private var uiImage: UIImage?
    
    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ProgressView()
            }
        }
        .frame(width: 80, height: 80)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        do {
            if let url = image.remoteURL {
                let downloaded = try await SupabaseStorageService.shared.downloadImage(from: url)
                await MainActor.run {
                    self.uiImage = downloaded
                }
            }
        } catch {
            // Ignore cancellation errors (normal when scrolling)
            if (error as NSError).code != NSURLErrorCancelled {
                print("❌ Failed to load thumbnail: \(error)")
            }
        }
    }
}

