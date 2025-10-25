// RootView.swift
import SwiftUI
struct RootView: View {
    @EnvironmentObject var appState: AppState
    var body: some View {
        if appState.isAuthenticated { MainTabsView() } else { LoginView() }
    }
}

