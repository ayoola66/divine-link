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

/// Manages the rolling transcript buffer with character limit
@MainActor
class TranscriptBuffer: ObservableObject {
    @Published var text: String = ""
    
    private let maxLength: Int
    
    init(maxLength: Int = 500) {
        self.maxLength = maxLength
    }
    
    /// Update the transcript text
    func update(_ newText: String) {
        var trimmedText = newText
        
        // Trim to last maxLength characters
        if trimmedText.count > maxLength {
            let startIndex = trimmedText.index(trimmedText.endIndex, offsetBy: -maxLength)
            trimmedText = String(trimmedText[startIndex...])
            
            // Try to break at a word boundary
            if let spaceIndex = trimmedText.firstIndex(of: " ") {
                trimmedText = String(trimmedText[trimmedText.index(after: spaceIndex)...])
            }
        }
        
        text = trimmedText
    }
    
    /// Clear the transcript
    func clear() {
        text = ""
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
