//
//  ChatExportFilterView.swift
//  Survale
//
//  Filter options for chat export
//

import SwiftUI

struct ChatExportFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    let operation: Operation
    let members: [User]
    let onExport: (ChatExportFilters) -> Void
    
    // Filter state
    @State private var filterByDate = false
    @State private var startDate: Date
    @State private var endDate = Date()
    
    @State private var filterByMembers = false
    @State private var selectedMemberIds: Set<UUID> = []
    
    init(operation: Operation, members: [User], onExport: @escaping (ChatExportFilters) -> Void) {
        self.operation = operation
        self.members = members
        self.onExport = onExport
        
        // Default start date to operation creation
        _startDate = State(initialValue: operation.createdAt)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Summary Section
                Section {
                    HStack {
                        Text("Operation")
                        Spacer()
                        Text(operation.name)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Incident #")
                        Spacer()
                        Text(operation.incidentNumber ?? "N/A")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Operation Details")
                }
                
                // Date Filter Section
                Section {
                    Toggle("Filter by Date/Time", isOn: $filterByDate)
                    
                    if filterByDate {
                        DatePicker(
                            "From",
                            selection: $startDate,
                            in: operation.createdAt...endDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        
                        DatePicker(
                            "To",
                            selection: $endDate,
                            in: startDate...(operation.endsAt ?? Date()),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                } header: {
                    Text("Time Range")
                } footer: {
                    if filterByDate {
                        Text("Only messages sent between these dates/times will be included")
                    }
                }
                
                // Member Filter Section
                Section {
                    Toggle("Filter by Members", isOn: $filterByMembers)
                    
                    if filterByMembers {
                        ForEach(members) { member in
                            Button {
                                toggleMember(member.id)
                            } label: {
                                HStack {
                                    Image(systemName: selectedMemberIds.contains(member.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedMemberIds.contains(member.id) ? .blue : .gray)
                                    
                                    VStack(alignment: .leading) {
                                        Text(member.fullName ?? member.email)
                                            .foregroundStyle(.primary)
                                        
                                        if let callsign = member.callsign {
                                            Text(callsign)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        
                        if !selectedMemberIds.isEmpty {
                            Button("Clear Selection") {
                                selectedMemberIds.removeAll()
                            }
                            .foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("Members")
                } footer: {
                    if filterByMembers {
                        if selectedMemberIds.isEmpty {
                            Text("Select at least one member to filter")
                        } else {
                            Text("\(selectedMemberIds.count) member(s) selected")
                        }
                    } else {
                        Text("All messages from all members will be included")
                    }
                }
                
                // Export Preview Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(.blue)
                            Text("Export will include:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        Label("PDF report with chat transcript", systemImage: "doc.richtext")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Label("Media files (photos & videos) in separate folder", systemImage: "photo.stack")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Label("Operation details and participant list", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Export Contents")
                }
            }
            .navigationTitle("Export Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") {
                        exportWithFilters()
                    }
                    .disabled(!canExport)
                }
            }
        }
    }
    
    private var canExport: Bool {
        // If filtering by members, must have at least one selected
        if filterByMembers && selectedMemberIds.isEmpty {
            return false
        }
        return true
    }
    
    private func toggleMember(_ id: UUID) {
        if selectedMemberIds.contains(id) {
            selectedMemberIds.remove(id)
        } else {
            selectedMemberIds.insert(id)
        }
    }
    
    private func exportWithFilters() {
        let filters = ChatExportFilters(
            startDate: filterByDate ? startDate : nil,
            endDate: filterByDate ? endDate : nil,
            selectedMemberIds: filterByMembers ? selectedMemberIds : nil
        )
        
        onExport(filters)
        dismiss()
    }
}

