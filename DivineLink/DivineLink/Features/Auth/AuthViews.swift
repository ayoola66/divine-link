import SwiftUI

// MARK: - Login View

struct LoginView: View {
    @ObservedObject private var authService = AuthService.shared
    @State private var email = ""
    @State private var otpCode = ""
    @State private var showOTPEntry = false
    @State private var countdown = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Close button
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Header
            VStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)
                
                Text(showOTPEntry ? "Enter Verification Code" : "Sign Up Free or Sign In")
                    .font(.title.bold())

                Text(showOTPEntry
                     ? "We've sent a 6-digit code to \(email)"
                     : "Enter your email — new or returning. We'll send a code. A free account unlocks 2 extra Bible versions; no password, no payment.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)   // wrap fully, never truncate
                    .padding(.horizontal, 4)
            }
            
            // Form
            if showOTPEntry {
                otpEntrySection
            } else {
                emailEntrySection
            }
            
            // Error message
            if let error = authService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Footer
            if !showOTPEntry {
                VStack(spacing: 8) {
                    Text("By signing in, you agree to our")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        Link("Terms of Service", destination: URL(string: "https://divinelink.netlify.app/terms")!)
                        Text("and")
                        Link("Privacy Policy", destination: URL(string: "https://divinelink.netlify.app/privacy")!)
                    }
                    .font(.caption)
                }
            }
        }
        .padding()
        .frame(width: 380)
        .frame(minHeight: 500)
        .onChange(of: authService.isAuthenticated) { _, isAuth in
            if isAuth {
                dismiss()
            }
        }
    }
    
    // MARK: - Email Entry
    
    private var emailEntrySection: some View {
        VStack(spacing: 16) {
            TextField("Email address", text: $email)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .onSubmit {
                    if !email.isEmpty && !authService.isLoading {
                        Task {
                            await requestOTP()
                        }
                    }
                }
            
            Button {
                Task {
                    await requestOTP()
                }
            } label: {
                HStack {
                    if authService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    Text(authService.isLoading ? "Sending..." : "Continue")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(email.isEmpty || authService.isLoading)
        }
    }
    
    // MARK: - OTP Entry
    
    private var otpEntrySection: some View {
        VStack(spacing: 16) {
            // Simple text field for OTP (macOS friendly)
            TextField("Enter 6-digit code", text: $otpCode)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 200)
                .onChange(of: otpCode) { _, newValue in
                    // Filter to digits only
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered != newValue {
                        otpCode = filtered
                        return
                    }
                    // Limit to 6 digits
                    if newValue.count > 6 {
                        otpCode = String(newValue.prefix(6))
                    }
                    // Auto-submit when complete
                    if otpCode.count == 6 {
                        Task {
                            await verifyOTP()
                        }
                    }
                }
            
            Text("\(otpCode.count)/6 digits")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Verify button
            Button {
                Task {
                    await verifyOTP()
                }
            } label: {
                HStack {
                    if authService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    Text(authService.isLoading ? "Verifying..." : "Verify")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(otpCode.count < 6 || authService.isLoading)
            
            // Resend option
            HStack {
                Text("Didn't receive the code?")
                    .foregroundStyle(.secondary)
                
                if countdown > 0 {
                    Text("Resend in \(countdown)s")
                        .foregroundStyle(.secondary)
                } else {
                    Button("Resend") {
                        Task {
                            await requestOTP()
                        }
                    }
                    .disabled(authService.isLoading)
                }
            }
            .font(.caption)
            
            // Back button
            Button("Use different email") {
                showOTPEntry = false
                otpCode = ""
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Helpers
    
    private func getDigit(at index: Int) -> String {
        guard index < otpCode.count else { return "" }
        let stringIndex = otpCode.index(otpCode.startIndex, offsetBy: index)
        return String(otpCode[stringIndex])
    }
    
    private func requestOTP() async {
        do {
            try await authService.requestOTP(email: email)
            showOTPEntry = true
            startCountdown()
        } catch {
            authService.errorMessage = error.localizedDescription
        }
    }
    
    private func verifyOTP() async {
        do {
            try await authService.verifyOTP(email: email, code: otpCode)
            // Register device after successful login
            try? await DeviceManager.shared.registerCurrentDevice()
            // Fetch subscription status
            await SubscriptionService.shared.fetchSubscription()
        } catch {
            authService.errorMessage = error.localizedDescription
            otpCode = ""
        }
    }
    
    private func startCountdown() {
        countdown = 60
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer.invalidate()
            }
        }
    }
}

// MARK: - OTP Digit View

struct OTPDigitView: View {
    let digit: String
    let isFocused: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color.orange : Color.gray.opacity(0.3), lineWidth: isFocused ? 2 : 1)
                .frame(width: 44, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
            
            Text(digit)
                .font(.title.bold())
        }
    }
}

// MARK: - Account View

struct AccountView: View {
    @ObservedObject private var authService = AuthService.shared
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @ObservedObject private var deviceManager = DeviceManager.shared
    @State private var showSignOutConfirmation = false

    // Editable profile fields
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var church = ""
    @State private var profileMessage: String?
    @State private var isSavingProfile = false
    @State private var billingMessage: String?
    @State private var isOpeningBilling = false

    private var isPremium: Bool { subscriptionService.isPremium || subscriptionService.isAdmin }

    var body: some View {
        ScrollView {
        VStack(spacing: 20) {
            // Profile Header
            VStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)

                if let user = authService.currentUser {
                    if !firstName.isEmpty || !lastName.isEmpty {
                        Text("\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces))
                            .font(.headline)
                    }
                    Text(user.email)
                        .font(firstName.isEmpty && lastName.isEmpty ? .headline : .subheadline)
                        .foregroundStyle(.secondary)
                }

                // Subscription badge — shows tier name + level
                HStack(spacing: 4) {
                    Image(systemName: subscriptionService.isPremium ? "star.fill" : "star")
                    Text(subscriptionBadgeText)
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(subscriptionBadgeColour.opacity(0.2))
                )
                .foregroundStyle(subscriptionBadgeColour)
            }

            Divider()

            // Profile editing (name for everyone; church for premium)
            VStack(alignment: .leading, spacing: 10) {
                Text("Your Details").font(.headline)
                HStack {
                    TextField("First name", text: $firstName)
                    TextField("Last name", text: $lastName)
                }
                .textFieldStyle(.roundedBorder)

                if isPremium {
                    TextField("Church name", text: $church)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Button {
                        Task { await saveProfile() }
                    } label: {
                        if isSavingProfile { ProgressView().controlSize(.small) } else { Text("Save details") }
                    }
                    .disabled(isSavingProfile)
                    if let msg = profileMessage {
                        Text(msg).font(.caption).foregroundStyle(msg.hasPrefix("✓") ? .green : .red)
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))

            // Manage Billing (premium only) → Stripe hosted portal
            if isPremium {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Billing").font(.headline)
                    Text("Update your billing address, payment method, invoices, or cancel — on Stripe's secure page.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        Task { await openBilling() }
                    } label: {
                        HStack {
                            Image(systemName: "creditcard")
                            if isOpeningBilling { ProgressView().controlSize(.small) } else { Text("Manage Billing") }
                        }
                    }
                    .disabled(isOpeningBilling)
                    if let msg = billingMessage {
                        Text(msg).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
            }
            
            // Devices Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Registered Devices")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(deviceManager.devices.count)/\(subscriptionService.currentTier.deviceLimit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if deviceManager.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if deviceManager.devices.isEmpty {
                    Text("No devices registered")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(deviceManager.devices) { device in
                        DeviceRow(device: device, isCurrentDevice: device.deviceId == deviceManager.deviceId)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            
            // Sign Out Button
            Button(role: .destructive) {
                showSignOutConfirmation = true
            } label: {
                Text("Sign Out")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .padding()
        }
        .frame(width: 380, height: 540)
        .onAppear {
            loadProfileFields()
            Task {
                await deviceManager.fetchDevices()
            }
        }
        .onChange(of: authService.currentUser?.id) { _, _ in loadProfileFields() }
        .confirmationDialog("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                Task {
                    try? await deviceManager.deactivateCurrentDevice()
                    await authService.signOut()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    // MARK: - Profile actions

    /// Pull the current user's saved details into the editable fields (auto-populated on login).
    private func loadProfileFields() {
        firstName = authService.currentUser?.firstName ?? ""
        lastName = authService.currentUser?.lastName ?? ""
        church = authService.currentUser?.church ?? ""
    }

    private func saveProfile() async {
        isSavingProfile = true
        profileMessage = nil
        defer { isSavingProfile = false }
        do {
            try await authService.updateProfile(
                firstName: firstName.trimmingCharacters(in: .whitespaces),
                lastName: lastName.trimmingCharacters(in: .whitespaces),
                church: isPremium ? church.trimmingCharacters(in: .whitespaces) : nil
            )
            profileMessage = "✓ Saved"
        } catch {
            profileMessage = (error as? AuthError)?.errorDescription ?? "Couldn't save. Try again."
        }
    }

    private func openBilling() async {
        isOpeningBilling = true
        billingMessage = nil
        defer { isOpeningBilling = false }
        if let error = await subscriptionService.openBillingPortal() {
            billingMessage = error
        }
    }

    // MARK: - Badge Helpers
    
    /// Badge text: "Admin" for admin; otherwise "Love, Premium" / "Grace, Premium" / "Mercy, Free"
    private var subscriptionBadgeText: String {
        if subscriptionService.isAdmin { return "Admin" }
        let tier = subscriptionService.currentTier
        let level = subscriptionService.isPremium ? "Premium" : "Free"
        return "\(tier.displayName), \(level)"
    }
    
    /// Badge colour: red for Admin; otherwise tier-based
    private var subscriptionBadgeColour: Color {
        if subscriptionService.isAdmin { return .red }
        switch subscriptionService.currentTier {
        case .love:
            return .purple
        case .grace:
            return .orange
        case .mercy:
            return .secondary
        }
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: RegisteredDevice
    let isCurrentDevice: Bool
    @ObservedObject private var deviceManager = DeviceManager.shared
    
    var body: some View {
        HStack {
            Image(systemName: "desktopcomputer")
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(device.deviceName ?? "Unknown")
                        .font(.subheadline)
                    
                    if isCurrentDevice {
                        Text("This device")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .cornerRadius(4)
                    }
                }
                
                Text("Last active: \(device.lastActiveAt, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if !isCurrentDevice {
                Button(role: .destructive) {
                    Task {
                        try? await deviceManager.removeDevice(device)
                    }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Auth Button (for use in other views)

struct AuthButton: View {
    @ObservedObject private var authService = AuthService.shared
    @State private var showLoginSheet = false
    @State private var showAccountSheet = false
    
    var body: some View {
        Button {
            if authService.isAuthenticated {
                showAccountSheet = true
            } else {
                showLoginSheet = true
            }
        } label: {
            HStack {
                Image(systemName: authService.isAuthenticated ? "person.circle.fill" : "person.circle")
                Text(authService.isAuthenticated ? "Account" : "Sign In")
            }
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginView()
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountView()
        }
    }
}
