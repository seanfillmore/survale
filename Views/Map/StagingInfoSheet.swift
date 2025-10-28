//
//  StagingInfoSheet.swift
//  Survale
//
//  Map info sheet for displaying staging point details
//

import SwiftUI

struct StagingInfoSheet: View {
    let staging: StagingPoint
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack(spacing: 16) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(staging.label)
                                .font(.title2.bold())
                            Text("Staging Point")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    // Address
                    if !staging.address.isEmpty {
                        InfoDetailRow(label: "Address", value: staging.address)
                    }
                    
                    // Coordinates
                    if let lat = staging.lat, let lng = staging.lng {
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
                                .background(Color.green)
                                .foregroundStyle(.white)
                                .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Staging Point")
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
}

