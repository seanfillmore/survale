//
//  TeamMemberInfoSheet.swift
//  Survale
//
//  Map info sheet for displaying team member details and assignments
//

import SwiftUI

struct TeamMemberInfoSheet: View {
    let member: User
    let assignmentService: AssignmentService
    let routeService: RouteService
    let operationId: UUID?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with avatar
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.blue.gradient)
                            .frame(width: 60, height: 60)
                            .overlay {
                                Text(initials)
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                            }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.fullName ?? member.email)
                                .font(.title2.bold())
                            if let callsign = member.callsign {
                                Text(callsign)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    // Contact info
                    if let phone = member.phoneNumber, !phone.isEmpty {
                        InfoDetailRow(label: "Phone", value: phone, isLink: true, linkURL: "tel:\(phone.filter { $0.isNumber })")
                    }
                    
                    InfoDetailRow(label: "Email", value: member.email, isLink: true, linkURL: "mailto:\(member.email)")
                    
                    // Vehicle info
                    InfoDetailRow(label: "Vehicle", value: "\(member.vehicleColor) \(member.vehicleType.displayName)")
                    
                    // Assignment info
                    if let assignment = memberAssignment {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Current Assignment")
                                .font(.headline)
                            
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: assignment.status.icon)
                                        .foregroundStyle(assignment.status.color)
                                    Text(assignment.status.rawValue.capitalized)
                                        .font(.subheadline)
                                    Spacer()
                                }
                                
                                if let label = assignment.label {
                                    HStack {
                                        Text("Location:")
                                            .foregroundStyle(.secondary)
                                        Text(label)
                                        Spacer()
                                    }
                                    .font(.subheadline)
                                }
                                
                                // ETA if available
                                if let routeInfo = routeService.getRoute(for: assignment.id) {
                                    HStack {
                                        Image(systemName: "clock")
                                            .foregroundStyle(.blue)
                                        Text("ETA: \(routeInfo.travelTimeText)")
                                            .font(.subheadline)
                                        Spacer()
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(8)
                        }
                    } else {
                        Text("No active assignment")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("Team Member")
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
    
    private var initials: String {
        if let callsign = member.callsign, !callsign.isEmpty {
            return String(callsign.prefix(2)).uppercased()
        }
        return String(member.email.prefix(2)).uppercased()
    }
    
    private var memberAssignment: AssignedLocation? {
        assignmentService.assignedLocations.first { $0.assignedToUserId == member.id }
    }
}

