import SwiftUI
import AVFoundation

/// Main settings view with tabbed interface
struct SettingsView: View {
    var body: some View {
        TabView {
            AccountSettingsTab()
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }
            
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
            
            AccessibilitySettingsTab()
                .tabItem {
                    Label("Display", systemImage: "textformat.size")
                }
            
            SubscriptionSettingsTab()
                .tabItem {
                    Label("Premium", systemImage: "star.fill")
                }
            
            UpdatesSettingsTab()
                .tabItem {
                    Label("Updates", systemImage: "arrow.down.circle")
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
        .frame(width: 580, height: 540)
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

// MARK: - ProPresenter Settings Tab

struct ProPresenterSettingsTab: View {
    @StateObject private var settings = ProPresenterSettings()
    @StateObject private var client = ProPresenterClient()
    
    var body: some View {
        VStack(spacing: 0) {
            ProPresenterSettingsView(settings: settings, client: client)
            
            Divider()
            
            // Help section
            VStack(alignment: .leading, spacing: 8) {
                Text("Setup Instructions")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Open ProPresenter → Preferences → Network")
                    Text("2. Enable \"Enable Network\" toggle")
                    Text("3. Note the Port (default is 50233)")
                    Text("4. Use 127.0.0.1 if on the same Mac")
                    Text("5. Click \"Test Connection\" to verify")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}

// MARK: - Subscription Settings Tab

struct SubscriptionSettingsTab: View {
    var body: some View {
        SubscriptionSettingsView()
            .padding()
    }
}

// MARK: - Updates Settings Tab

struct UpdatesSettingsTab: View {
    var body: some View {
        UpdateSettingsView()
            .padding()
    }
}

// MARK: - Account Settings Tab

struct AccountSettingsTab: View {
    @ObservedObject private var authService = AuthService.shared
    @State private var showLoginSheet = false
    
    var body: some View {
        if authService.isAuthenticated {
            AccountView()
        } else {
            VStack(spacing: 20) {
                Image(systemName: "person.circle")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                
                Text("Sign In to Divine Link")
                    .font(.title2.bold())
                
                Text("Create an account to access premium features, sync across devices, and manage your subscription.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Sign In") {
                    showLoginSheet = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding()
            .sheet(isPresented: $showLoginSheet) {
                LoginView()
            }
        }
    }
}

// MARK: - Accessibility Settings Tab

struct AccessibilitySettingsTab: View {
    @ObservedObject private var settings = AccessibilitySettings.shared
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Font Size")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        Text("A")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        
                        Slider(
                            value: Binding(
                                get: { Double(settings.fontScaleLevel) },
                                set: { settings.fontScaleLevel = Int($0) }
                            ),
                            in: 1...5,
                            step: 1
                        )
                        .frame(maxWidth: 200)
                        
                        Text("A")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Level \(settings.fontScaleLevel): \(settings.levelDescription)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Button("Reset") {
                            settings.resetToDefault()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(settings.fontScaleLevel == 2) // Medium is default
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Display Size")
            } footer: {
                Text("Adjusts the text size throughout the app. Each level increases the font size by 2 points.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section {
                // Preview section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preview")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("John 3:16")
                            .scaledTitleFont()
                        
                        Text("For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.")
                            .scaledBodyFont()
                            .lineLimit(3)
                        
                        Text("KJV • Detected 2 minutes ago")
                            .scaledCaptionFont()
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            } header: {
                Text("Preview")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - About Tab

struct AboutTab: View {
    @ObservedObject private var cleanup = ArchiveCleanupService.shared
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
            
            Text("Version \(appVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("Build \(buildNumber)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
    
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.1"
    }
    
    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
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
