//
//  CreateOperationView.swift
//  Survale
//
//  Created by Sean Fillmore on 10/17/25.
//

import SwiftUI
import PhotosUI

struct CreateOperationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    // Optional cloned operation data
    let clonedOperation: Operation?
    let clonedTargets: [OpTarget]
    let clonedStaging: [StagingPoint]

    enum Step: Hashable { case name, targets, staging, teamMembers, review }
    @State private var step: Step = .name

    @State private var incidentNumber = ""
    @State private var name = ""
    @State private var targets: [OpTarget] = []
    @State private var staging: [StagingPoint] = []
    @State private var selectedMemberIds: Set<UUID> = []
    @State private var showingTemplatePicker = false
    
    // Default initializer for creating new operations
    init(clonedOperation: Operation? = nil, clonedTargets: [OpTarget] = [], clonedStaging: [StagingPoint] = []) {
        self.clonedOperation = clonedOperation
        self.clonedTargets = clonedTargets
        self.clonedStaging = clonedStaging
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressBar(step: step)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Content area - takes up remaining space
                content
                    .frame(maxHeight: .infinity)
                
                // Footer at bottom
                footer
            }
            .navigationTitle(clonedOperation != nil ? "Clone Operation" : (step == .name ? "New Operation" : (name.isEmpty ? "Untitled Operation" : name)))
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
            .sheet(isPresented: $showingTemplatePicker) {
                TemplatePickerView { template in
                    applyTemplate(template)
                }
            }
            .onAppear {
                // Pre-fill data if cloning an operation
                if let clonedOp = clonedOperation {
                    name = clonedOp.name + " (Copy)"
                    incidentNumber = clonedOp.incidentNumber ?? ""
                    targets = clonedTargets
                    staging = clonedStaging
                    
                    print("🔄 Cloning operation: \(clonedOp.name)")
                    print("   Targets: \(clonedTargets.count)")
                    print("   Staging: \(clonedStaging.count)")
                }
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .name:
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "target")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue.gradient)
                        .padding(.top, 40)
                    
                    VStack(spacing: 8) {
                        Text("Create Operation")
                            .font(.title2.bold())
                        
                        Text("Enter the basic information")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Incident / Case Number field (first)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Incident / Case Number")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            TextField("e.g., 2024-10-19-001", text: $incidentNumber)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .submitLabel(.next)
                        }
                        
                        // Operation Name field (second)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Operation Name")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            TextField("e.g., Operation Nightfall", text: $name)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .submitLabel(.go)
                                .onSubmit {
                                    if !disableNext {
                                        next()
                                    }
                                }
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // From Template button
                        Button {
                            showingTemplatePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Start from Template")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    
                    // Extra padding at bottom to ensure button is always visible above keyboard
                    Spacer()
                        .frame(height: 100)
                }
            }
            .scrollDismissesKeyboard(.interactively)

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
                        .padding(.top, 20)
                    
                    Text("Ready to Launch")
                        .font(.title2.bold())
                    
                    VStack(spacing: 16) {
                        ReviewCard(icon: "target", title: "Operation", value: name.isEmpty ? "Untitled Operation" : name)
                        ReviewCard(icon: "person.2", title: "Targets", value: "\(targets.count) target\(targets.count == 1 ? "" : "s")")
                        ReviewCard(icon: "mappin.circle", title: "Staging Points", value: "\(staging.count) location\(staging.count == 1 ? "" : "s")")
                        
                        ReviewCard(icon: "person.3", title: "Team Members", value: "\(selectedMemberIds.count) member\(selectedMemberIds.count == 1 ? "" : "s") selected")
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
            
            // Save as Draft button (only on review step)
            if step == .review {
                Button {
                    saveDraft()
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("Save as Draft")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .padding(.horizontal)
            }
            
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
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
                
                Button {
                    if step == .review {
                        createOperation(isDraft: false)
                    } else {
                        next()
                    }
                } label: {
                    HStack {
                        Text(step == .review ? "Create & Activate" : "Next")
                        if step != .review {
                            Image(systemName: "chevron.right")
                        } else {
                            Image(systemName: "checkmark")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(disableNext)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
    }
    
    private func applyTemplate(_ template: OperationTemplate) {
        print("📋 Applying template: \(template.name)")
        print("   Targets: \(template.targets.count)")
        print("   Staging: \(template.staging.count)")
        
        // Debug staging points
        for (index, stage) in template.staging.enumerated() {
            print("   Staging[\(index)]: label='\(stage.label)', address='\(stage.address)', lat=\(stage.lat ?? 0), lng=\(stage.lng ?? 0)")
        }
        
        name = template.name
        targets = template.targets
        staging = template.staging
        showingTemplatePicker = false
    }
    
    private func createOperation(isDraft: Bool) {
        Task {
            do {
                guard let userId = appState.currentUserID else {
                    print("❌ CreateOperation: currentUserID is nil")
                    await MainActor.run {
                        // Show error to user
                        print("Please ensure you're logged in and your profile is set up")
                    }
                    return
                }
                
                guard let teamId = appState.currentUser?.teamId else {
                    print("❌ CreateOperation: currentUser.teamId is nil")
                    print("   Current user: \(String(describing: appState.currentUser))")
                    await MainActor.run {
                        print("Your account is not assigned to a team. Contact your administrator.")
                    }
                    return
                }
                
                guard let agencyId = appState.currentUser?.agencyId else {
                    print("❌ CreateOperation: currentUser.agencyId is nil")
                    await MainActor.run {
                        print("Your account is not assigned to an agency. Contact your administrator.")
                    }
                    return
                }
                
                let op = try await OperationStore.shared.create(
                    name: name,
                    incidentNumber: incidentNumber.isEmpty ? nil : incidentNumber,
                    userId: userId,
                    teamId: teamId,
                    agencyId: agencyId,
                    targets: targets,
                    staging: staging,
                    isDraft: isDraft
                )
                
                // Add selected team members to the operation
                if !selectedMemberIds.isEmpty {
                    print("👥 Adding \(selectedMemberIds.count) member(s) to operation...")
                    do {
                        let addedCount = try await SupabaseRPCService.shared.addOperationMembers(
                            operationId: op.id,
                            memberIds: Array(selectedMemberIds)
                        )
                        print("✅ Successfully added \(addedCount) member(s)")
                    } catch {
                        print("⚠️ Failed to add members: \(error)")
                        // Continue anyway - operation was created successfully
                    }
                }
                
                await MainActor.run {
                    if isDraft {
                        print("📝 Draft saved successfully")
                        dismiss()
                    } else {
                        appState.activeOperationID = op.id
                        appState.activeOperation = op
                        dismiss()
                    }
                }
            } catch {
                print("Failed to create operation: \(error)")
            }
        }
    }
    
    private func saveDraft() {
        createOperation(isDraft: true)
    }

    private var disableNext: Bool {
        switch step {
        case .name: return name.trimmingCharacters(in: .whitespaces).isEmpty
        case .targets: return false   // allow zero targets
        case .staging: return false   // allow zero staging for now
        case .teamMembers: return false  // allow creating without adding members initially
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
}

// MARK: - Targets Editor

struct TargetsEditor: View {
    @Binding var targets: [OpTarget]
    @State private var kind: OpTargetKind = .person

    // Common
    @State private var notes = ""
    @State private var images: [OpTargetImage] = []  // Changed to image array
    @State private var currentTargetId = UUID()  // Track current target being edited
    @State private var editingTargetId: UUID?  // Track which target is being edited

    // Person (phone optional)
    @State private var firstName = ""
    @State private var lastName  = ""
    @State private var phone     = ""

    // Vehicle (all optional)
    @State private var make = ""
    @State private var model = ""
    @State private var color = ""
    @State private var plate = ""

    // Location (address with city/zip)
    @State private var locationLabel = ""
    @State private var address = ""
    @State private var city = ""
    @State private var zipCode = ""
    @State private var latitude: Double?
    @State private var longitude: Double?

    var body: some View {
        Form {
            Section("Target Type") {
                Picker("Type", selection: $kind) {
                    ForEach(OpTargetKind.allCases, id: \.self) {
                        Text($0.rawValue.capitalized).tag($0)
                    }
                }
                .pickerStyle(.segmented)
            }

            switch kind {
            case .person:
                Section {
                    Button {
                        add()
                    } label: {
                        HStack {
                            Image(systemName: editingTargetId == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                            Text(editingTargetId == nil ? "Add Target" : "Update Target")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .disabled(!canAddTarget)
                    .buttonStyle(.borderedProminent)
                    .tint(editingTargetId == nil ? .blue : .green)
                    
                    if editingTargetId != nil {
                        Button {
                            clearFields()
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Cancel Edit")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                
                Section("Person Details") {
                    TextField("First name", text: $firstName)
                    TextField("Last name", text: $lastName)
                    TextField("Phone (optional)", text: $phone)
                        .keyboardType(.phonePad)
                }
                
                Section {
                    if #available(iOS 16.0, *) {
                        TargetImagePicker(
                            images: $images,
                            targetId: currentTargetId
                        )
                    } else {
                        Text("Photo upload requires iOS 16+")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }

            case .vehicle:
                Section {
                    Button {
                        add()
                    } label: {
                        HStack {
                            Image(systemName: editingTargetId == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                            Text(editingTargetId == nil ? "Add Target" : "Update Target")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .disabled(!canAddTarget)
                    .buttonStyle(.borderedProminent)
                    .tint(editingTargetId == nil ? .blue : .green)
                    
                    if editingTargetId != nil {
                        Button {
                            clearFields()
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Cancel Edit")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                
                Section("Vehicle Details") {
                    TextField("Make (optional)", text: $make)
                    TextField("Model (optional)", text: $model)
                    TextField("Color (optional)", text: $color)
                    TextField("Plate (optional)", text: $plate)
                        .textInputAutocapitalization(.characters)
                }
                
                Section {
                    if #available(iOS 16.0, *) {
                        TargetImagePicker(
                            images: $images,
                            targetId: currentTargetId
                        )
                    } else {
                        Text("Photo upload requires iOS 16+")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }

            case .location:
                Section {
                    Button {
                        add()
                    } label: {
                        HStack {
                            Image(systemName: editingTargetId == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                            Text(editingTargetId == nil ? "Add Target" : "Update Target")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .disabled(!canAddTarget || latitude == nil || longitude == nil)
                    .buttonStyle(.borderedProminent)
                    .tint(editingTargetId == nil ? .blue : .green)
                    
                    if editingTargetId != nil {
                        Button {
                            clearFields()
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Cancel Edit")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                
                Section("Location Details") {
                    TextField("Label (e.g., 'Suspect's Home')", text: $locationLabel)
                    
                    AddressSearchField(
                        label: "Street Address",
                        address: $address,
                        city: $city,
                        zipCode: $zipCode,
                        latitude: $latitude,
                        longitude: $longitude
                    )
                    
                    TextField("City", text: $city)
                    TextField("ZIP Code", text: $zipCode)
                        .keyboardType(.numberPad)
                }
                
                Section {
                    if #available(iOS 16.0, *) {
                        TargetImagePicker(
                            images: $images,
                            targetId: currentTargetId
                        )
                    } else {
                        Text("Photo upload requires iOS 16+")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }

            Section("Additional Info") {
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            if !targets.isEmpty {
                Section("Added Targets (\(targets.count))") {
                    ForEach(targets) { t in
                        Button {
                            loadTargetForEditing(t)
                        } label: {
                            HStack {
                                Image(systemName: iconForKind(t.kind))
                                    .foregroundStyle(.blue)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.label)
                                        .foregroundStyle(.primary)
                                    
                                    if editingTargetId == t.id {
                                        Text("Editing...")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { 
                        deleteTargets(at: $0)
                    }
                }
            }
        }
    }
    
    private func iconForKind(_ kind: OpTargetKind) -> String {
        switch kind {
        case .person: return "person.fill"
        case .vehicle: return "car.fill"
        case .location: return "mappin.circle.fill"
        }
    }

    private var canAddTarget: Bool {
        switch kind {
        case .person:
            // Allow add if at least a name or photos exist
            return !(firstName.isEmpty && lastName.isEmpty && images.isEmpty)
        case .vehicle:
            // Add enabled if any field or photos are present
            return !(make.isEmpty && model.isEmpty && color.isEmpty && plate.isEmpty && images.isEmpty)
        case .location:
            return !address.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func add() {
        let label: String
        var target = OpTarget(
            id: UUID(),
            kind: kind,
            label: "",
            notes: notes.nilIfEmpty,
            personFirstName: nil,
            personLastName: nil,
            personPhone: nil,
            vehicleMake: nil,
            vehicleModel: nil,
            vehicleColor: nil,
            vehiclePlate: nil,
            locationLat: nil,
            locationLng: nil,
            locationName: nil,
            images: []
        )

        switch kind {
        case .person:
            label = personLabel(first: firstName, last: lastName)
            target.personFirstName = firstName.nilIfEmpty
            target.personLastName = lastName.nilIfEmpty
            target.personPhone = phone.nilIfEmpty

        case .vehicle:
            label = vehicleLabel(make: make, model: model, color: color, plate: plate)
            target.vehicleMake = make.nilIfEmpty
            target.vehicleModel = model.nilIfEmpty
            target.vehicleColor = color.nilIfEmpty
            target.vehiclePlate = plate.nilIfEmpty

        case .location:
            // Use custom label if provided, otherwise fallback to address
            if !locationLabel.trimmingCharacters(in: .whitespaces).isEmpty {
                label = locationLabel
            } else {
                let locationParts = [address, city, zipCode]
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                label = locationParts.isEmpty ? "Location" : locationParts.joined(separator: ", ")
            }
            target.locationName = label
            target.locationAddress = address
            target.locationLat = latitude
            target.locationLng = longitude
        }
        
        target.label = label
        
        // Add images (already uploaded by TargetImagePicker)
        target.images = images

        // If editing, update the existing target; otherwise append
        if let editingId = editingTargetId,
           let index = targets.firstIndex(where: { $0.id == editingId }) {
            targets[index] = target
            editingTargetId = nil  // Clear editing mode
            print("✏️ Updated target: \(target.label)")
        } else {
            targets.append(target)
            print("➕ Added new target: \(target.label)")
        }

        // reset quick fields
        clearFields()
    }
    
    private func loadTargetForEditing(_ target: OpTarget) {
        print("📝 Loading target for editing: \(target.label)")
        
        // Set editing mode
        editingTargetId = target.id
        currentTargetId = target.id
        
        // Set target type
        kind = target.kind
        
        // Load common fields
        notes = target.notes ?? ""
        images = target.images
        
        // Load type-specific fields
        switch target.kind {
        case .person:
            firstName = target.personFirstName ?? ""
            lastName = target.personLastName ?? ""
            phone = target.personPhone ?? ""
            
        case .vehicle:
            make = target.vehicleMake ?? ""
            model = target.vehicleModel ?? ""
            color = target.vehicleColor ?? ""
            plate = target.vehiclePlate ?? ""
            
        case .location:
            locationLabel = target.locationName ?? ""
            address = target.locationAddress ?? ""
            city = ""  // Not stored separately
            zipCode = ""  // Not stored separately
            latitude = target.locationLat
            longitude = target.locationLng
        }
        
        // Scroll to top to show the form
        print("✅ Target loaded for editing")
    }
    
    private func deleteTargets(at offsets: IndexSet) {
        // If deleting the target being edited, clear editing mode
        for index in offsets {
            if targets[index].id == editingTargetId {
                editingTargetId = nil
                clearFields()
            }
        }
        targets.remove(atOffsets: offsets)
    }
    
    private func clearFields() {
        notes = ""
        images = []
        currentTargetId = UUID()
        editingTargetId = nil
        firstName = ""; lastName = ""; phone = ""
        make = ""; model = ""; color = ""; plate = ""
        locationLabel = ""; address = ""; city = ""; zipCode = ""
        latitude = nil; longitude = nil
    }

    private func personLabel(first: String, last: String) -> String {
        let f = first.trimmingCharacters(in: .whitespaces)
        let l = last.trimmingCharacters(in: .whitespaces)
        if f.isEmpty && l.isEmpty { return "Person" }
        if f.isEmpty { return l }
        if l.isEmpty { return f }
        return "\(f) \(l)"
    }

    private func vehicleLabel(make: String, model: String, color: String, plate: String) -> String {
        let parts = [color, make, model, plate]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "Vehicle" : parts.joined(separator: " ")
    }
}

// MARK: - Staging editor (address, not lat/lng)

struct StagingEditor: View {
    @Binding var staging: [StagingPoint]
    @State private var label = ""
    @State private var address = ""
    @State private var city = ""
    @State private var zipCode = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var editingStagingId: UUID?

    var body: some View {
        Form {
            Section {
                Button {
                    addOrUpdate()
                } label: {
                    HStack {
                        Image(systemName: editingStagingId == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                        Text(editingStagingId == nil ? "Add Staging Point" : "Update Staging Point")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .disabled(!canAddStaging)
                .buttonStyle(.borderedProminent)
                .tint(editingStagingId == nil ? .blue : .green)
                
                if editingStagingId != nil {
                    Button {
                        clearFields()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Cancel Edit")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            
            Section(editingStagingId == nil ? "Staging Location" : "Edit Staging Location") {
                TextField("Label (e.g., 'North Parking')", text: $label)
                
                AddressSearchField(
                    label: "Street Address",
                    address: $address,
                    city: $city,
                    zipCode: $zipCode,
                    latitude: $latitude,
                    longitude: $longitude
                )
                
                TextField("City", text: $city)
                TextField("ZIP Code", text: $zipCode)
                    .keyboardType(.numberPad)
            }

            if !staging.isEmpty {
                Section("Added Staging Points (\(staging.count))") {
                    ForEach(staging) { s in
                        Button {
                            loadStagingForEditing(s)
                        } label: {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(.blue)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.label)
                                        .foregroundStyle(.primary)
                                    
                                    if editingStagingId == s.id {
                                        Text("Editing...")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { 
                        staging.remove(atOffsets: $0)
                        // Clear editing state if deleted item was being edited
                        if let editingId = editingStagingId,
                           !staging.contains(where: { $0.id == editingId }) {
                            clearFields()
                        }
                    }
                }
            }
        }
    }
    
    private var canAddStaging: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty &&
        !address.trimmingCharacters(in: .whitespaces).isEmpty &&
        latitude != nil && longitude != nil
    }
    
    private func addOrUpdate() {
        let fullAddress = [address, city, zipCode]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        
        let newStaging = StagingPoint(
            id: editingStagingId ?? UUID(),
            label: label.isEmpty ? "Staging" : label,
            address: fullAddress.isEmpty ? address : fullAddress,
            lat: latitude,
            lng: longitude
        )
        
        if let editingId = editingStagingId,
           let index = staging.firstIndex(where: { $0.id == editingId }) {
            // Update existing
            staging[index] = newStaging
        } else {
            // Add new
            staging.append(newStaging)
        }
        
        clearFields()
    }
    
    private func loadStagingForEditing(_ stagingPoint: StagingPoint) {
        print("📝 Loading staging point for editing: \(stagingPoint.label)")
        
        editingStagingId = stagingPoint.id
        label = stagingPoint.label
        latitude = stagingPoint.lat
        longitude = stagingPoint.lng
        
        // Check if address is empty (from old templates)
        if stagingPoint.address.trimmingCharacters(in: .whitespaces).isEmpty {
            print("   ⚠️ Staging point has no address - old template or coordinates-only")
            // Leave fields empty - user will need to add address manually
            address = ""
            city = ""
            zipCode = ""
            return
        }
        
        // Parse address into components (format: "street, city, zip")
        let components = stagingPoint.address.components(separatedBy: ", ")
        if components.count >= 3 {
            // Full format: "street, city, zip"
            address = components.dropLast(2).joined(separator: ", ")
            city = components[components.count - 2]
            zipCode = components.last ?? ""
        } else if components.count == 2 {
            // Two parts: could be "street, city" or "street, zip"
            address = components.first ?? ""
            // Try to determine if second part is zip (numeric) or city
            let secondPart = components.last ?? ""
            if secondPart.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil {
                // Looks like a zip code
                city = ""
                zipCode = secondPart
            } else {
                // Probably a city
                city = secondPart
                zipCode = ""
            }
        } else {
            // Single component - use as street address
            address = stagingPoint.address
            city = ""
            zipCode = ""
        }
        
        print("   Parsed - Street: '\(address)', City: '\(city)', Zip: '\(zipCode)'")
    }
    
    private func clearFields() {
        editingStagingId = nil
        label = ""
        address = ""
        city = ""
        zipCode = ""
        latitude = nil
        longitude = nil
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let step: CreateOperationView.Step
    
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
                ForEach([CreateOperationView.Step.name, .targets, .staging, .teamMembers, .review], id: \.self) { s in
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
    
    private var stepIndex: Int {
        switch step {
        case .name: return 1
        case .targets: return 2
        case .staging: return 3
        case .teamMembers: return 4
        case .review: return 5
        }
    }
}

extension CreateOperationView.Step: Comparable {
    var rawValue: Int {
        switch self {
        case .name: return 0
        case .targets: return 1
        case .staging: return 2
        case .teamMembers: return 3
        case .review: return 4
        }
    }
    
    static func < (lhs: CreateOperationView.Step, rhs: CreateOperationView.Step) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Review Card

struct ReviewCard: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 16) {
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

// MARK: - Team Member Selector

struct TeamMemberSelector: View {
    @Binding var selectedMemberIds: Set<UUID>
    @EnvironmentObject var appState: AppState
    
    @State private var teamMembers: [TeamMember] = []
    @State private var isLoading = false
    
    var body: some View {
        Form {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue.gradient)
                    
                    VStack(spacing: 8) {
                        Text("Select Team Members")
                            .font(.title3.bold())
                        
                        Text("Choose who to add to this operation")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            .listRowBackground(Color.clear)
            
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if teamMembers.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        
                        Text("No other team members")
                            .font(.subheadline.weight(.medium))
                        
                        Text("You're the only member of your team. You can still create the operation and add members later.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                Section {
                    ForEach(teamMembers) { member in
                        TeamMemberRow(
                            member: member,
                            isSelected: selectedMemberIds.contains(member.id),
                            isInOperation: member.inOperation,
                            onToggle: {
                                if member.inOperation {
                                    // Can't select someone already in an operation
                                    return
                                }
                                if selectedMemberIds.contains(member.id) {
                                    selectedMemberIds.remove(member.id)
                                } else {
                                    selectedMemberIds.insert(member.id)
                                }
                            }
                        )
                    }
                } header: {
                    Text("Team Roster")
                } footer: {
                    Text("Members grayed out are already in another active operation")
                        .font(.caption)
                }
            }
            
            if !selectedMemberIds.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("\(selectedMemberIds.count) member\(selectedMemberIds.count == 1 ? "" : "s") selected")
                            .font(.subheadline)
                    }
                }
            }
        }
        .task {
            await loadTeamMembers()
        }
    }
    
    private func loadTeamMembers() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            print("📥 Loading team roster...")
            let members = try await SupabaseRPCService.shared.getTeamRoster()
            print("✅ Loaded \(members.count) team members")
            
            // Filter out current user (they're already the case agent)
            let currentUserId = appState.currentUserID
            let filteredMembers = members.filter { $0.id != currentUserId }
            print("   Filtered to \(filteredMembers.count) members (excluding current user)")
            
            await MainActor.run {
                self.teamMembers = filteredMembers
            }
        } catch {
            print("❌ Failed to load team members: \(error)")
        }
    }
}

struct TeamMemberRow: View {
    let member: TeamMember
    let isSelected: Bool
    let isInOperation: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(isInOperation ? Color.gray.opacity(0.3) : Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(member.fullName.prefix(1))
                            .font(.headline)
                            .foregroundStyle(isInOperation ? .gray : .blue)
                    }
                
                // Name and role
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.fullName)
                        .font(.body)
                        .foregroundStyle(isInOperation ? .secondary : .primary)
                    
                    Text(member.callsign ?? member.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                if isInOperation {
                    Text("In Operation")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.gray.opacity(0.2))
                        .foregroundStyle(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                } else {
                    Image(systemName: "circle")
                        .font(.title3)
                        .foregroundStyle(.gray.opacity(0.3))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isInOperation)
        .opacity(isInOperation ? 0.6 : 1.0)
    }
}

// MARK: - Utils

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
