import SwiftUI

/// Main content view displayed in the menu bar popover
struct MainView: View {
    @StateObject private var audioManager = AudioDeviceManager()
    @StateObject private var audioCapture = AudioCaptureService()
    @State private var hasPermission = true
    
    var body: some View {
        VStack(spacing: 12) {
            // Header (always full colour)
            headerView
            
            Divider()
            
            // Content area with desaturation when paused
            contentArea
                .saturation(audioCapture.isCapturing ? 1.0 : 0.4)
                .animation(.easeInOut(duration: 0.3), value: audioCapture.isCapturing)
            
            Divider()
            
            // Action buttons
            actionButtons
        }
        .padding()
        .frame(width: 320, height: 280)
        .task {
            // Check microphone permission on appear
            hasPermission = await AudioCaptureService.checkPermission()
            
            // Auto-start listening if we have permission
            if hasPermission {
                audioCapture.start()
            }
        }
        // Keyboard shortcut: Space to toggle listening
        .onKeyPress(.space) {
            if hasPermission {
                audioCapture.toggle()
            }
            return .handled
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Image(systemName: "book.fill")
                .font(.title2)
                .foregroundStyle(.blue)
            
            Text("Divine Link")
                .font(.headline)
            
            Spacer()
            
            SettingsLink {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings (⌘,)")
        }
    }
    
    // MARK: - Content Area
    
    private var contentArea: some View {
        VStack(spacing: 12) {
            // Status and audio level
            statusView
            
            // Audio level indicator
            audioLevelView
            
            Divider()
            
            // Pending scripture area (placeholder)
            pendingScriptureView
        }
    }
    
    // MARK: - Status
    
    private var statusView: some View {
        HStack {
            // Listening status indicator
            Circle()
                .fill(statusColour)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(audioCapture.isCapturing ? .primary : .secondary)
            
            Spacer()
            
            // Audio device info
            if let device = audioManager.selectedDevice {
                Text(device.friendlyName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
    
    private var statusColour: Color {
        if !hasPermission {
            return .red
        } else if audioCapture.isCapturing {
            return .green
        } else {
            return .gray
        }
    }
    
    private var statusText: String {
        if !hasPermission {
            return "No Microphone Access"
        } else if audioCapture.isCapturing {
            return "Listening"
        } else {
            return "Paused"
        }
    }
    
    // MARK: - Audio Level
    
    private var audioLevelView: some View {
        VStack(spacing: 4) {
            AudioLevelIndicator(
                level: audioCapture.audioLevel,
                isListening: audioCapture.isCapturing,
                peakLevel: audioCapture.peakLevel
            )
            
            // Error message if any
            if let error = audioCapture.error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
    
    // MARK: - Pending Scripture
    
    private var pendingScriptureView: some View {
        VStack(spacing: 8) {
            if audioCapture.isCapturing {
                Text("Listening for scripture references...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Press Start or Space to begin")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: 40)
    }
    
    // MARK: - Actions
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                audioCapture.toggle()
            } label: {
                HStack {
                    Image(systemName: audioCapture.isCapturing ? "pause.fill" : "play.fill")
                    Text(audioCapture.isCapturing ? "Pause" : "Start")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(audioCapture.isCapturing ? Color.divineMuted : Color.divineBlue)
            .disabled(!hasPermission)
            .help("Space to toggle")
            
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}

#Preview {
    MainView()
}
