//
//  TargetMarker.swift
//  Survale
//
//  Map marker for displaying targets with status-based color and pulsing animation
//

import SwiftUI

struct TargetMarker: View {
    let target: OpTarget
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Pulsing ring for active targets
            if target.status == .active {
                Circle()
                    .fill(target.status.color.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0.0 : 0.8)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
                    .onAppear { isPulsing = true }
            }
            
            // Main marker
            Image(systemName: iconForKind)
                .font(.title2)
                .foregroundStyle(.white)
                .padding(8)
                .background(target.status.color, in: Circle())
                .shadow(radius: 3)
                .overlay {
                    // Status badge
                    Circle()
                        .fill(target.status.color)
                        .frame(width: 12, height: 12)
                        .overlay {
                            Circle()
                                .strokeBorder(.white, lineWidth: 2)
                        }
                        .offset(x: 12, y: -12)
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
}

