//
//  SaveAsTemplateView.swift
//  Survale
//
//  Created by Assistant on 10/27/25.
//

import SwiftUI

struct SaveAsTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    let operation: Operation
    let targets: [OpTarget]
    let staging: [StagingPoint]
    
    @State private var templateName: String
    @State private var templateDescription = ""
    @State private var isPublic = false
    @State private var isSaving = false
    @State private var showingSuccess = false
    
    init(operation: Operation, targets: [OpTarget], staging: [StagingPoint]) {
        self.operation = operation
        self.targets = targets
        self.staging = staging
        _templateName = State(initialValue: operation.name + " Template")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Template Information") {
                    TextField("Template Name", text: $templateName)
                    
                    TextField("Description (optional)", text: $templateDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Toggle(isOn: $isPublic) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Share with Agency")
                                .font(.body)
                            
                            Text(isPublic ? "All users in your agency can use this template" : "Only you can use this template")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Template Contents") {
                    HStack {
                        Label("\(targets.count)", systemImage: "person.2")
                        Spacer()
                        Text("Target\(targets.count == 1 ? "" : "s")")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Label("\(staging.count)", systemImage: "mappin.circle")
                        Spacer()
                        Text("Staging Point\(staging.count == 1 ? "" : "s")")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Save as Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        print("🔘 Save button tapped")
                        print("   Template name: '\(templateName)'")
                        print("   Is saving: \(isSaving)")
                        print("   Button disabled: \(templateName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)")
                        saveTemplate()
                    }
                    .disabled(templateName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .disabled(isSaving)
            .alert("Template Saved", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("'\(templateName)' has been saved and can be used when creating new operations.")
            }
        }
    }
    
    private func saveTemplate() {
        print("📝 saveTemplate() called")
        print("   isSaving before: \(isSaving)")
        isSaving = true
        print("   isSaving after: \(isSaving)")
        
        Task {
            do {
                print("   Checking user context...")
                print("   currentUserID: \(appState.currentUserID?.uuidString ?? "nil")")
                print("   teamId: \(appState.currentUser?.teamId.uuidString ?? "nil")")
                print("   agencyId: \(appState.currentUser?.agencyId.uuidString ?? "nil")")
                
                guard let userId = appState.currentUserID,
                      let teamId = appState.currentUser?.teamId,
                      let agencyId = appState.currentUser?.agencyId else {
                    print("❌ Missing user context")
                    await MainActor.run {
                        isSaving = false
                    }
                    return
                }
                
                print("📋 Saving template: \(templateName)")
                print("   Public: \(isPublic)")
                print("   Targets: \(targets.count)")
                print("   Staging: \(staging.count)")
                
                let templateId = try await SupabaseRPCService.shared.saveOperationAsTemplate(
                    name: templateName,
                    description: templateDescription.isEmpty ? nil : templateDescription,
                    isPublic: isPublic,
                    targets: targets,
                    staging: staging
                )
                
                print("✅ Template saved with ID: \(templateId)")
                
                await MainActor.run {
                    isSaving = false
                    showingSuccess = true
                }
            } catch {
                print("❌ Failed to save template: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    SaveAsTemplateView(
        operation: Operation(
            id: UUID(),
            name: "Test Operation",
            incidentNumber: "123",
            state: .active,
            createdAt: Date(),
            startsAt: Date(),
            endsAt: nil,
            createdByUserId: UUID(),
            teamId: UUID(),
            agencyId: UUID()
        ),
        targets: [],
        staging: []
    )
    .environmentObject(AppState())
}

