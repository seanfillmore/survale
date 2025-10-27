import SwiftUI

struct EditOperationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    let operation: Operation
    
    enum Step: Hashable { case name, targets, staging, teamMembers, review }
    @State private var step: Step = .name
    
    @State private var incidentNumber = ""
    @State private var name = ""
    @State private var targets: [OpTarget] = []
    @State private var staging: [StagingPoint] = []
    @State private var selectedMemberIds: Set<UUID> = []
    
    @State private var isLoading = false
    
    // Track originally loaded data to detect what's new
    @State private var originalTargets: [OpTarget] = []
    @State private var originalStaging: [StagingPoint] = []
    
    init(operation: Operation) {
        self.operation = operation
        // Initialize state with operation data
        _incidentNumber = State(initialValue: operation.incidentNumber ?? "")
        _name = State(initialValue: operation.name)
        _targets = State(initialValue: operation.targets)
        _staging = State(initialValue: operation.staging)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                EditProgressBar(step: step)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Content area
                content
                    .frame(maxHeight: .infinity)
                
                // Footer at bottom
                footer
            }
            .navigationTitle("Edit Operation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .task {
                await loadOperationData()
            }
        }
    }
    
    @ViewBuilder private var content: some View {
        switch step {
        case .name:
            VStack(spacing: 24) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue.gradient)
                    .padding(.top, 40)
                
                VStack(spacing: 8) {
                    Text("Edit Operation")
                        .font(.title2.bold())
                    
                    Text("Update the operation details")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Incident / Case Number")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        TextField("e.g., 2024-10-19-001", text: $incidentNumber)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Operation Name")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        TextField("e.g., Operation Nightfall", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                    }
                }
                .padding(.horizontal, 24)
            }
            
        case .targets:
            TargetsEditor(targets: $targets)
            
        case .staging:
            StagingEditor(staging: $staging)
            
        case .teamMembers:
            TeamMemberSelector(selectedMemberIds: $selectedMemberIds)
            
        case .review:
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green.gradient)
                        .padding(.top, 40)
                    
                    Text("Review Changes")
                        .font(.title2.bold())
                    
                    VStack(spacing: 16) {
                        EditReviewCard(icon: "target", title: "Operation", value: name.isEmpty ? "Untitled Operation" : name)
                        EditReviewCard(icon: "person.2", title: "Targets", value: "\(targets.count) target\(targets.count == 1 ? "" : "s")")
                        EditReviewCard(icon: "mappin.circle", title: "Staging Points", value: "\(staging.count) location\(staging.count == 1 ? "" : "s")")
                        EditReviewCard(icon: "person.3", title: "Team Members", value: "\(selectedMemberIds.count) member\(selectedMemberIds.count == 1 ? "" : "s") selected")
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
        }
    }
    
    @ViewBuilder private var footer: some View {
        VStack(spacing: 12) {
            Divider()
            
            HStack(spacing: 12) {
                if step != .name {
                    Button {
                        previous()
                    } label: {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                
                Button {
                    if step == .review {
                        Task { await saveChanges() }
                    } else {
                        next()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(step == .review ? "Save Changes" : "Next")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(disableNext || isLoading)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
    
    private var disableNext: Bool {
        switch step {
        case .name: return name.trimmingCharacters(in: .whitespaces).isEmpty
        case .targets: return false
        case .staging: return false
        case .teamMembers: return false
        case .review: return false
        }
    }
    
    private func next() {
        switch step {
        case .name: step = .targets
        case .targets: step = .staging
        case .staging: step = .teamMembers
        case .teamMembers: step = .review
        case .review: break
        }
    }
    
    private func previous() {
        switch step {
        case .name: break
        case .targets: step = .name
        case .staging: step = .targets
        case .teamMembers: step = .staging
        case .review: step = .teamMembers
        }
    }
    
    private func loadOperationData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load targets from database
            let loadedTargets = try await SupabaseRPCService.shared.getOperationTargets(operationId: operation.id)
            print("📥 Loaded \(loadedTargets.targets.count) targets, \(loadedTargets.staging.count) staging points")
            
            await MainActor.run {
                self.targets = loadedTargets.targets
                self.staging = loadedTargets.staging
                // Store originals for comparison later
                self.originalTargets = loadedTargets.targets
                self.originalStaging = loadedTargets.staging
            }
        } catch {
            print("❌ Failed to load operation data: \(error)")
        }
    }
    
    private func saveChanges() async {
        guard let userId = appState.currentUserID else {
            print("❌ No current user ID")
            return
        }
        
        guard let teamId = appState.currentUser?.teamId else {
            print("❌ No team ID")
            return
        }
        
        guard let agencyId = appState.currentUser?.agencyId else {
            print("❌ No agency ID")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Update operation details via RPC
            try await SupabaseRPCService.shared.updateOperation(
                operationId: operation.id,
                name: name,
                incidentNumber: incidentNumber.isEmpty ? nil : incidentNumber
            )
            
            print("✅ Operation details updated")
            
            // Detect changes: additions and deletions
            let originalTargetIds = Set(originalTargets.map { $0.id })
            let currentTargetIds = Set(targets.map { $0.id })
            let newTargets = targets.filter { !originalTargetIds.contains($0.id) }
            let deletedTargetIds = originalTargetIds.subtracting(currentTargetIds)
            
            let originalStagingIds = Set(originalStaging.map { $0.id })
            let currentStagingIds = Set(staging.map { $0.id })
            let newStaging = staging.filter { !originalStagingIds.contains($0.id) }
            let deletedStagingIds = originalStagingIds.subtracting(currentStagingIds)
            
            print("💾 Changes: +\(newTargets.count) targets, -\(deletedTargetIds.count) targets, +\(newStaging.count) staging, -\(deletedStagingIds.count) staging")
            
            // Delete removed targets
            for targetId in deletedTargetIds {
                do {
                    try await SupabaseRPCService.shared.deleteTarget(targetId: targetId)
                    print("  🗑️ Deleted target: \(targetId)")
                } catch {
                    print("  ⚠️ Failed to delete target \(targetId): \(error)")
                }
            }
            
            // Delete removed staging points
            for stagingId in deletedStagingIds {
                do {
                    try await SupabaseRPCService.shared.deleteStagingPoint(stagingId: stagingId)
                    print("  🗑️ Deleted staging point: \(stagingId)")
                } catch {
                    print("  ⚠️ Failed to delete staging point \(stagingId): \(error)")
                }
            }
            
            // Save new targets
            for target in newTargets {
                do {
                    // Convert OpTargetImage to dictionary for RPC
                    let imagesDicts = target.images.map { img -> [String: Any] in
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        
                        var dict: [String: Any] = [
                            "id": img.id.uuidString,
                            "storage_kind": img.storageKind.rawValue,
                            "filename": img.filename,
                            "created_at": formatter.string(from: img.createdAt)
                        ]
                        if let url = img.remoteURL {
                            dict["remote_url"] = url.absoluteString
                        }
                        if let localPath = img.localPath {
                            dict["local_path"] = localPath
                        }
                        if let caption = img.caption {
                            dict["caption"] = caption
                        }
                        if let width = img.pixelWidth {
                            dict["pixel_width"] = width
                        }
                        if let height = img.pixelHeight {
                            dict["pixel_height"] = height
                        }
                        if let size = img.byteSize {
                            dict["byte_size"] = size
                        }
                        return dict
                    }
                    
                    switch target.kind {
                    case .person:
                        _ = try await SupabaseRPCService.shared.createPersonTarget(
                            operationId: operation.id,
                            firstName: target.personFirstName ?? "",
                            lastName: target.personLastName ?? "",
                            phone: target.phone,
                            images: imagesDicts
                        )
                    case .vehicle:
                        _ = try await SupabaseRPCService.shared.createVehicleTarget(
                            operationId: operation.id,
                            make: target.vehicleMake,
                            model: target.vehicleModel,
                            color: target.vehicleColor,
                            plate: target.licensePlate,
                            images: imagesDicts
                        )
                    case .location:
                        _ = try await SupabaseRPCService.shared.createLocationTarget(
                            operationId: operation.id,
                            address: target.locationAddress ?? "",
                            label: target.locationName,
                            city: nil,
                            zipCode: nil,
                            latitude: target.locationLat,
                            longitude: target.locationLng,
                            images: imagesDicts
                        )
                    }
                    print("  ✅ Saved target: \(target.label) (\(target.images.count) image(s))")
                } catch {
                    print("  ⚠️ Failed to save target \(target.label): \(error)")
                }
            }
            
            // Save new staging points
            for stage in newStaging {
                guard let lat = stage.lat, let lng = stage.lng else {
                    print("  ⚠️ Skipping staging point \(stage.label): no coordinates")
                    continue
                }
                
                do {
                    _ = try await SupabaseRPCService.shared.createStagingPoint(
                        operationId: operation.id,
                        label: stage.label,
                        latitude: lat,
                        longitude: lng
                    )
                    print("  ✅ Saved staging point: \(stage.label)")
                } catch {
                    print("  ⚠️ Failed to save staging point \(stage.label): \(error)")
                }
            }
            
            // Add newly selected team members to the operation
            if !selectedMemberIds.isEmpty {
                print("👥 Adding \(selectedMemberIds.count) member(s) to operation...")
                do {
                    let addedCount = try await SupabaseRPCService.shared.addOperationMembers(
                        operationId: operation.id,
                        memberIds: Array(selectedMemberIds)
                    )
                    print("✅ Successfully added \(addedCount) member(s)")
                } catch {
                    print("⚠️ Failed to add members: \(error)")
                    // Continue anyway - other changes were saved successfully
                }
            }
            
            print("✅ Operation updated successfully")
            
            await MainActor.run {
                dismiss()
            }
        } catch {
            print("❌ Failed to update operation: \(error)")
            // TODO: Show user-facing error
        }
    }
}

// Progress bar for edit operation view
private struct EditProgressBar: View {
    let step: EditOperationView.Step
    
    private var progress: Double {
        switch step {
        case .name: return 0.2
        case .targets: return 0.4
        case .staging: return 0.6
        case .teamMembers: return 0.8
        case .review: return 1.0
        }
    }
    
    private var stepLabel: String {
        switch step {
        case .name: return "1 of 5"
        case .targets: return "2 of 5"
        case .staging: return "3 of 5"
        case .teamMembers: return "4 of 5"
        case .review: return "5 of 5"
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach([EditOperationView.Step.name, .targets, .staging, .teamMembers, .review], id: \.self) { s in
                    Circle()
                        .fill(s.rawValue <= step.rawValue ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                    
                    if s != .review {
                        Rectangle()
                            .fill(s.rawValue < step.rawValue ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
            
            Text(stepLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }
}

extension EditOperationView.Step: Comparable {
    var rawValue: Int {
        switch self {
        case .name: return 0
        case .targets: return 1
        case .staging: return 2
        case .teamMembers: return 3
        case .review: return 4
        }
    }
    
    static func < (lhs: EditOperationView.Step, rhs: EditOperationView.Step) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// Review card for edit operation view
private struct EditReviewCard: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body.weight(.medium))
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

