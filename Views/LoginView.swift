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
        VStack(spacing: 16) {
            Text("Survale").font(.largeTitle).bold()

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.username)
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
                .padding().background(Color(.secondarySystemBackground)).cornerRadius(12)

            SecureField("Password", text: $password)
                .textContentType(.password)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { signIn() }
                .padding().background(Color(.secondarySystemBackground)).cornerRadius(12)

            if let error { Text(error).foregroundColor(.red) }

            Button(action: signIn) {
                if isLoading { ProgressView() } else { Text("Sign In").bold() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || email.isEmpty || password.isEmpty)
            
            // Inside LoginView's VStack, under the Sign In button:
            HStack {
                Button("Create account") { showSignUp = true }
                Spacer()
                Button("Forgot password?") { showReset = true }
            }
            .font(.footnote)
            .padding(.top, 8)

            .fullScreenCover(isPresented: $showSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $showReset) {
                ResetPasswordView()
                    .presentationDetents([.height(240), .medium])
            }

        }
        .padding()
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
