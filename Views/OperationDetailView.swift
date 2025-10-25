import SwiftUI

struct OperationDetailView: View {
    let operation: Operation
    
    @State private var targets: [OpTarget] = []
    @State private var staging: [StagingPoint] = []
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue.gradient)
                    
                    Text(operation.name)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                    
                    if let incidentNumber = operation.incidentNumber {
                        Text("Incident / Case Number: \(incidentNumber)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Text("Started")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let startedAt = operation.startsAt {
                                Text(startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                            } else {
                                Text("N/A")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Divider()
                            .frame(height: 30)
                        
                        VStack(spacing: 4) {
                            Text("Ended")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let endedAt = operation.endsAt {
                                Text(endedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                            } else {
                                Text("N/A")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .padding()
                
                // Targets Section
                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    if !targets.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Targets")
                                .font(.title2.bold())
                                .padding(.horizontal)
                            
                            ForEach(targets) { target in
                                TargetCard(target: target)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Staging Points Section
                    if !staging.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Staging Points")
                                .font(.title2.bold())
                                .padding(.horizontal)
                            
                            ForEach(staging) { stage in
                                StagingCard(staging: stage)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    
                    if targets.isEmpty && staging.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            
                            Text("No targets or staging points")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                
                Spacer()
            }
        }
        .navigationTitle("Operation Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadOperationData()
        }
    }
    
    private func loadOperationData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let data = try await SupabaseRPCService.shared.getOperationTargets(operationId: operation.id)
            
            await MainActor.run {
                self.targets = data.targets
                self.staging = data.staging
            }
        } catch {
            print("❌ Failed to load operation data: \(error)")
        }
    }
}

// MARK: - Target Card

private struct TargetCard: View {
    let target: OpTarget
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconForKind)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(target.label)
                        .font(.headline)
                    
                    Text(kindLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Details based on kind
            VStack(alignment: .leading, spacing: 8) {
                switch target.kind {
                case .person:
                    if let phone = target.phone {
                        DetailRow(label: "Phone", value: phone)
                    }
                    
                case .vehicle:
                    if let make = target.vehicleMake, let model = target.vehicleModel {
                        DetailRow(label: "Vehicle", value: "\(make) \(model)")
                    }
                    if let color = target.vehicleColor {
                        DetailRow(label: "Color", value: color)
                    }
                    if let plate = target.licensePlate {
                        DetailRow(label: "Plate", value: plate)
                    }
                    
                case .location:
                    if let address = target.locationAddress {
                        DetailRow(label: "Address", value: address)
                    }
                    if let lat = target.locationLat, let lng = target.locationLng {
                        DetailRow(label: "Coordinates", value: String(format: "%.6f, %.6f", lat, lng))
                    }
                }
            }
            .padding(.leading, 40)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var iconForKind: String {
        switch target.kind {
        case .person: return "person.fill"
        case .vehicle: return "car.fill"
        case .location: return "mappin.circle.fill"
        }
    }
    
    private var kindLabel: String {
        switch target.kind {
        case .person: return "Person"
        case .vehicle: return "Vehicle"
        case .location: return "Location"
        }
    }
}

// MARK: - Staging Card

private struct StagingCard: View {
    let staging: StagingPoint
    
    var body: some View {
        HStack {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(staging.label)
                    .font(.headline)
                
                if !staging.address.isEmpty {
                    Text(staging.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let lat = staging.lat, let lng = staging.lng {
                    Text(String(format: "%.6f, %.6f", lat, lng))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.caption)
        }
    }
}

