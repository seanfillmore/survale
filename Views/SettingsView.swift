import SwiftUI
import Supabase

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    // User profile fields
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var callsign = ""
    @State private var phoneNumber = ""
    @State private var email = ""
    
    // Vehicle information
    @State private var vehicleType: VehicleType = .sedan
    @State private var vehicleColor: VehicleColor = .black
    
    // Original values (to track changes)
    @State private var originalFirstName = ""
    @State private var originalLastName = ""
    @State private var originalCallsign = ""
    @State private var originalPhoneNumber = ""
    @State private var originalVehicleType: VehicleType = .sedan
    @State private var originalVehicleColor: VehicleColor = .black
    
    // UI state
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var error: String?
    @State private var successMessage: String?
    @State private var isPhoneValid = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.blue)
                        
                        Text("Profile Settings")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Update your personal information")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Personal Information Section
                    VStack(spacing: 16) {
                        SettingsSectionHeader(title: "Personal Information")
                        
                        SettingsTextField(icon: "person.fill", placeholder: "First Name", text: $firstName)
                            .autocorrectionDisabled()
                        
                        SettingsTextField(icon: "person.fill", placeholder: "Last Name", text: $lastName)
                            .autocorrectionDisabled()
                        
                        SettingsTextField(icon: "signature", placeholder: "Call Sign", text: $callsign)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                        
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            
                            TextField("Phone Number (###-###-####)", text: $phoneNumber)
                                .keyboardType(.phonePad)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .onChange(of: phoneNumber) { _, newValue in
                            let formatted = formatPhoneNumber(newValue)
                            if phoneNumber != formatted {
                                phoneNumber = formatted
                            }
                            // Validate async to avoid blocking UI
                            Task { @MainActor in
                                isPhoneValid = isValidPhoneNumber(formatted)
                            }
                        }
                        
                        // Email (read-only)
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            
                            Text(email.isEmpty ? "Loading..." : email)
                                .foregroundStyle(email.isEmpty ? .secondary : .primary)
                            
                            Spacer()
                            
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                    
                    // Vehicle Information Section
                    VStack(spacing: 16) {
                        SettingsSectionHeader(title: "Vehicle Information")
                        
                        // Vehicle Type Picker
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "car.fill")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                
                                Text("Vehicle Type")
                                    .foregroundStyle(.secondary)
                            }
                            
                            Picker("Vehicle Type", selection: $vehicleType) {
                                ForEach(VehicleType.allCases, id: \.self) { type in
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
                    
                    // Error/Success Messages
                    if let error {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                    
                    if let successMessage {
                        Text(successMessage)
                            .font(.footnote)
                            .foregroundStyle(.green)
                            .padding(.horizontal)
                    }
                    
                    // Save Button
                    Button {
                        Task {
                            await saveProfile()
                        }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save Changes")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSave ? Color.blue : Color.gray)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canSave || isSaving)
                    .padding(.horizontal)
                    
                    // Sign Out Button
                    Button(role: .destructive) {
                        Task {
                            await signOut()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundStyle(.red)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadUserProfile()
            }
        }
    }
    
    private var canSave: Bool {
        // Check if fields are valid (use cached phone validation)
        let fieldsValid = !firstName.isEmpty &&
                         !lastName.isEmpty &&
                         !callsign.isEmpty &&
                         isPhoneValid
        
        // Check if anything has changed
        let hasChanges = firstName != originalFirstName ||
                        lastName != originalLastName ||
                        callsign != originalCallsign ||
                        phoneNumber != originalPhoneNumber ||
                        vehicleType != originalVehicleType ||
                        vehicleColor != originalVehicleColor
        
        return fieldsValid && hasChanges
    }
    
    private func isValidPhoneNumber(_ phone: String) -> Bool {
        let pattern = "^\\d{3}-\\d{3}-\\d{4}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: phone.utf16.count)
        return regex?.firstMatch(in: phone, range: range) != nil
    }
    
    private func formatPhoneNumber(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        
        if digits.count <= 3 {
            return digits
        } else if digits.count <= 6 {
            let areaCode = digits.prefix(3)
            let middle = digits.dropFirst(3)
            return "\(areaCode)-\(middle)"
        } else {
            let areaCode = digits.prefix(3)
            let middle = digits.dropFirst(3).prefix(3)
            let last = digits.dropFirst(6).prefix(4)
            return "\(areaCode)-\(middle)-\(last)"
        }
    }
    
    @MainActor
    private func loadUserProfile() async {
        isLoading = true
        error = nil
        
        do {
            let userId = try await SupabaseAuthService.shared.supabase.auth.session.user.id
            
            // Get user email
            email = try await SupabaseAuthService.shared.supabase.auth.session.user.email ?? ""
            
            // Fetch user profile
            let response: UserProfile = try await SupabaseAuthService.shared.supabase
                .from("users")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            // Populate fields
            firstName = response.first_name ?? ""
            lastName = response.last_name ?? ""
            callsign = response.callsign ?? ""
            phoneNumber = response.phone_number ?? ""
            
            // Vehicle info
            if let vehicleTypeStr = response.vehicle_type,
               let type = VehicleType(rawValue: vehicleTypeStr) {
                vehicleType = type
            }
            
            if let vehicleColorStr = response.vehicle_color,
               let color = VehicleColor(rawValue: vehicleColorStr) {
                vehicleColor = color
            }
            
            // Store original values for change tracking
            originalFirstName = firstName
            originalLastName = lastName
            originalCallsign = callsign
            originalPhoneNumber = phoneNumber
            originalVehicleType = vehicleType
            originalVehicleColor = vehicleColor
            
            // Initialize phone validation
            isPhoneValid = isValidPhoneNumber(phoneNumber)
            
        } catch {
            self.error = "Failed to load profile: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    @MainActor
    private func saveProfile() async {
        isSaving = true
        error = nil
        successMessage = nil
        
        do {
            let userId = try await SupabaseAuthService.shared.supabase.auth.session.user.id
            
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
            
            // Update original values after successful save
            originalFirstName = firstName
            originalLastName = lastName
            originalCallsign = callsign
            originalPhoneNumber = phoneNumber
            originalVehicleType = vehicleType
            originalVehicleColor = vehicleColor
            
            successMessage = "✓ Profile updated successfully!"
            
            // Clear success message after 3 seconds
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            successMessage = nil
            
        } catch {
            self.error = "Failed to save: \(error.localizedDescription)"
        }
        
        isSaving = false
    }
    
    @MainActor
    private func signOut() async {
        do {
            try await SupabaseAuthService.shared.signOut()
            appState.isAuthenticated = false
        } catch {
            self.error = "Sign out failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting Components

private struct SettingsSectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}

private struct SettingsTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - User Profile Model

private struct UserProfile: Decodable {
    let first_name: String?
    let last_name: String?
    let callsign: String?
    let phone_number: String?
    let vehicle_type: String?
    let vehicle_color: String?
}
