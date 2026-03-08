import SwiftUI
import Combine

// MARK: - Listening Feed View

/// Displays the live transcript in Zone 1 (top area)
struct ListeningFeedView: View {
    let transcript: String
    let isListening: Bool
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if transcript.isEmpty {
                        emptyState
                    } else {
                        Text(transcript)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.disabled)
                    }
                    
                    // Anchor for scrolling to bottom
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .onChange(of: transcript) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private var emptyState: some View {
        Group {
            if isListening {
                Text("Listening for speech...")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                Text("Paused")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Transcript Buffer

/// A single finalised transcript chunk (one STT result marked isFinal).
struct TranscriptLine: Identifiable {
    let id: UUID
    let text: String
    let timestamp: Date

    init(text: String) {
        self.id = UUID()
        self.text = text
        self.timestamp = Date()
    }
}

/// Manages the rolling transcript buffer with character limit and full-session history.
@MainActor
class TranscriptBuffer: ObservableObject {
    /// Current in-progress (non-final) transcription chunk shown live.
    @Published var text: String = ""
    /// Accumulated final transcript lines for the session.
    @Published var lines: [TranscriptLine] = []

    private let maxLength: Int
    private let maxLines: Int
    /// Seconds of silence before a non-final partial is treated as a completed sentence.
    private let sentencePauseInterval: TimeInterval = 1.5
    private var sentenceTimer: Timer?

    init(maxLength: Int = 500, maxLines: Int = 300) {
        self.maxLength = maxLength
        self.maxLines = maxLines
    }

    /// Update the rolling in-progress text (called for every STT segment).
    /// Restarts the sentence-boundary timer — if no new update arrives within
    /// sentencePauseInterval seconds the current partial is committed as a final line.
    func update(_ newText: String) {
        var trimmedText = newText
        if trimmedText.count > maxLength {
            let startIndex = trimmedText.index(trimmedText.endIndex, offsetBy: -maxLength)
            trimmedText = String(trimmedText[startIndex...])
            if let spaceIndex = trimmedText.firstIndex(of: " ") {
                trimmedText = String(trimmedText[trimmedText.index(after: spaceIndex)...])
            }
        }
        text = trimmedText

        // Restart the silence timer on every new partial
        sentenceTimer?.invalidate()
        guard !trimmedText.isEmpty else { return }
        sentenceTimer = Timer.scheduledTimer(
            withTimeInterval: sentencePauseInterval,
            repeats: false
        ) { [weak self] _ in
            self?.finalizeInProgressText()
        }
    }

    /// Append a finalised transcript line to the session history.
    func appendFinalLine(_ newText: String) {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            // STT session ended with empty final (cancel/timeout) — salvage in-progress text
            finalizeInProgressText()
        } else {
            lines.append(TranscriptLine(text: trimmed))
            if lines.count > maxLines { lines.removeFirst() }
            text = ""
        }
    }

    /// Promotes whatever in-progress text exists to a final line.
    /// Called when the STT session ends without producing a non-empty final result.
    func finalizeInProgressText() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { text = ""; return }
        lines.append(TranscriptLine(text: trimmed))
        if lines.count > maxLines { lines.removeFirst() }
        text = ""
    }

    /// Full transcript text for the session (all finalised lines joined).
    var fullTranscript: String {
        lines.map(\.text).joined(separator: " ")
    }

    /// Clear all transcript state (called on Clear or new session).
    func clear() {
        sentenceTimer?.invalidate()
        sentenceTimer = nil
        text = ""
        lines = []
    }
}

// MARK: - Previews

#Preview("Listening with text") {
    ListeningFeedView(
        transcript: "For God so loved the world that he gave his only begotten son that whoever believes in him shall not perish but have everlasting life. John 3:16 is one of the most famous verses.",
        isListening: true
    )
    .frame(width: 300, height: 80)
    .padding()
}

#Preview("Listening empty") {
    ListeningFeedView(transcript: "", isListening: true)
        .frame(width: 300, height: 80)
        .padding()
}

#Preview("Paused") {
    ListeningFeedView(transcript: "", isListening: false)
        .frame(width: 300, height: 80)
        .padding()
}
