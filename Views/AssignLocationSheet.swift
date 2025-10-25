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
        NavigationView {
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
                    Picker("Team Member", selection: $selectedUserId) {
                        Text("Select member...").tag(nil as UUID?)
                        ForEach(teamMembers) { member in
                            HStack {
                                if let callsign = member.callsign {
                                    Text("[\(callsign)]")
                                        .fontWeight(.semibold)
                                }
                                Text(member.fullName ?? "Unknown")
                            }
                            .tag(member.id as UUID?)
                        }
                    }
                    .pickerStyle(.navigationLink)
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
                toUserId: userId,
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
                email: "test@example.com",
                teamId: UUID(),
                agencyId: UUID(),
                fullName: "John Doe",
                callsign: "ALPHA-1",
                vehicleType: "sedan",
                vehicleColor: "black"
            )
        ]
    )
}

