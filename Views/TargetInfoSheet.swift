//
//  TargetInfoSheet.swift
//  Survale
//
//  Map info sheet for displaying target details
//

import SwiftUI

struct TargetInfoSheet: View {
    let target: OpTarget
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with icon
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(target.status.color.opacity(0.2))
                                .frame(width: 70, height: 70)
                            Image(systemName: iconForKind)
                                .font(.system(size: 35))
                                .foregroundStyle(target.status.color)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(target.label)
                                .font(.title2.bold())
                            HStack(spacing: 8) {
                                Text(kindLabel)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                // Status badge
                                Text(target.status.displayName)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(target.status.color.opacity(0.2))
                                    .foregroundStyle(target.status.color)
                                    .cornerRadius(6)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    // Details based on kind
                    switch target.kind {
                    case .person:
                        if let firstName = target.personFirstName, let lastName = target.personLastName {
                            InfoDetailRow(label: "Name", value: "\(firstName) \(lastName)")
                        }
                        if let phone = target.personPhone {
                            InfoDetailRow(label: "Phone", value: phone, isLink: true, linkURL: "tel:\(phone.filter { $0.isNumber })")
                        }
                        
                    case .vehicle:
                        if let make = target.vehicleMake {
                            InfoDetailRow(label: "Make", value: make)
                        }
                        if let model = target.vehicleModel {
                            InfoDetailRow(label: "Model", value: model)
                        }
                        if let color = target.vehicleColor {
                            InfoDetailRow(label: "Color", value: color)
                        }
                        if let plate = target.vehiclePlate {
                            InfoDetailRow(label: "License Plate", value: plate)
                        }
                        
                    case .location:
                        if let name = target.locationName {
                            InfoDetailRow(label: "Location Name", value: name)
                        }
                        if let address = target.locationAddress {
                            InfoDetailRow(label: "Address", value: address)
                        }
                    }
                    
                    // Location coordinates
                    if let lat = target.locationLat, let lng = target.locationLng {
                        InfoDetailRow(label: "Coordinates", value: String(format: "%.6f, %.6f", lat, lng))
                        
                        // Navigate button
                        if let url = URL(string: "maps://?daddr=\(lat),\(lng)") {
                            Link(destination: url) {
                                HStack {
                                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                    Text("Navigate Here")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .cornerRadius(10)
                            }
                        }
                    }
                    
                    // Notes
                    if let notes = target.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            Text(notes)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(8)
                        }
                    }
                    
                    // Images
                    if !target.images.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Photos (\(target.images.count))")
                                .font(.headline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(target.images) { image in
                                        if let localPath = image.localPath,
                                           let uiImage = OpTargetImageManager.shared.loadImage(atRelativePath: localPath) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 150, height: 150)
                                                .cornerRadius(8)
                                                .clipped()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Target Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var iconForKind: String {
        switch target.kind {
        case .person: return "person.fill"
        case .vehicle: return "car.fill"
        case .location: return "mappin.circle.fill"
        }
    }
    
    private var kindLabel: String {
        target.kind.rawValue.capitalized
    }
    
    private var colorForKind: Color {
        switch target.kind {
        case .person: return .green
        case .vehicle: return .orange
        case .location: return .red
        }
    }
}

