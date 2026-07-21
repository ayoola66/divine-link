import SwiftUI
import Combine

// MARK: - Colour Constants (per UI Spec)

extension Color {
    static let divineBlue = Color(red: 0.23, green: 0.51, blue: 0.96)  // #3B82F6
    static let divineGold = Color(red: 0.83, green: 0.69, blue: 0.22)  // #D4AF37
    static let divineMuted = Color(red: 0.61, green: 0.64, blue: 0.69) // #9CA3AF
}

// MARK: - Audio Level Indicator

/// Visual indicator showing real-time audio input level
struct AudioLevelIndicator: View {
    /// Audio level from 0.0 to 1.0
    let level: Float
    
    /// Whether the app is actively listening
    let isListening: Bool
    
    /// Peak level for peak indicator
    var peakLevel: Float = 0.0
    
    @State private var pulseOpacity: Double = 0.3
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                
                // Level bar with gradient
                RoundedRectangle(cornerRadius: 4)
                    .fill(levelGradient)
                    .frame(width: max(4, geometry.size.width * CGFloat(min(level, 1.0))))
                    .animation(.easeOut(duration: 0.05), value: level)
                
                // Peak indicator line
                if peakLevel > 0.05 {
                    Rectangle()
                        .fill(Color.divineBlue.opacity(0.8))
                        .frame(width: 2)
                        .offset(x: geometry.size.width * CGFloat(min(peakLevel, 1.0)) - 1)
                        .animation(.easeOut(duration: 0.1), value: peakLevel)
                }
                
                // Pulse overlay when listening
                if isListening {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.divineBlue.opacity(pulseOpacity))
                        .onAppear {
                            withAnimation(
                                .easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true)
                            ) {
                                pulseOpacity = 0.1
                            }
                        }
                        .onDisappear {
                            pulseOpacity = 0.3
                        }
                }
            }
        }
        .frame(height: 8)
    }
    
    /// Gradient that changes colour based on level
    private var levelGradient: LinearGradient {
        let colors: [Color]
        
        if level < 0.6 {
            colors = [Color.divineBlue, Color.divineBlue]
        } else if level < 0.85 {
            colors = [Color.divineBlue, Color.divineGold]
        } else {
            colors = [Color.divineBlue, Color.divineGold, Color.red.opacity(0.8)]
        }
        
        return LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Compact Audio Level Indicator

/// Smaller version for use in the main popover
struct CompactAudioLevelIndicator: View {
    let level: Float
    let isListening: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            // Microphone icon with pulse
            Image(systemName: isListening ? "mic.fill" : "mic.slash.fill")
                .foregroundStyle(isListening ? Color.divineBlue : Color.divineMuted)
                .font(.caption)
            
            // Level bar
            AudioLevelIndicator(level: level, isListening: isListening)
                .frame(width: 60)
        }
    }
}

// MARK: - Engine Loading Banner

/// Small status line shown ABOVE the soundbar while the transcription engine starts up.
///
/// Shows "Engine loading, standby…" for at least a few seconds — even when the engine is
/// effectively instant (Apple STT on Intel) — then flips to "Ready" once the engine can
/// actually produce text (on Apple Silicon, only after the WhisperKit model finishes
/// loading), then clears so the soundbar takes over. Appears once per launch / restart.
struct EngineLoadingBanner: View {
    @ObservedObject var service: TranscriptionService

    @State private var phase: Phase = .loading
    @State private var minElapsed = false
    private enum Phase { case loading, ready, live }

    /// Minimum time the "loading" message stays visible, even if the engine is instant.
    private let minLoadingSeconds: Double = 3.0
    /// How long "Ready" shows before it clears.
    private let readySeconds: Double = 1.5
    /// Safety net — never stay stuck on "loading" if the engine never reports ready.
    private let maxLoadingSeconds: Double = 30.0

    var body: some View {
        Group {
            switch phase {
            case .loading:
                banner(text: "Engine loading, standby…", systemImage: "hourglass", tint: .orange, showSpinner: true)
            case .ready:
                banner(text: "Ready", systemImage: "checkmark.circle.fill", tint: .green, showSpinner: false)
            case .live:
                EmptyView()
            }
        }
        .onAppear { startSequence() }
        .onChange(of: service.engineReady) { _, _ in advanceIfReady() }
    }

    private func startSequence() {
        phase = .loading
        minElapsed = false
        DispatchQueue.main.asyncAfter(deadline: .now() + minLoadingSeconds) {
            minElapsed = true
            advanceIfReady()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + maxLoadingSeconds) {
            if phase == .loading { showReadyThenClear() }
        }
    }

    private func advanceIfReady() {
        guard phase == .loading, minElapsed, service.engineReady else { return }
        showReadyThenClear()
    }

    private func showReadyThenClear() {
        guard phase == .loading else { return }
        withAnimation(.easeInOut(duration: 0.25)) { phase = .ready }
        DispatchQueue.main.asyncAfter(deadline: .now() + readySeconds) {
            withAnimation(.easeInOut(duration: 0.3)) { phase = .live }
        }
    }

    @ViewBuilder
    private func banner(text: String, systemImage: String, tint: Color, showSpinner: Bool) -> some View {
        HStack(spacing: 6) {
            if showSpinner {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            } else {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
            }
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 2)
        .transition(.opacity)
    }
}

// MARK: - Previews

#Preview("Audio Level - Low") {
    VStack(spacing: 20) {
        AudioLevelIndicator(level: 0.2, isListening: true)
        AudioLevelIndicator(level: 0.5, isListening: true)
        AudioLevelIndicator(level: 0.8, isListening: true)
        AudioLevelIndicator(level: 0.95, isListening: true)
        AudioLevelIndicator(level: 0.0, isListening: false)
    }
    .padding()
    .frame(width: 300)
}

#Preview("Compact Indicator") {
    VStack(spacing: 20) {
        CompactAudioLevelIndicator(level: 0.3, isListening: true)
        CompactAudioLevelIndicator(level: 0.0, isListening: false)
    }
    .padding()
}
