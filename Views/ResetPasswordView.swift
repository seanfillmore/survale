//
//  ResetPasswordView.swift
//  Survale
//
//  Created by Sean Fillmore on 10/17/25.
//
import SwiftUI
import Supabase
import Auth

struct ResetPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var error: String?
    @State private var info: String?
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if let error { Text(error).foregroundColor(.red) }
                if let info  { Text(info).foregroundColor(.secondary) }

                Button {
                    Task { await sendReset() }
                } label: {
                    if isLoading { ProgressView() } else { Text("Send Reset Link").bold() }
                }
                .disabled(isLoading || !email.contains("@"))
            }
            .navigationTitle("Reset Password")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    @MainActor
    private func sendReset() async {
        error = nil; info = nil; isLoading = true
        do {
            try await SupabaseAuthService.shared.supabase.auth.resetPasswordForEmail(email)
            info = "If an account exists, a reset link has been sent."
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Couldn’t send reset email."
        }
        isLoading = false
    }
}

