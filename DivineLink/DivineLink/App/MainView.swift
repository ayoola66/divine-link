import SwiftUI

/// Main content view displayed in the menu bar popover
struct MainView: View {
    @StateObject private var pipeline = DetectionPipeline()
    @State private var hasPermission = true
    @State private var showStatus = false
    
    // Observe nested objects directly for proper SwiftUI updates
    @ObservedObject private var audioCapture: AudioCaptureService
    @ObservedObject private var transcriptBuffer: TranscriptBuffer
    
    init() {
        let pipeline = DetectionPipeline()
        _pipeline = StateObject(wrappedValue: pipeline)
        _audioCapture = ObservedObject(wrappedValue: pipeline.audioCapture)
        _transcriptBuffer = ObservedObject(wrappedValue: pipeline.transcriptBuffer)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            headerView
            
            // Status indicators row
            statusIndicatorsRow
            
            Divider()
            
            // Zone 1: Listening Feed (transcript)
            ListeningFeedView(
                transcript: transcriptBuffer.text,
                isListening: pipeline.isActive
            )
            .frame(height: 60)
            
            // Zone 2: Audio level indicator
            audioLevelView
            
            Divider()
            
            // Zone 3: Pending Scripture (or placeholder)
            pendingScriptureView
            
            Divider()
            
            // Zone 4: Action buttons
            actionButtons
            
            // Expandable status panel
            if showStatus {
                statusPanel
            }
        }
        .padding(12)
        .frame(width: 340, height: showStatus ? 420 : 340)
        .animation(.easeInOut(duration: 0.2), value: showStatus)
        .saturation(pipeline.isActive ? 1.0 : 0.4)
        .animation(.easeInOut(duration: 0.3), value: pipeline.isActive)
        .task {
            // Check permissions and auto-start
            hasPermission = await AudioCaptureService.checkPermission()
            if hasPermission {
                await pipeline.start()
            }
        }
        .onKeyPress(.space) {
            Task {
                await pipeline.toggle()
            }
            return .handled
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Image(systemName: "book.fill")
                .font(.title3)
                .foregroundStyle(.blue)
            
            Text("Divine Link")
                .font(.headline)
            
            Spacer()
            
            // Status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColour)
                    .frame(width: 8, height: 8)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            SettingsLink {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings (⌘,)")
        }
    }
    
    private var statusColour: Color {
        if !hasPermission {
            return .red
        } else if pipeline.isActive {
            return .green
        } else {
            return .gray
        }
    }
    
    private var statusText: String {
        if !hasPermission {
            return "No Permission"
        } else if pipeline.isActive {
            return "Listening"
        } else {
            return "Paused"
        }
    }
    
    // MARK: - Audio Level
    
    private var audioLevelView: some View {
        AudioLevelIndicator(
            level: audioCapture.audioLevel,
            isListening: audioCapture.isCapturing,
            peakLevel: audioCapture.peakLevel
        )
        .padding(.horizontal, 4)
    }
    
    // MARK: - Pending Scripture
    
    private var pendingScriptureView: some View {
        Group {
            if let verse = pipeline.buffer.currentVerse {
                // Show pending scripture card
                PendingScriptureCard(verse: verse)
            } else {
                // Empty state
                VStack(spacing: 6) {
                    if pipeline.isActive {
                        if let lastRef = pipeline.lastDetectedReference {
                            Text("Last detected: \(lastRef)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Listening for scripture references...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Press Start or Space to begin")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .frame(height: 80)
    }
    
    // MARK: - Actions
    
    private var actionButtons: some View {
        HStack(spacing: 10) {
            // Push button (if verse pending)
            if pipeline.buffer.hasPendingVerses {
                Button {
                    // TODO: Push to ProPresenter (Epic 3)
                    pipeline.buffer.removeCurrent()
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("Push")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.divineGold)
                
                Button {
                    pipeline.buffer.ignoreCurrent()
                } label: {
                    Text("Ignore")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                // Start/Pause button
                Button {
                    Task {
                        await pipeline.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: pipeline.isActive ? "pause.fill" : "play.fill")
                        Text(pipeline.isActive ? "Pause" : "Start")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(pipeline.isActive ? Color.divineMuted : Color.divineBlue)
                .disabled(!hasPermission)
                .help("Space to toggle")
            }
            
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Status Indicators Row
    
    private var statusIndicatorsRow: some View {
        HStack(spacing: 12) {
            StatusPill(
                icon: "mic.fill",
                label: "Audio",
                isActive: audioCapture.isCapturing,
                color: .green
            )
            
            StatusPill(
                icon: "text.bubble.fill",
                label: "Speech",
                isActive: pipeline.transcription.isTranscribing,
                color: .blue
            )
            
            StatusPill(
                icon: "book.closed.fill",
                label: "Bible",
                isActive: pipeline.bible.isLoaded,
                color: .purple
            )
            
            StatusPill(
                icon: "magnifyingglass",
                label: "Detect",
                isActive: pipeline.detector.lastDetection != nil,
                color: .orange
            )
            
            Spacer()
            
            // Toggle status panel
            Button {
                showStatus.toggle()
            } label: {
                Image(systemName: showStatus ? "chevron.up.circle.fill" : "info.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Show/hide status details")
        }
        .font(.caption2)
    }
    
    // MARK: - Status Panel (Expandable)
    
    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            
            Text("System Status")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                StatusRow(label: "Audio Capture", 
                         status: audioCapture.isCapturing ? "Running" : "Stopped",
                         isOK: audioCapture.isCapturing)
                
                StatusRow(label: "Audio Level", 
                         status: String(format: "%.0f%%", audioCapture.audioLevel * 100),
                         isOK: audioCapture.audioLevel > 0.01)
                
                StatusRow(label: "Speech Recognition", 
                         status: pipeline.transcription.isTranscribing ? "Active" : "Inactive",
                         isOK: pipeline.transcription.isTranscribing)
                
                StatusRow(label: "Bible Database", 
                         status: pipeline.bible.isLoaded ? "Loaded" : "Not Found",
                         isOK: pipeline.bible.isLoaded)
                
                StatusRow(label: "Last Detection", 
                         status: pipeline.lastDetectedReference ?? "None",
                         isOK: pipeline.lastDetectedReference != nil)
                
                StatusRow(label: "Pending Verses", 
                         status: "\(pipeline.buffer.pendingCount)",
                         isOK: true)
            }
            .font(.caption2)
        }
        .padding(.top, 4)
    }
}

// MARK: - Status Pill

struct StatusPill: View {
    let icon: String
    let label: String
    let isActive: Bool
    let color: Color
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(label)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(isActive ? color.opacity(0.2) : Color.gray.opacity(0.1))
        .foregroundStyle(isActive ? color : .gray)
        .clipShape(Capsule())
    }
}

// MARK: - Status Row

struct StatusRow: View {
    let label: String
    let status: String
    let isOK: Bool
    
    var body: some View {
        HStack {
            Circle()
                .fill(isOK ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(status)
                .foregroundStyle(isOK ? .primary : .tertiary)
        }
    }
}

// MARK: - Pending Scripture Card

struct PendingScriptureCard: View {
    let verse: PendingVerse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Reference header
            HStack {
                Text(verse.displayReference)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.divineBlue)
                
                Spacer()
                
                Text(verse.translation)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            // Verse text
            Text(verse.fullText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.divineGold.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Previews

#Preview("Main View") {
    MainView()
}

#Preview("With Pending Verse") {
    let view = MainView()
    return view
}
