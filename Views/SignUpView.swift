//
//  SignUpView.swift
//  Survale
//
//  Created by Sean Fillmore on 10/17/25.
//
import SwiftUI
import Auth
import Supabase

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Account credentials
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    // Personal information
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var callsign = ""
    @State private var phoneNumber = ""
    
    // Vehicle information
    @State private var vehicleType: VehicleType = .sedan
    @State private var vehicleColor: VehicleColor = .black
    
    // UI state
    @State private var error: String?
    @State private var isLoading = false
    @State private var info: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue.gradient)
                        
                        Text("Create Account")
                            .font(.title.bold())
                        
                        Text("Fill in your details to get started")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Account Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Account Information")
                        
                        CustomTextField(icon: "envelope.fill", placeholder: "Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        
                        CustomSecureField(icon: "lock.fill", placeholder: "Password (min 8 characters)", text: $password)
                            .textContentType(.newPassword)
                        
                        CustomSecureField(icon: "lock.fill", placeholder: "Confirm Password", text: $confirmPassword)
                            .textContentType(.newPassword)
                    }
                    .padding(.horizontal)
                    
                    // Personal Information Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Personal Information")
                        
                        CustomTextField(icon: "person.fill", placeholder: "First Name", text: $firstName)
                            .textContentType(.givenName)
                        
                        CustomTextField(icon: "person.fill", placeholder: "Last Name", text: $lastName)
                            .textContentType(.familyName)
                        
                        CustomTextField(icon: "star.fill", placeholder: "Callsign", text: $callsign)
                        
                        CustomTextField(icon: "phone.fill", placeholder: "Phone Number (###-###-####)", text: $phoneNumber)
                            .keyboardType(.numberPad)
                            .textContentType(.telephoneNumber)
                            .onChange(of: phoneNumber) { _, newValue in
                                phoneNumber = formatPhoneNumber(newValue)
                            }
                    }
                    .padding(.horizontal)
                    
                    // Vehicle Information Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Vehicle Information")
                        
                        // Vehicle Type Picker
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "car.fill")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                
                                Text("Vehicle Type")
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                            }
                            
                            Picker("Vehicle Type", selection: $vehicleType) {
                                ForEach([VehicleType.sedan, VehicleType.suv, VehicleType.pickup], id: \.self) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Vehicle Color Picker
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "paintpalette.fill")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                
                                Text("Vehicle Color")
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                            }
                            
                            Picker("Vehicle Color", selection: $vehicleColor) {
                                ForEach(VehicleColor.allCases, id: \.self) { color in
                                    HStack {
                                        Circle()
                                            .fill(color.color)
                                            .frame(width: 16, height: 16)
                                        Text(color.displayName)
                                    }
                                    .tag(color)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Error/Info Messages
                    if let error {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    if let info {
                        Text(info)
                            .font(.footnote)
                            .foregroundColor(.blue)
                            .padding(.horizontal)
                    }
                    
                    // Create Account Button
                    Button {
                        Task { await signUp() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Create Account")
                                    .bold()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSubmit ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || !canSubmit)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var canSubmit: Bool {
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 8 &&
        password == confirmPassword &&
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !callsign.isEmpty &&
        isValidPhoneNumber(phoneNumber)
        // vehicleColor has a default value, so no need to check
    }
    
    private func isValidPhoneNumber(_ phone: String) -> Bool {
        // Check format: ###-###-####
        let pattern = "^\\d{3}-\\d{3}-\\d{4}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: phone.utf16.count)
        return regex?.firstMatch(in: phone, range: range) != nil
    }
    
    private func formatPhoneNumber(_ input: String) -> String {
        // Remove all non-numeric characters
        let digits = input.filter { $0.isNumber }
        
        // Limit to 10 digits
        let limitedDigits = String(digits.prefix(10))
        
        // Format as ###-###-####
        var formatted = ""
        for (index, digit) in limitedDigits.enumerated() {
            if index == 3 || index == 6 {
                formatted.append("-")
            }
            formatted.append(digit)
        }
        
        return formatted
    }

    @MainActor
    private func signUp() async {
        error = nil
        info = nil
        isLoading = true
        
        do {
            // Create auth account
            let response = try await SupabaseAuthService.shared.supabase.auth.signUp(
                email: email,
                password: password
            )
            
            let userId = response.user.id
            
            // Update user profile with additional info
            try await updateUserProfile(userId: userId)
            
            info = "Account created successfully! You can now log in."
            
            // Dismiss after a short delay
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            dismiss()
            
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Sign up failed: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func updateUserProfile(userId: UUID) async throws {
        struct UserUpdate: Encodable {
            let first_name: String
            let last_name: String
            let full_name: String
            let callsign: String
            let phone_number: String
            let vehicle_type: String
            let vehicle_color: String
        }
        
        let fullName = "\(firstName) \(lastName)"
        let update = UserUpdate(
            first_name: firstName,
            last_name: lastName,
            full_name: fullName,
            callsign: callsign,
            phone_number: phoneNumber,
            vehicle_type: vehicleType.rawValue,
            vehicle_color: vehicleColor.rawValue
        )
        
        try await SupabaseAuthService.shared.supabase
            .from("users")
            .update(update)
            .eq("id", value: userId.uuidString)
            .execute()
    }
}

// MARK: - Custom UI Components

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            SecureField(placeholder, text: $text)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Vehicle Color Enum

enum VehicleColor: String, CaseIterable {
    case black = "Black"
    case white = "White"
    case silver = "Silver"
    case gray = "Gray"
    case red = "Red"
    case blue = "Blue"
    case green = "Green"
    case yellow = "Yellow"
    case orange = "Orange"
    case brown = "Brown"
    case tan = "Tan"
    case gold = "Gold"
    
    var displayName: String {
        return rawValue
    }
    
    var color: Color {
        switch self {
        case .black: return .black
        case .white: return Color(white: 0.95)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case .gray: return .gray
        case .red: return .red
        case .blue: return .blue
        case .green: return .green
        case .yellow: return .yellow
        case .orange: return .orange
        case .brown: return Color(red: 0.6, green: 0.4, blue: 0.2)
        case .tan: return Color(red: 0.82, green: 0.71, blue: 0.55)
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0.0)
        }
    }
}
