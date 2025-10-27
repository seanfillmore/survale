//
//  SplashView.swift
//  Survale
//
//  Splash screen with loading indicator shown during app initialization
//

import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var progressOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Gradient background matching login screen
            LinearGradient(
                colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.1), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo
                VStack(spacing: 20) {
                    Image("LoginLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .shadow(color: .blue.opacity(0.4), radius: 20, x: 0, y: 10)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                    
                    Text("Survale")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(logoOpacity)
                    
                    Text("Tactical Operations Platform")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .opacity(logoOpacity)
                }
                
                Spacer()
                
                // Loading indicator
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(1.2)
                    
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(progressOpacity)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            // Animate logo entrance
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            
            // Fade in progress indicator after logo
            withAnimation(.easeIn(duration: 0.4).delay(0.3)) {
                progressOpacity = 1.0
            }
        }
    }
}

#Preview {
    SplashView()
}

