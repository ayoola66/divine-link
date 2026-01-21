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
            
            PastorProfilesTab()
                .tabItem {
                    Label("Pastors", systemImage: "person.2")
                }
            
            ServiceHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            
            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 420)
    }
}

// MARK: - Audio Settings Tab

struct AudioSettingsTab: View {
    @StateObject private var audioManager = AudioDeviceManager()
    @StateObject private var audioTest = AudioCaptureService()
    @State private var isTesting = false
    
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
                            // Restart test if active
                            if isTesting {
                                audioTest.stop()
                                audioTest.start()
                            }
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
            
            // Audio Level Test Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button(isTesting ? "Stop Test" : "Test Audio") {
                            if isTesting {
                                audioTest.stop()
                            } else {
                                audioTest.start()
                            }
                            isTesting.toggle()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isTesting ? .red : .blue)
                        
                        Spacer()
                        
                        if isTesting {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 8, height: 8)
                                    .opacity(audioTest.audioLevel > 0.05 ? 1.0 : 0.3)
                                Text("Listening")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if isTesting {
                        // Audio level bar
                        VStack(alignment: .leading, spacing: 4) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    // Background
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                    
                                    // Level bar
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(levelColor)
                                        .frame(width: max(4, geo.size.width * CGFloat(audioTest.audioLevel)))
                                        .animation(.easeOut(duration: 0.1), value: audioTest.audioLevel)
                                }
                            }
                            .frame(height: 20)
                            
                            Text("Speak or make noise to test the microphone")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let error = audioTest.error {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error.localizedDescription)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            } header: {
                Text("Audio Level Test")
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
        .onDisappear {
            // Stop testing when leaving the tab
            if isTesting {
                audioTest.stop()
            }
        }
    }
    
    private var levelColor: Color {
        if audioTest.audioLevel < 0.6 {
            return .green
        } else if audioTest.audioLevel < 0.85 {
            return .yellow
        } else {
            return .red
        }
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
    @StateObject private var cleanup = ArchiveCleanupService.shared
    @State private var showCleanupConfirmation = false
    
    var body: some View {
        VStack(spacing: 16) {
            // App info section
            appInfoSection
            
            Divider()
            
            // Storage section
            storageSection
            
            Spacer()
            
            Text("© 2026 Divine Link. All rights reserved.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Clean Up Storage?", isPresented: $showCleanupConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Old Sessions", role: .destructive) {
                cleanup.performCleanup()
            }
        } message: {
            Text("This will delete all services older than 90 days.")
        }
    }
    
    private var appInfoSection: some View {
        VStack(spacing: 12) {
            // Use the app icon from the asset catalog
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
            }
            
            Text("Divine Link")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Version 1.0.0")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Services:")
                        .foregroundStyle(.secondary)
                    Text("\(cleanup.totalSessionCount)")
                }
                
                GridRow {
                    Text("Scriptures:")
                        .foregroundStyle(.secondary)
                    Text("\(cleanup.totalScriptureCount)")
                }
                
                GridRow {
                    Text("Storage used:")
                        .foregroundStyle(.secondary)
                    Text(cleanup.formattedStorageSize)
                }
                
                if cleanup.expiredSessionCount > 0 {
                    GridRow {
                        Text("Expired:")
                            .foregroundStyle(.orange)
                        Text("\(cleanup.expiredSessionCount) sessions")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .font(.callout)
            
            HStack {
                Text("Sessions kept for 90 days")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                Spacer()
                
                Button {
                    showCleanupConfirmation = true
                } label: {
                    Label("Clean Up", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
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
