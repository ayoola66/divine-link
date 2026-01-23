import SwiftUI

/// Settings view for configuring ProPresenter connection
struct ProPresenterSettingsView: View {
    @ObservedObject var settings: ProPresenterSettings
    @ObservedObject var client: ProPresenterClient
    
    @State private var portString: String = ""
    @State private var isTesting = false
    @State private var isPushing = false
    @State private var pushResult: PushResult?
    
    enum PushResult {
        case success
        case failure(String)
    }
    
    var body: some View {
        Form {
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
                Text("Enter the IP address and port from ProPresenter → Preferences → Network. Default port is 50233.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section {
                HStack {
                    // Connection status
                    HStack(spacing: 6) {
                        Circle()
                            .fill(settings.connectionStatus.color)
                            .frame(width: 10, height: 10)
                        
                        Text(settings.connectionStatus.displayText)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Test button
                    Button {
                        Task {
                            await testConnection()
                        }
                    } label: {
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text("Test Connection")
                        }
                    }
                    .disabled(!settings.isValid || isTesting)
                }
            } header: {
                Text("Status")
            }
            
            // Test Push Section
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
                        .disabled(settings.connectionStatus != .connected || isPushing)
                        
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
                        .disabled(settings.connectionStatus != .connected || isPushing)
                    }
                    
                    // Result feedback
                    if let result = pushResult {
                        HStack(spacing: 6) {
                            switch result {
                            case .success:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Message sent! Check your ProPresenter Stage Display.")
                                    .foregroundStyle(.green)
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
                Text("Test Stage Message")
            } footer: {
                Text("Send a test message to verify ProPresenter displays it on the Stage Screen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
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
        
        do {
            try await client.sendStageMessage("""
            📖 Divine Link Test
            
            John 3:16
            For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.
            """)
            pushResult = .success
        } catch {
            pushResult = .failure(error.localizedDescription)
        }
        
        isPushing = false
    }
    
    private func clearMessage() async {
        isPushing = true
        pushResult = nil
        
        do {
            try await client.clearStageMessage()
            pushResult = .success
        } catch {
            pushResult = .failure(error.localizedDescription)
        }
        
        isPushing = false
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
