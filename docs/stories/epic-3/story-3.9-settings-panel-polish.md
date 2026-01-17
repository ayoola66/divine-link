# Story 3.9: Settings Panel Polish

**Epic:** 3 - Pending Buffer & ProPresenter Integration  
**Story ID:** 3.9  
**Status:** Not Started  
**Complexity:** Small  

---

## User Story

**As an** operator,  
**I want** a clean, simple settings panel,  
**so that** I can configure the app without confusion.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Settings opens in separate window or sheet | Settings appears separately |
| 2 | Sections: Audio Input, ProPresenter Connection | Both sections present |
| 3 | Clean layout with appropriate spacing | Professional appearance |
| 4 | Close button or standard window controls | Window closable |
| 5 | Changes apply immediately (no "Save" button) | Changes take effect instantly |
| 6 | Settings window closable with Escape key | Esc closes window |

---

## Technical Notes

### Complete Settings View

```swift
import SwiftUI

struct SettingsView: View {
    @StateObject private var audioManager = AudioDeviceManager()
    @StateObject private var ppSettings = ProPresenterSettings()
    @StateObject private var ppClient = ProPresenterClient()
    
    var body: some View {
        TabView {
            // Audio Settings Tab
            AudioSettingsTab(audioManager: audioManager)
                .tabItem {
                    Label("Audio", systemImage: "mic.fill")
                }
            
            // ProPresenter Settings Tab
            ProPresenterSettingsTab(
                settings: ppSettings,
                client: ppClient
            )
            .tabItem {
                Label("ProPresenter", systemImage: "tv.fill")
            }
            
            // About Tab
            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle.fill")
                }
        }
        .frame(width: 480, height: 320)
        .onExitCommand {
            // Close settings window on Escape
            NSApp.keyWindow?.close()
        }
    }
}
```

### Audio Settings Tab

```swift
struct AudioSettingsTab: View {
    @ObservedObject var audioManager: AudioDeviceManager
    
    var body: some View {
        Form {
            Section {
                Picker("Input Device", selection: $audioManager.selectedDeviceID) {
                    ForEach(audioManager.availableDevices, id: \.uniqueID) { device in
                        Text(device.localizedName)
                            .tag(device.uniqueID)
                    }
                }
                .pickerStyle(.menu)
                
                // BlackHole helper
                if !audioManager.isBlackHoleInstalled() {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Want to capture system audio?")
                                .font(.caption)
                            
                            Link("Install BlackHole (free)", 
                                 destination: URL(string: "https://existential.audio/blackhole/")!)
                                .font(.caption)
                        }
                    }
                    .padding(.top, 4)
                }
            } header: {
                Text("Audio Input")
            } footer: {
                Text("Select the audio source Divine Link should listen to.")
                    .foregroundColor(.secondary)
            }
            
            Section {
                // Audio level test
                HStack {
                    Text("Input Level")
                    Spacer()
                    AudioLevelIndicator(
                        level: audioManager.currentLevel,
                        isListening: true
                    )
                    .frame(width: 100)
                }
            } header: {
                Text("Test")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            audioManager.refreshDevices()
        }
    }
}
```

### ProPresenter Settings Tab

```swift
struct ProPresenterSettingsTab: View {
    @ObservedObject var settings: ProPresenterSettings
    @ObservedObject var client: ProPresenterClient
    
    @State private var isTesting = false
    
    var body: some View {
        Form {
            Section {
                TextField("IP Address", text: $settings.ipAddress)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    Text("Port")
                    Spacer()
                    TextField("", value: $settings.port, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            } header: {
                Text("Connection")
            } footer: {
                Text("Enter the IP address and port of your ProPresenter computer.")
                    .foregroundColor(.secondary)
            }
            
            Section {
                HStack {
                    // Status indicator
                    Circle()
                        .fill(client.connectionStatus.color)
                        .frame(width: 10, height: 10)
                    
                    Text(client.connectionStatus.displayText)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(isTesting ? "Testing..." : "Test Connection") {
                        testConnection()
                    }
                    .disabled(!settings.isValid || isTesting)
                }
            } header: {
                Text("Status")
            }
        }
        .formStyle(.grouped)
    }
    
    private func testConnection() {
        guard let url = settings.connectionURL else { return }
        
        isTesting = true
        
        Task {
            do {
                _ = try await client.testConnection(to: url)
            } catch {
                // Error handled in client
            }
            isTesting = false
        }
    }
}
```

### About Tab

```swift
struct AboutTab: View {
    var body: some View {
        VStack(spacing: 20) {
            // App icon
            Image("AppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .cornerRadius(16)
            
            // App name and version
            VStack(spacing: 4) {
                Text("Divine Link")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Version \(Bundle.main.appVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Description
            Text("Real-time scripture detection for ProPresenter")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            // Copyright
            Text("© 2026 Divine Link")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
```

### Window Styling

```swift
@main
struct DivineLink: App {
    var body: some Scene {
        // Main window
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        
        // Settings window
        Settings {
            SettingsView()
        }
    }
}
```

---

## Dependencies

- Story 1.2 (Audio Input Selection)
- Story 3.5 (ProPresenter Connection Settings)

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] Both tabs present and functional
- [ ] Clean, professional layout
- [ ] Escape closes settings
- [ ] Changes apply immediately
- [ ] About tab shows version
- [ ] Committed to Git

---

## MVP Complete

This is the final story for the Divine Link MVP. Upon completion:

- ✅ Epic 1: Foundation & Audio Capture
- ✅ Epic 2: Transcription & Scripture Detection  
- ✅ Epic 3: Pending Buffer & ProPresenter Integration

**Divine Link is ready for user testing.**
