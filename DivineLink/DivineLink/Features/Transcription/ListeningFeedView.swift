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
    /// Seconds of speech-silence before the current phrase is committed to its own line.
    /// A pause = a new line — this is what makes the transcript easy to follow.
    private let sentencePauseInterval: TimeInterval = 1.4
    private var sentenceTimer: Timer?

    /// Full cumulative text of the CURRENT STT session. Apple reports each partial as
    /// the entire transcript-so-far for the active session, then resets to a short
    /// partial when a new session begins (seamless handoff).
    private var sessionCumulative: String = ""
    /// The portion of `sessionCumulative` already committed to `lines`. Everything
    /// after it is the live, uncommitted phrase. Tracking this DELTA (instead of
    /// committing whole cumulative snapshots) is what lets us break a new line at each
    /// pause WITHOUT the old duplication bug.
    private var committedPrefix: String = ""

    init(maxLength: Int = 500, maxLines: Int = 300) {
        self.maxLength = maxLength
        self.maxLines = maxLines
    }

    /// Update from an STT partial (cumulative within a session).
    func update(_ newText: String) {
        if committedPrefix.isEmpty || newText.hasPrefix(committedPrefix) {
            // Fresh session, or the same session growing normally.
            sessionCumulative = newText
        } else if newText.count < committedPrefix.count {
            // New STT session (cumulative reset shorter) with no explicit isFinal:
            // commit the previous session's trailing phrase, then start fresh.
            commitDelta()
            committedPrefix = ""
            sessionCumulative = newText
        } else {
            // Apple revised words inside the already-committed region — resync on the
            // longest common prefix so the live delta stays correct.
            committedPrefix = String(commonPrefix(committedPrefix, newText))
            sessionCumulative = newText
        }

        text = displayTrimmed(currentDelta())
        scheduleSentenceCommit()
    }

    /// The live (uncommitted) phrase = session text beyond what's already committed.
    private func currentDelta() -> String {
        guard sessionCumulative.hasPrefix(committedPrefix) else { return sessionCumulative }
        return String(sessionCumulative.dropFirst(committedPrefix.count))
            .trimmingCharacters(in: .whitespaces)
    }

    /// Restart the pause timer; when it fires, the current phrase becomes its own line.
    private func scheduleSentenceCommit() {
        sentenceTimer?.invalidate()
        guard !currentDelta().isEmpty else { return }
        sentenceTimer = Timer.scheduledTimer(withTimeInterval: sentencePauseInterval, repeats: false) { [weak self] _ in
            // Timer is scheduled on the main run loop from this @MainActor method.
            MainActor.assumeIsolated { self?.commitDelta() }
        }
    }

    /// Commit the current live phrase as one finalised line (called on a pause, on
    /// isFinal, on a session change, or on stop). Idempotent when nothing is pending.
    private func commitDelta() {
        let delta = currentDelta()
        guard !delta.isEmpty else { return }
        lines.append(TranscriptLine(text: delta))
        if lines.count > maxLines { lines.removeFirst() }
        committedPrefix = sessionCumulative
        text = ""
    }

    /// Trim the live phrase to the rolling character budget (display only).
    private func displayTrimmed(_ newText: String) -> String {
        guard newText.count > maxLength else { return newText }
        var t = String(newText[newText.index(newText.endIndex, offsetBy: -maxLength)...])
        if let space = t.firstIndex(of: " ") { t = String(t[t.index(after: space)...]) }
        return t
    }

    /// Longest common character prefix of two strings.
    private func commonPrefix(_ a: String, _ b: String) -> Substring {
        var count = 0
        for (x, y) in zip(a, b) { if x == y { count += 1 } else { break } }
        return a.prefix(count)
    }

    /// Called on an explicit isFinal STT result: commit the trailing phrase and reset.
    func appendFinalLine(_ newText: String) {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, newText.hasPrefix(committedPrefix) {
            sessionCumulative = newText
        }
        commitDelta()
        committedPrefix = ""
        sessionCumulative = ""
        text = ""
    }

    /// Promote the current phrase to a line. Called when transcription actually STOPS.
    func finalizeInProgressText() {
        commitDelta()
        committedPrefix = ""
        sessionCumulative = ""
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
        committedPrefix = ""
        sessionCumulative = ""
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
