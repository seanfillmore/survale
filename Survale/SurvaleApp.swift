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
            RootView()
                .environmentObject(appState)
                .task {
                    SupabaseAuthService.shared.setAppState(appState)
                    SupabaseAuthService.shared.startAuthListener { isAuthed in
                        appState.isAuthenticated = isAuthed
                    }
                }
        }
    }
}

