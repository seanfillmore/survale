import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var showSignUp = false
    @State private var showReset = false
    @FocusState private var focusedField: Field?
    enum Field { case email, password }

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 40)
                    
                    // App branding header
                    VStack(spacing: 16) {
                        // App logo
                        Image("LoginLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .shadow(color: .blue.opacity(0.3), radius: 15, x: 0, y: 8)
                        
                        Text("Survale")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Tactical Operations Platform")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 20)
                    
                    // Login form
                    VStack(spacing: 20) {
                        // Email field
                        LoginTextField(
                            icon: "envelope.fill",
                            placeholder: "Email",
                            text: $email
                        )
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        
                        // Password field
                        LoginSecureField(
                            icon: "lock.fill",
                            placeholder: "Password",
                            text: $password
                        )
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { signIn() }
                        
                        // Error message
                        if let error {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(error)
                                Spacer()
                            }
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        // Sign in button
                        Button(action: signIn) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Sign In")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isLoading || email.isEmpty || password.isEmpty)
                        .opacity((isLoading || email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
                        
                        // Forgot password link
                        Button(action: { showReset = true }) {
                            Text("Forgot password?")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer().frame(height: 40)
                    
                    // Create account section
                    VStack(spacing: 16) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 12) {
                            Text("Don't have an account?")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Button(action: { showSignUp = true }) {
                                Text("Create Account")
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(16)
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    
                    Spacer()
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .fullScreenCover(isPresented: $showSignUp) {
            SignUpView()
        }
        .sheet(isPresented: $showReset) {
            ResetPasswordView()
                .presentationDetents([.height(240), .medium])
        }
    }

    private func signIn() {
        guard email.contains("@") else { error = "Enter a valid email."; return }
        isLoading = true; error = nil
        Task {
            do {
                try await SupabaseAuthService.shared.signIn(email: email, password: password)
                // appState.isAuthenticated will flip via the auth listener
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? "Sign-in failed."
            }
            isLoading = false
        }
    }
}

// MARK: - Custom Text Field Components

struct LoginTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue.gradient)
                .frame(width: 24)
            
            TextField(placeholder, text: $text)
                .font(.body)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

struct LoginSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue.gradient)
                .frame(width: 24)
            
            SecureField(placeholder, text: $text)
                .font(.body)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}
