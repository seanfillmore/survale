//
//  InfoDetailRow.swift
//  Survale
//
//  Reusable detail row component for map info sheets
//

import SwiftUI

struct InfoDetailRow: View {
    let label: String
    let value: String
    var isLink: Bool = false
    var linkURL: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            if isLink, let urlString = linkURL, let url = URL(string: urlString) {
                Link(destination: url) {
                    HStack {
                        Text(value)
                            .font(.body)
                        Spacer()
                        Image(systemName: "arrow.up.right.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            } else {
                Text(value)
                    .font(.body)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

