//
//  TemplatePickerView.swift
//  Survale
//
//  Created by Assistant on 10/27/25.
//

import SwiftUI

struct TemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    let onSelect: (OperationTemplate) -> Void
    
    @State private var templates: [OperationTemplate] = []
    @State private var isLoading = false
    @State private var selectedScope: TemplateScope = .mine
    
    enum TemplateScope: String, CaseIterable {
        case mine = "My Templates"
        case agency = "Agency Templates"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Scope Picker
                Picker("Scope", selection: $selectedScope) {
                    ForEach(TemplateScope.allCases, id: \.self) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if templates.isEmpty {
                    EmptyTemplatesView(scope: selectedScope)
                } else {
                    List(templates) { template in
                        TemplateRow(template: template) {
                            onSelect(template)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Choose Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadTemplates()
            }
            .onChange(of: selectedScope) { _, _ in
                Task {
                    await loadTemplates()
                }
            }
        }
    }
    
    private func loadTemplates() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // TODO: Load templates from SupabaseRPCService
            print("📋 Loading \(selectedScope.rawValue)...")
            templates = []
        } catch {
            print("❌ Failed to load templates: \(error)")
        }
    }
}

// MARK: - Template Row

struct TemplateRow: View {
    let template: OperationTemplate
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "doc.on.doc")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    if let description = template.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 12) {
                        if !template.targets.isEmpty {
                            Label("\(template.targets.count)", systemImage: "person.2")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        if !template.staging.isEmpty {
                            Label("\(template.staging.count)", systemImage: "mappin.circle")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        if template.isPublic {
                            Label("Agency", systemImage: "building.2")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

struct EmptyTemplatesView: View {
    let scope: TemplatePickerView.TemplateScope
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.ellipsis")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text(scope == .mine ? "No Personal Templates" : "No Agency Templates")
                .font(.headline)
            
            Text(scope == .mine ? 
                 "Save an operation as a template to reuse it later" :
                 "No public templates have been shared by your agency")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    TemplatePickerView { _ in }
        .environmentObject(AppState())
}

