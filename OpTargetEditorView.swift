//
//  OpTargetEditorView.swift
//  Survale
//
//  Created by You on 10/18/25.
//

import SwiftUI
import CoreLocation

struct OpTargetEditorView: View {
    @Binding var target: OpTarget

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Label (e.g. Blue Honda Civic)", text: $target.label)
                    .textInputAutocapitalization(.words)

                TextField("Notes", text: Binding(
                    get: { target.notes ?? "" },
                    set: { target.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(3, reservesSpace: true)
            }

            Section("Details") {
                Picker("Kind", selection: $target.kind) {
                    ForEach(OpTargetKind.allCases, id: \.self) { kind in
                        Text(kindDisplay(kind)).tag(kind)
                    }
                }

                switch target.kind {
                case .person:
                    TextField("First name", text: Binding(get: { target.personFirstName ?? "" },
                                                          set: { target.personFirstName = $0.isEmpty ? nil : $0 }))
                    TextField("Last name", text: Binding(get: { target.personLastName ?? "" },
                                                         set: { target.personLastName = $0.isEmpty ? nil : $0 }))
                    TextField("Phone", text: Binding(get: { target.personPhone ?? "" },
                                                     set: { target.personPhone = $0.isEmpty ? nil : $0 }))
                    .keyboardType(.phonePad)

                case .vehicle:
                    TextField("Make", text: Binding(get: { target.vehicleMake ?? "" },
                                                    set: { target.vehicleMake = $0.isEmpty ? nil : $0 }))
                    TextField("Model", text: Binding(get: { target.vehicleModel ?? "" },
                                                     set: { target.vehicleModel = $0.isEmpty ? nil : $0 }))
                    TextField("Color", text: Binding(get: { target.vehicleColor ?? "" },
                                                     set: { target.vehicleColor = $0.isEmpty ? nil : $0 }))
                    TextField("Plate", text: Binding(get: { target.vehiclePlate ?? "" },
                                                     set: { target.vehiclePlate = $0.isEmpty ? nil : $0 }))
                    .textInputAutocapitalization(.characters)

                case .location:
                    TextField("Location name", text: Binding(get: { target.locationName ?? "" },
                                                             set: { target.locationName = $0.isEmpty ? nil : $0 }))
                    HStack {
                        TextField("Latitude", value: $target.locationLat, format: .number)
                            .keyboardType(.numbersAndPunctuation)
                        TextField("Longitude", value: $target.locationLng, format: .number)
                            .keyboardType(.numbersAndPunctuation)
                    }
                }
            }

            Section {
                OpTargetGalleryView(target: $target)
            }
        }
        .navigationTitle(target.label.isEmpty ? "New Target" : target.label)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func kindDisplay(_ k: OpTargetKind) -> String {
        switch k {
        case .person: return "Person"
        case .vehicle: return "Vehicle"
        case .location: return "Location"
        }
    }
}

#Preview("Editor Preview") {
    struct Host: View {
        @State var t = OpTarget(
            id: UUID(),
            kind: .vehicle,
            label: "Blue Honda Civic",
            notes: "Seen near Warehouse B",
            personFirstName: nil,
            personLastName: nil,
            personPhone: nil,
            vehicleMake: "Honda",
            vehicleModel: "Civic",
            vehicleColor: "Blue",
            vehiclePlate: "8XYZ123",
            locationLat: 37.7749,
            locationLng: -122.4194,
            locationName: "Warehouse B",
            images: []
        )
        var body: some View {
            NavigationStack { OpTargetEditorView(target: $t) }
        }
    }
    return Host()
}
