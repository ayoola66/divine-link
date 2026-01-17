# Story 3.5: ProPresenter Connection Settings

**Epic:** 3 - Pending Buffer & ProPresenter Integration  
**Story ID:** 3.5  
**Status:** Not Started  
**Complexity:** Small  

---

## User Story

**As an** operator,  
**I want** to configure the ProPresenter connection,  
**so that** Divine Link can communicate with my ProPresenter instance.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Settings panel includes ProPresenter section | Section visible in settings |
| 2 | User can enter ProPresenter IP address | Text field for IP |
| 3 | User can enter port number (default: 1025) | Port field with default |
| 4 | "Test Connection" button verifies connectivity | Button tests and shows result |
| 5 | Connection status displayed | Status indicator visible |
| 6 | Settings persisted between app launches | Relaunch retains settings |
| 7 | Invalid IP/port shows validation error | Error message shown |

---

## Technical Notes

### ProPresenter Settings Model

```swift
import Foundation

class ProPresenterSettings: ObservableObject {
    @Published var ipAddress: String {
        didSet { save() }
    }
    
    @Published var port: Int {
        didSet { save() }
    }
    
    @Published var connectionStatus: ConnectionStatus = .unknown
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let ipAddress = "propresenter.ipAddress"
        static let port = "propresenter.port"
    }
    
    init() {
        self.ipAddress = defaults.string(forKey: Keys.ipAddress) ?? "192.168.1.100"
        self.port = defaults.integer(forKey: Keys.port)
        if self.port == 0 { self.port = 1025 }
    }
    
    private func save() {
        defaults.set(ipAddress, forKey: Keys.ipAddress)
        defaults.set(port, forKey: Keys.port)
    }
    
    var isValid: Bool {
        isValidIPAddress(ipAddress) && port > 0 && port < 65536
    }
    
    var connectionURL: URL? {
        URL(string: "http://\(ipAddress):\(port)")
    }
    
    private func isValidIPAddress(_ string: String) -> Bool {
        let parts = string.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let num = Int(part) else { return false }
            return num >= 0 && num <= 255
        }
    }
}

enum ConnectionStatus {
    case unknown
    case testing
    case connected
    case disconnected
    case error(String)
    
    var displayText: String {
        switch self {
        case .unknown: return "Not tested"
        case .testing: return "Testing..."
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .error(let message): return "Error: \(message)"
        }
    }
    
    var color: Color {
        switch self {
        case .connected: return .green
        case .disconnected, .error: return .red
        case .testing: return .orange
        case .unknown: return .gray
        }
    }
}
```

### ProPresenter Settings View

```swift
import SwiftUI

struct ProPresenterSettingsView: View {
    @ObservedObject var settings: ProPresenterSettings
    let onTestConnection: () async -> Void
    
    @State private var portString: String = ""
    @State private var validationError: String?
    
    var body: some View {
        Form {
            Section {
                // IP Address
                TextField("IP Address", text: $settings.ipAddress)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: settings.ipAddress) { _ in
                        validateInput()
                    }
                
                // Port
                TextField("Port", text: $portString)
                    .textFieldStyle(.roundedBorder)
                    .onAppear { portString = String(settings.port) }
                    .onChange(of: portString) { newValue in
                        if let port = Int(newValue) {
                            settings.port = port
                        }
                        validateInput()
                    }
                
                // Validation error
                if let error = validationError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            } header: {
                Text("ProPresenter Connection")
            }
            
            Section {
                HStack {
                    // Connection status
                    Circle()
                        .fill(settings.connectionStatus.color)
                        .frame(width: 10, height: 10)
                    
                    Text(settings.connectionStatus.displayText)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Test button
                    Button("Test Connection") {
                        Task {
                            await onTestConnection()
                        }
                    }
                    .disabled(!settings.isValid || settings.connectionStatus == .testing)
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private func validateInput() {
        if !settings.isValid {
            if !isValidIP(settings.ipAddress) {
                validationError = "Invalid IP address format"
            } else if settings.port <= 0 || settings.port >= 65536 {
                validationError = "Port must be between 1 and 65535"
            }
        } else {
            validationError = nil
        }
    }
    
    private func isValidIP(_ string: String) -> Bool {
        let parts = string.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let num = Int(part) else { return false }
            return num >= 0 && num <= 255
        }
    }
}
```

### Settings View Integration

```swift
struct SettingsView: View {
    @StateObject private var ppSettings = ProPresenterSettings()
    @StateObject private var audioSettings = AudioDeviceManager()
    @StateObject private var ppClient = ProPresenterClient()
    
    var body: some View {
        TabView {
            // Audio Tab
            AudioSettingsView(settings: audioSettings)
                .tabItem {
                    Label("Audio", systemImage: "mic.fill")
                }
            
            // ProPresenter Tab
            ProPresenterSettingsView(settings: ppSettings) {
                await testConnection()
            }
            .tabItem {
                Label("ProPresenter", systemImage: "tv.fill")
            }
        }
        .frame(width: 450, height: 300)
    }
    
    private func testConnection() async {
        ppSettings.connectionStatus = .testing
        
        do {
            let connected = try await ppClient.testConnection(
                to: ppSettings.connectionURL!
            )
            ppSettings.connectionStatus = connected ? .connected : .disconnected
        } catch {
            ppSettings.connectionStatus = .error(error.localizedDescription)
        }
    }
}
```

---

## Dependencies

- Story 1.2 (Audio Input Selection) - for settings panel structure

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] IP and port fields work
- [ ] Validation shows errors
- [ ] Test Connection works
- [ ] Status indicator updates
- [ ] Settings persist on relaunch
- [ ] Committed to Git
