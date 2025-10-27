//
//  SurvaleApp.swift
//  Survale
//
//  Created by Sean Fillmore on 10/17/25.
//

import SwiftUI

@main
struct SurvaleApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app content
                RootView()
                    .environmentObject(appState)
                    .opacity(appState.isInitializing ? 0 : 1)
                
                // Splash screen overlay
                if appState.isInitializing {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                await initializeApp()
            }
        }
    }
    
    private func initializeApp() async {
        // Set up auth service
        SupabaseAuthService.shared.setAppState(appState)
        
        // Start auth listener
        SupabaseAuthService.shared.startAuthListener { isAuthed in
            appState.isAuthenticated = isAuthed
        }
        
        // Minimum splash display time (ensure smooth experience)
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Hide splash screen
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.5)) {
                appState.isInitializing = false
            }
        }
    }
}

