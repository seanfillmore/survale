import SwiftUI
import MapKit

struct AssignLocationSheet: View {
    let coordinate: CLLocationCoordinate2D
    let operationId: UUID
    let teamMembers: [User]
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedUserId: UUID?
    @State private var label = ""
    @State private var notes = ""
    @State private var isAssigning = false
    @State private var error: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Latitude: \(coordinate.latitude, specifier: "%.6f")")
                                .font(.subheadline)
                            Text("Longitude: \(coordinate.longitude, specifier: "%.6f")")
                                .font(.subheadline)
                        }
                    }
                }
                
                Section("Assign To") {
                    if teamMembers.isEmpty {
                        Text("No team members available")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    } else {
                        Picker("Team Member", selection: $selectedUserId) {
                            Text("Select member...").tag(nil as UUID?)
                            ForEach(teamMembers) { member in
                                HStack {
                                    if let callsign = member.callsign {
                                        Text("[\(callsign)]")
                                            .fontWeight(.semibold)
                                    }
                                    Text(member.email)
                                }
                                .tag(member.id as UUID?)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }
                
                Section("Details") {
                    TextField("Label (e.g., 'North Entry', 'OP-1')", text: $label)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
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
                            await assignLocation()
                        }
                    } label: {
                        HStack {
                            if isAssigning {
                                ProgressView()
                            } else {
                                Image(systemName: "mappin.circle.fill")
                                Text("Assign Location")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(selectedUserId == nil || isAssigning || label.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Assign Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                print("📍 AssignLocationSheet appeared")
                print("   Operation ID: \(operationId)")
                print("   Coordinate: \(coordinate.latitude), \(coordinate.longitude)")
                print("   Team members: \(teamMembers.count)")
                for member in teamMembers {
                    print("     - \(member.callsign ?? "no callsign") (\(member.email))")
                }
            }
        }
    }
    
    private func assignLocation() async {
        guard let userId = selectedUserId else { return }
        guard !label.isEmpty else {
            error = "Please enter a label for this location"
            return
        }
        
        isAssigning = true
        error = nil
        
        do {
            try await AssignmentService.shared.assignLocation(
                operationId: operationId,
                assignedToUserId: userId,
                coordinate: coordinate,
                label: label,
                notes: notes.isEmpty ? nil : notes
            )
            
            print("✅ Location assigned successfully")
            dismiss()
        } catch {
            self.error = "Failed to assign location: \(error.localizedDescription)"
            print("❌ Error assigning location: \(error)")
        }
        
        isAssigning = false
    }
}

// MARK: - Preview Helper

#Preview {
    AssignLocationSheet(
        coordinate: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
        operationId: UUID(),
        teamMembers: [
            User(
                id: UUID(),
                email: "john.doe@agency.gov",
                teamId: UUID(),
                agencyId: UUID(),
                callsign: "ALPHA-1",
                vehicleType: .sedan,
                vehicleColor: "#000000"
            )
        ]
    )
}

