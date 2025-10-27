//
//  StagingPointEditorView.swift
//  Survale
//
//  Created by Assistant on 10/27/25.
//

import SwiftUI

struct StagingPointEditorView: View {
    @Binding var stagingPoint: StagingPoint
    @Environment(\.dismiss) private var dismiss
    
    @State private var label: String
    @State private var address: String
    @State private var city: String
    @State private var zipCode: String
    @State private var latitude: Double?
    @State private var longitude: Double?
    
    init(stagingPoint: Binding<StagingPoint>) {
        self._stagingPoint = stagingPoint
        
        // Initialize state from the staging point
        let point = stagingPoint.wrappedValue
        _label = State(initialValue: point.label)
        _address = State(initialValue: point.address)
        _latitude = State(initialValue: point.lat)
        _longitude = State(initialValue: point.lng)
        
        // Try to parse city and zip from address
        let components = point.address.components(separatedBy: ", ")
        _city = State(initialValue: components.count >= 2 ? components[components.count - 2] : "")
        _zipCode = State(initialValue: components.count >= 1 ? (components.last ?? "") : "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Location Details") {
                    TextField("Label (e.g., 'North Parking')", text: $label)
                        .textInputAutocapitalization(.words)
                }
                
                Section("Address") {
                    AddressSearchField(
                        label: "Street Address",
                        address: $address,
                        city: $city,
                        zipCode: $zipCode,
                        latitude: $latitude,
                        longitude: $longitude
                    )
                    
                    TextField("City", text: $city)
                        .textInputAutocapitalization(.words)
                    
                    TextField("ZIP Code", text: $zipCode)
                        .keyboardType(.numberPad)
                }
                
                if let lat = latitude, let lng = longitude {
                    Section("Coordinates") {
                        HStack {
                            Text("Latitude")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.6f", lat))
                                .font(.system(.body, design: .monospaced))
                        }
                        HStack {
                            Text("Longitude")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.6f", lng))
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
            }
            .navigationTitle("Edit Staging Point")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty &&
        !address.trimmingCharacters(in: .whitespaces).isEmpty &&
        latitude != nil &&
        longitude != nil
    }
    
    private func saveChanges() {
        let fullAddress = [address, city, zipCode]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        
        stagingPoint = StagingPoint(
            id: stagingPoint.id,
            label: label.trimmingCharacters(in: .whitespaces),
            address: fullAddress.isEmpty ? address : fullAddress,
            lat: latitude,
            lng: longitude
        )
    }
}

#Preview {
    @Previewable @State var staging = StagingPoint(
        id: UUID(),
        label: "North Parking",
        address: "123 Main St, Springfield, 12345",
        lat: 34.0522,
        lng: -118.2437
    )
    
    StagingPointEditorView(stagingPoint: $staging)
}

