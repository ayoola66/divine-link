import SwiftUI
import AVFoundation

/// Main settings view with tabbed interface
struct SettingsView: View {
    var body: some View {
        TabView {
            AudioSettingsTab()
                .tabItem {
                    Label("Audio", systemImage: "waveform")
                }
            
            ProPresenterSettingsTab()
                .tabItem {
                    Label("ProPresenter", systemImage: "tv")
                }
            
            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 380)
    }
}

// MARK: - Audio Settings Tab

struct AudioSettingsTab: View {
    @StateObject private var audioManager = AudioDeviceManager()
    
    var body: some View {
        Form {
            Section {
                Picker("Input Device", selection: $audioManager.selectedDevice) {
                    ForEach(audioManager.availableDevices, id: \.uniqueID) { device in
                        Text(device.friendlyName)
                            .tag(device as AVCaptureDevice?)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: audioManager.selectedDevice) { oldValue, newValue in
                    if let device = newValue {
                        Task {
                            await audioManager.selectDevice(device)
                        }
                    }
                }
                
                Button("Refresh Devices") {
                    Task {
                        await audioManager.refreshDevices()
                    }
                }
                .disabled(audioManager.isRefreshing)
            } header: {
                Text("Audio Input")
            } footer: {
                if audioManager.availableDevices.isEmpty {
                    Text("No audio input devices found.")
                        .foregroundStyle(.secondary)
                }
            }
            
            Section {
                if audioManager.isBlackHoleInstalled {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("BlackHole is installed")
                            .foregroundStyle(.secondary)
                    }
                    
                    if !audioManager.blackHoleDevices.isEmpty {
                        Text("Available: \(audioManager.blackHoleDevices.map { $0.friendlyName }.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text("BlackHole not detected")
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("BlackHole is required to capture system audio (e.g., from ProPresenter or a stream).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Link(destination: AudioDeviceManager.blackHoleURL) {
                            HStack {
                                Image(systemName: "arrow.up.right.square")
                                Text("Install BlackHole")
                            }
                        }
                        .font(.caption)
                    }
                }
            } header: {
                Text("System Audio Capture")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - ProPresenter Settings Tab (Placeholder)

struct ProPresenterSettingsTab: View {
    @AppStorage("proPresenterHost") private var host: String = "localhost"
    @AppStorage("proPresenterPort") private var port: String = "1025"
    
    var body: some View {
        Form {
            Section {
                TextField("Host", text: $host)
                TextField("Port", text: $port)
            } header: {
                Text("Connection")
            } footer: {
                Text("ProPresenter must have Network enabled in Preferences → Network.")
                    .foregroundStyle(.secondary)
            }
            
            Section {
                Button("Test Connection") {
                    // TODO: Implement connection test in Story 2.x
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - About Tab

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            // Use the app icon from the asset catalog
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
            }
            
            Text("Divine Link")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Version 1.0.0")
                .foregroundStyle(.secondary)
            
            Text("Real-time scripture detection for live church services.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Spacer()
            
            Text("© 2026 Divine Link. All rights reserved.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#Preview("Settings") {
    SettingsView()
}

#Preview("Audio Tab") {
    AudioSettingsTab()
        .frame(width: 450, height: 300)
}
