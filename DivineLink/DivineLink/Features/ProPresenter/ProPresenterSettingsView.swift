import SwiftUI

/// Settings view for configuring ProPresenter connection
struct ProPresenterSettingsView: View {
    @ObservedObject var settings: ProPresenterSettings
    @ObservedObject var client: ProPresenterClient
    @StateObject private var integrationManager = HybridIntegrationManager.shared
    
    @State private var portString: String = ""
    @State private var isTesting = false
    @State private var isPushing = false
    @State private var pushResult: PushResult?
    @State private var hasAccessibilityPermission = false

    private let subscriptionService = SubscriptionService.shared
    @StateObject private var adManager = AdManager.shared
    
    enum PushResult {
        case success
        case failure(String)
    }
    
    var body: some View {
        Form {
            // Setup (same-machine vs two-machines)
            topologySection

            // Connection Settings
            connectionSection

            // Output Paths Section
            outputPathsSection

            // Connection Dashboard
            connectionDashboardSection

            // Test Push Section
            testSection

            // Accessibility Section (for keyboard automation)
            if settings.effectiveKeyboardAutomationEnabled {
                accessibilitySection
            }
        }
        .onAppear {
            checkAccessibility()
            Task {
                await integrationManager.configure()
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $adManager.showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Topology

    private var topologySection: some View {
        Section {
            Picker("Setup", selection: Binding(
                get: { settings.effectiveTopology },
                set: { newValue in
                    if newValue == .twoMachines && !subscriptionService.canUsePremiumFeatures {
                        adManager.requestUpgrade()
                    } else {
                        settings.topology = newValue
                    }
                }
            )) {
                ForEach(ProPresenterTopology.allCases, id: \.self) { topology in
                    Text(topology.displayName).tag(topology)
                }
            }
            .pickerStyle(.segmented)

            Text(settings.effectiveTopology.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("ProPresenter Setup")
        } footer: {
            Text("Two Machines is for large events where ProPresenter runs on a separate laptop connected to the projector. Requires Premium.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Sections
    
    private var connectionSection: some View {
        Section {
            // IP Address
            VStack(alignment: .leading, spacing: 4) {
                Text("IP Address")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("127.0.0.1", text: $settings.ipAddress)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
            }
            
            // Port
            VStack(alignment: .leading, spacing: 4) {
                Text("Port")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("50233", text: $portString)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .onAppear { portString = String(settings.port) }
                    .onChange(of: portString) { _, newValue in
                        if let port = Int(newValue) {
                            settings.port = port
                        }
                    }
            }
            
            // Validation error
            if let error = settings.validationError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        } header: {
            Text("ProPresenter Connection")
        } footer: {
            Text(settings.effectiveTopology == .sameMachine
                 ? "Enter the IP address and port from ProPresenter → Preferences → Network. Default port is 50233. Use 127.0.0.1 since both apps run on this Mac."
                 : "Enter the IP address of the Mac running ProPresenter (ProPresenter → Preferences → Network) and its port. Default port is 50233. Both Macs must be on the same network.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var outputPathsSection: some View {
        Section {
            // Stage Display Toggle
            Toggle(isOn: $settings.stageDisplayEnabled) {
                HStack {
                    Image(systemName: "display")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text("Stage Display")
                        Text("Shows scripture on confidence monitor")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Messages API Toggle (Premium)
            Toggle(isOn: $settings.messagesAPIEnabled) {
                HStack {
                    Image(systemName: "network")
                        .foregroundStyle(subscriptionService.canUsePremiumFeatures ? .purple : .gray)
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Messages API")
                            if !subscriptionService.canUsePremiumFeatures {
                                Text("Premium")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.orange.opacity(0.2))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }
                        }
                        Text("WebSocket-based audience display")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(!subscriptionService.canUsePremiumFeatures)
            
            // Keyboard Automation Toggle — only offered in same-machine mode.
            // It's local keystroke simulation (Accessibility API) and cannot
            // reach ProPresenter on a different Mac, so it's structurally
            // unavailable in two-machine mode rather than just discouraged.
            if settings.effectiveTopology == .sameMachine {
                Toggle(isOn: $settings.keyboardAutomationEnabled) {
                    HStack {
                        Image(systemName: "keyboard")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading) {
                            Text("Keyboard Automation")
                            Text("Uses ⌘B to trigger PP's Bible")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                HStack {
                    Image(systemName: "keyboard.badge.ellipsis")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text("Keyboard Automation")
                            .foregroundStyle(.secondary)
                        Text("Not available in Two Machines mode — can't reach another Mac")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Auto-fallback Toggle
            if settings.messagesAPIEnabled && settings.effectiveKeyboardAutomationEnabled {
                Toggle(isOn: $settings.autoFallbackEnabled) {
                    HStack {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading) {
                            Text("Auto-Fallback")
                            Text("Use keyboard if WebSocket fails")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("Output Paths")
        } footer: {
            Text("Enable the output paths you want to use. Stage Display is for operators, Audience outputs show to the congregation.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var connectionDashboardSection: some View {
        Section {
            ForEach(settings.enabledOutputTypes, id: \.self) { outputType in
                HStack {
                    // Output icon and name
                    Image(systemName: outputType.icon)
                        .foregroundStyle(integrationManager.status(for: outputType).color)
                    
                    Text(outputType.displayName)
                    
                    Spacer()
                    
                    // Status indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(integrationManager.status(for: outputType).color)
                            .frame(width: 8, height: 8)
                        
                        Text(integrationManager.status(for: outputType).displayText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Test All button
            HStack {
                Spacer()
                
                Button {
                    Task {
                        await testAllConnections()
                    }
                } label: {
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Label("Test All Connections", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(!settings.isValid || isTesting)
            }
        } header: {
            HStack {
                Text("Connection Status")
                Spacer()
                Text(integrationManager.statusSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var testSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    // Send test message button
                    Button {
                        Task {
                            await sendTestMessage()
                        }
                    } label: {
                        HStack {
                            if isPushing {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text("Send Test Message")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!integrationManager.systemStatus.isReady || isPushing)
                    
                    // Clear message button
                    Button {
                        Task {
                            await clearMessage()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Clear")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!integrationManager.systemStatus.isReady || isPushing)
                }
                
                // Result feedback
                if let result = pushResult {
                    HStack(spacing: 6) {
                        switch result {
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading) {
                                Text("Message sent!")
                                    .foregroundStyle(.green)
                                if let lastOutput = integrationManager.lastSuccessfulOutput {
                                    Text("via \(lastOutput.displayName)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        case .failure(let error):
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .foregroundStyle(.red)
                        }
                    }
                    .font(.caption)
                }
            }
        } header: {
            Text("Test Display")
        } footer: {
            Text("Send a test message to verify all enabled outputs are working correctly.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var accessibilitySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                // Permission status
                HStack(spacing: 8) {
                    Circle()
                        .fill(hasAccessibilityPermission ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                    
                    Text(hasAccessibilityPermission ? "Accessibility Enabled" : "Accessibility Required")
                        .foregroundStyle(hasAccessibilityPermission ? .green : .orange)
                    
                    Spacer()
                    
                    if !hasAccessibilityPermission {
                        Button("Grant Access") {
                            requestAccessibility()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Button("Refresh") {
                        checkAccessibility()
                    }
                    .buttonStyle(.bordered)
                }
                
                Text("Keyboard automation requires Accessibility permission to control ProPresenter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Keyboard Automation")
        } footer: {
            Text("When using keyboard automation, Divine Link will: Open PP's Bible (⌘B) → Type the reference → Press Enter.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Actions
    
    private func testAllConnections() async {
        isTesting = true
        await integrationManager.testAllConnections(with: settings)
        isTesting = false
    }
    
    private func testConnection() async {
        guard settings.isValid, let url = settings.connectionURL else { return }
        
        isTesting = true
        settings.connectionStatus = .testing
        
        do {
            client.configure(baseURL: url)
            let connected = try await client.testConnection(to: url)
            settings.connectionStatus = connected ? .connected : .disconnected
        } catch {
            settings.connectionStatus = .error(error.localizedDescription)
        }
        
        isTesting = false
    }
    
    private func sendTestMessage() async {
        isPushing = true
        pushResult = nil
        
        // Create test scripture data
        let testScripture = ScriptureDisplayData(
            reference: "John 3:16",
            text: "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.",
            translation: "KJV",
            confidence: 0.95
        )
        
        let success = await integrationManager.displayScripture(testScripture)
        
        if success {
            pushResult = .success
        } else {
            pushResult = .failure(integrationManager.lastError ?? "Failed to display")
        }
        
        isPushing = false
    }
    
    private func clearMessage() async {
        isPushing = true
        pushResult = nil
        
        let success = await integrationManager.clearAllDisplays()
        
        if success {
            pushResult = .success
        } else {
            pushResult = .failure("Failed to clear displays")
        }
        
        isPushing = false
    }
    
    private func checkAccessibility() {
        Task { @MainActor in
            hasAccessibilityPermission = KeyboardAutomationService.shared.checkAccessibilityPermission()
        }
    }
    
    private func requestAccessibility() {
        Task { @MainActor in
            KeyboardAutomationService.shared.requestAccessibilityPermission()
            // Check again after a short delay
            try? await Task.sleep(nanoseconds: 500_000_000)
            hasAccessibilityPermission = KeyboardAutomationService.shared.checkAccessibilityPermission()
        }
    }
}

// MARK: - Connection Status Indicator (for Header)

struct ConnectionStatusIndicator: View {
    let status: ConnectionStatus
    let ipAddress: String
    let port: Int
    
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: 4) {
            // Status dot
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
                .opacity(isPulsing ? 0.5 : 1.0)
                .animation(pulseAnimation, value: isPulsing)
                .onChange(of: status) { _, newStatus in
                    isPulsing = newStatus == .testing
                }
            
            // Status icon
            Image(systemName: status.icon)
                .font(.system(size: 10))
                .foregroundStyle(status.color)
        }
        .help(tooltipText)
    }
    
    private var tooltipText: String {
        "ProPresenter: \(status.displayText)\n\(ipAddress):\(port)"
    }
    
    private var pulseAnimation: Animation? {
        status == .testing
            ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
            : nil
    }
}

#Preview {
    ProPresenterSettingsView(
        settings: ProPresenterSettings(),
        client: ProPresenterClient()
    )
    .frame(width: 400)
}
