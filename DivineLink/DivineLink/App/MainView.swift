import SwiftUI

/// Main content view displayed in the menu bar popover
struct MainView: View {
    @StateObject private var pipeline = DetectionPipeline()
    @State private var hasPermission = true
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            headerView
            
            Divider()
            
            // Zone 1: Listening Feed (transcript)
            ListeningFeedView(
                transcript: pipeline.transcriptBuffer.text,
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
        }
        .padding(12)
        .frame(width: 340, height: 320)
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
            level: pipeline.audioCapture.audioLevel,
            isListening: pipeline.isActive,
            peakLevel: pipeline.audioCapture.peakLevel
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
