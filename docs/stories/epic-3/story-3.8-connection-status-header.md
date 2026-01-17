# Story 3.8: Connection Status Header

**Epic:** 3 - Pending Buffer & ProPresenter Integration  
**Story ID:** 3.8  
**Status:** Not Started  
**Complexity:** Small  

---

## User Story

**As an** operator,  
**I want** to see the ProPresenter connection status,  
**so that** I know if pushes will work.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Header bar shows connection status icon | Icon visible in header |
| 2 | Connected: Green dot or checkmark | Green indicator when connected |
| 3 | Disconnected: Red dot or warning icon | Red indicator when disconnected |
| 4 | Reconnecting: Amber/pulsing indicator | Amber indicator when reconnecting |
| 5 | Hovering shows tooltip with details | Tooltip shows IP:port |
| 6 | Status updates in real-time | Indicator changes with connection |

---

## Technical Notes

### Header View with Status

```swift
import SwiftUI

struct HeaderView: View {
    let status: String
    @ObservedObject var ppClient: ProPresenterClient
    @ObservedObject var ppSettings: ProPresenterSettings
    
    var body: some View {
        HStack {
            // Logo
            Image("LogoMark")
                .resizable()
                .scaledToFit()
                .frame(height: 20)
            
            Spacer()
            
            // Status text
            Text(status)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // ProPresenter connection status
            ConnectionStatusIndicator(
                status: ppClient.connectionStatus,
                ipAddress: ppSettings.ipAddress,
                port: ppSettings.port
            )
            
            // Settings button
            Button(action: openSettings) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
```

### Connection Status Indicator

```swift
struct ConnectionStatusIndicator: View {
    let status: ConnectionStatus
    let ipAddress: String
    let port: Int
    
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .opacity(isPulsing ? 0.5 : 1.0)
                .animation(pulseAnimation, value: isPulsing)
                .onAppear {
                    if status == .testing {
                        isPulsing = true
                    }
                }
                .onChange(of: status) { newStatus in
                    isPulsing = newStatus == .testing
                }
            
            // Status icon
            Image(systemName: statusIcon)
                .font(.system(size: 12))
                .foregroundColor(statusColor)
        }
        .help(tooltipText)
    }
    
    private var statusColor: Color {
        switch status {
        case .connected:
            return .green
        case .disconnected, .error:
            return .red
        case .testing:
            return .orange
        case .unknown:
            return .gray
        }
    }
    
    private var statusIcon: String {
        switch status {
        case .connected:
            return "checkmark.circle.fill"
        case .disconnected:
            return "xmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .testing:
            return "arrow.triangle.2.circlepath"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    private var tooltipText: String {
        let statusText: String
        switch status {
        case .connected:
            statusText = "Connected"
        case .disconnected:
            statusText = "Disconnected"
        case .error(let message):
            statusText = "Error: \(message)"
        case .testing:
            statusText = "Connecting..."
        case .unknown:
            statusText = "Not configured"
        }
        
        return "ProPresenter: \(statusText)\n\(ipAddress):\(port)"
    }
    
    private var pulseAnimation: Animation? {
        status == .testing 
            ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
            : nil
    }
}
```

### Connection Status Enum (Extended)

```swift
enum ConnectionStatus: Equatable {
    case unknown
    case testing
    case connected
    case disconnected
    case error(String)
    
    static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown),
             (.testing, .testing),
             (.connected, .connected),
             (.disconnected, .disconnected):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}
```

### Real-time Status Updates

```swift
struct ContentView: View {
    @StateObject private var ppClient = ProPresenterClient()
    @StateObject private var ppSettings = ProPresenterSettings()
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                status: appState.listeningState.statusText,
                ppClient: ppClient,
                ppSettings: ppSettings
            )
            
            // ... rest of UI
        }
        .onAppear {
            // Configure client with saved settings
            if let url = ppSettings.connectionURL {
                ppClient.configure(baseURL: url)
            }
        }
        .onChange(of: ppSettings.ipAddress) { _ in
            updateClientConfiguration()
        }
        .onChange(of: ppSettings.port) { _ in
            updateClientConfiguration()
        }
    }
    
    private func updateClientConfiguration() {
        if let url = ppSettings.connectionURL {
            ppClient.configure(baseURL: url)
        }
    }
}
```

---

## Dependencies

- Story 3.6 (ProPresenter API Client)

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] Status indicator visible in header
- [ ] Correct colours for each state
- [ ] Pulsing animation when testing
- [ ] Tooltip shows connection details
- [ ] Real-time updates working
- [ ] Committed to Git
