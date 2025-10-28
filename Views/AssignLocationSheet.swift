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
    @State private var address: String = "Loading address..."
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(address)
                                .font(.subheadline)
                            Text("\(coordinate.latitude, specifier: "%.6f"), \(coordinate.longitude, specifier: "%.6f")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                                memberRow(for: member)
                                    .tag(member.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Section("Details") {
                    TextField("Label (e.g., 'North Entry', 'OP-1')", text: $label)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                    
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .autocorrectionDisabled()
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
                    print("     - ID: \(member.id)")
                    print("       Callsign: '\(member.callsign ?? "nil")'")
                    print("       Email: '\(member.email)'")
                    print("       VehicleType: \(member.vehicleType)")
                }
                
                // Fetch address
                Task {
                    await fetchAddress()
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
            _ = try await AssignmentService.shared.assignLocation(
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
    
    // MARK: - Helper Functions
    
    @ViewBuilder
    private func memberRow(for member: User) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: member.vehicleColor) ?? .gray)
                .frame(width: 12, height: 12)
            
            if let callsign = member.callsign, !callsign.isEmpty {
                Text("\(callsign) (\(member.vehicleType.displayName))")
            } else if !member.email.isEmpty {
                Text("\(member.email) (\(member.vehicleType.displayName))")
            } else {
                Text("User \(member.id.uuidString.prefix(8)) (\(member.vehicleType.displayName))")
            }
        }
    }
    
    private func fetchAddress() async {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            
            if let placemark = placemarks.first {
                var components: [String] = []
                
                if let streetNumber = placemark.subThoroughfare {
                    components.append(streetNumber)
                }
                if let street = placemark.thoroughfare {
                    components.append(street)
                }
                
                let firstLine = components.joined(separator: " ")
                
                var secondLineComponents: [String] = []
                if let city = placemark.locality {
                    secondLineComponents.append(city)
                }
                if let state = placemark.administrativeArea {
                    secondLineComponents.append(state)
                }
                
                let secondLine = secondLineComponents.joined(separator: ", ")
                
                if !firstLine.isEmpty && !secondLine.isEmpty {
                    address = "\(firstLine), \(secondLine)"
                } else if !firstLine.isEmpty {
                    address = firstLine
                } else if !secondLine.isEmpty {
                    address = secondLine
                } else {
                    address = "Address not available"
                }
                
                print("📍 Geocoded address: \(address)")
            } else {
                address = "Address not available"
            }
        } catch {
            print("❌ Geocoding error: \(error)")
            address = "Address not available"
        }
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
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

