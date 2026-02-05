# Story 7.2: Implicit Detection (AI-Powered)

**Epic:** 7 - Advanced Detection & Personalisation  
**Story ID:** 7.2  
**Status:** ⚠️ Partially Complete (Basic phrase-matching only)  
**Complexity:** Large  
**Priority:** P1 (Love Tier Feature)

**Current Implementation:**
- `DivineLink/Features/Detection/ImplicitReferenceDetector.swift` - Basic phrase matching for famous verses

**Remaining Work:**
- MLX Framework integration for true AI-powered detection
- Detection of phrases like "the verse we just read" using LLM context
- Quantised model (Llama-3/Mistral) integration

---

## User Story

**As an** operator during a sermon,  
**I want** the app to detect implicit scripture references,  
**so that** when the pastor says "the verse we just read" or quotes without citation, the correct scripture is displayed.

---

## Background

**The Problem:**
Pastors often reference scriptures implicitly:
- "The verse we just read tells us..."
- "Going back to that passage..."
- "As Paul said, 'I can do all things through Christ...'"
- "Remember what Jesus said about the lilies?"

These references are currently undetectable because there's no explicit citation.

**The Solution:**
Use a local LLM (via Apple MLX framework) to:
1. Detect implicit reference phrases
2. Match quoted text to scripture
3. Reference the last-pushed verse history

**Professor BMAD:**
> "Use a local LLM (like a quantized Llama-3 or Mistral) via Apple's MLX framework to detect when a pastor says 'the verse we just read' without incurring cloud costs."

This is the **"Love Tier" selling point**.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | "The verse we just read" triggers last pushed verse | Correct verse re-displayed |
| 2 | "That passage" / "going back" triggers recent reference | Context-aware recall |
| 3 | Quoted text matched to scripture | "I can do all things..." → Phil 4:13 |
| 4 | Famous verse detection | "For God so loved the world" → John 3:16 |
| 5 | All processing is local (no cloud) | Works offline |
| 6 | Latency under 500ms for detection | Real-time usable |
| 7 | Implicit matches flagged in UI | "AI-detected" badge |
| 8 | Confidence scoring for implicit matches | May be lower than explicit |
| 9 | Feature can be disabled in Settings | Optional enhancement |
| 10 | Model download is optional | App works without AI model |

---

## Technical Notes

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                  Implicit Detection Pipeline                     │
│                                                                  │
│  Transcript → ┌─────────────────────────────────────────────┐   │
│               │         Implicit Detector                    │   │
│               │  ┌───────────────────────────────────────┐  │   │
│               │  │ 1. Phrase Pattern Matching            │  │   │
│               │  │    "the verse we just read"           │  │   │
│               │  │    → Check verse history              │  │   │
│               │  ├───────────────────────────────────────┤  │   │
│               │  │ 2. Quote Matching (MLX LLM)           │  │   │
│               │  │    "I can do all things..."           │  │   │
│               │  │    → Match against Bible corpus       │  │   │
│               │  ├───────────────────────────────────────┤  │   │
│               │  │ 3. Famous Verse Detection             │  │   │
│               │  │    Known phrases → Known verses       │  │   │
│               │  └───────────────────────────────────────┘  │   │
│               └─────────────────────────────────────────────┘   │
│                                    │                             │
│                                    ▼                             │
│                           Scripture Match                        │
│                   (sourceType: .implicit, lower confidence)      │
└─────────────────────────────────────────────────────────────────┘
```

### Apple MLX Framework Integration

```swift
// MLXService.swift
import MLX
import MLXRandom
import MLXNN

class MLXScriptureDetector: ObservableObject {
    @Published var isModelLoaded = false
    @Published var isProcessing = false
    
    private var model: TextModel?
    private let modelPath = "models/llama-3-8b-scripture"
    
    // MARK: - Model Loading
    
    func loadModel() async throws {
        // Load quantized Llama-3 or Mistral model
        let config = ModelConfig(path: modelPath, quantization: .q4)
        model = try await TextModel.load(configuration: config)
        await MainActor.run { isModelLoaded = true }
    }
    
    func unloadModel() {
        model = nil
        isModelLoaded = false
    }
    
    // MARK: - Quote Detection
    
    func detectQuotedScripture(text: String) async -> ScriptureQuoteMatch? {
        guard let model = model else { return nil }
        
        await MainActor.run { isProcessing = true }
        defer { Task { await MainActor.run { isProcessing = false } } }
        
        let prompt = """
        You are a Bible verse detector. Given the following text, determine if it contains a direct or paraphrased Bible quote. If it does, respond with ONLY the book, chapter, and verse reference in the format "Book Chapter:Verse". If it doesn't contain a Bible quote, respond with "NONE".
        
        Text: "\(text)"
        
        Reference:
        """
        
        let response = try? await model.generate(prompt: prompt, maxTokens: 20)
        
        guard let response = response,
              response != "NONE" else {
            return nil
        }
        
        return parseReference(response)
    }
    
    // MARK: - Similarity Search
    
    func findSimilarVerse(text: String, in corpus: BibleCorpus) async -> ScriptureMatch? {
        guard let model = model else { return nil }
        
        // Generate embedding for input text
        let inputEmbedding = try? await model.embed(text)
        
        guard let embedding = inputEmbedding else { return nil }
        
        // Find most similar verse in corpus
        var bestMatch: (verse: BibleVerse, similarity: Float)?
        
        for verse in corpus.verses {
            let similarity = cosineSimilarity(embedding, verse.embedding)
            if similarity > (bestMatch?.similarity ?? 0.7) {
                bestMatch = (verse, similarity)
            }
        }
        
        guard let match = bestMatch, match.similarity > 0.85 else {
            return nil
        }
        
        return ScriptureMatch(
            book: match.verse.book,
            chapter: match.verse.chapter,
            verse: match.verse.verse,
            verseText: match.verse.text,
            confidence: buildImplicitConfidence(similarity: match.similarity),
            sourceType: .implicit
        )
    }
}
```

### Phrase Pattern Detection (No LLM Required)

```swift
// ImplicitPhraseDetector.swift
class ImplicitPhraseDetector {
    
    // Patterns that refer to recent verses
    let recallPatterns = [
        "the verse we just read",
        "that verse",
        "that passage",
        "going back to",
        "as we saw in",
        "remember when (we read|he said|it says)",
        "back to verse",
        "earlier in"
    ]
    
    // Famous verse patterns (hardcoded for speed)
    let famousVersePatterns: [(pattern: String, reference: String)] = [
        ("for god so loved the world", "John 3:16"),
        ("i can do all things through christ", "Philippians 4:13"),
        ("the lord is my shepherd", "Psalm 23:1"),
        ("in the beginning god created", "Genesis 1:1"),
        ("love is patient.? love is kind", "1 Corinthians 13:4"),
        ("be strong and courageous", "Joshua 1:9"),
        ("trust in the lord with all", "Proverbs 3:5"),
        ("i am the way.? the truth", "John 14:6"),
        ("faith without works is dead", "James 2:26"),
        ("blessed are the poor in spirit", "Matthew 5:3"),
    ]
    
    @Published var verseHistory: [ScriptureMatch] = []
    
    // MARK: - Detection
    
    func detectImplicitReference(in text: String) -> ImplicitMatch? {
        let lowercased = text.lowercased()
        
        // 1. Check for recall patterns
        for pattern in recallPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                
                // Return last pushed verse
                if let lastVerse = verseHistory.last {
                    return ImplicitMatch(
                        type: .recall,
                        resolvedReference: lastVerse,
                        matchedPhrase: pattern
                    )
                }
            }
        }
        
        // 2. Check for famous verse patterns
        for (pattern, reference) in famousVersePatterns {
            if lowercased.contains(pattern) {
                return ImplicitMatch(
                    type: .famousVerse,
                    referenceString: reference,
                    matchedPhrase: pattern
                )
            }
        }
        
        return nil
    }
    
    // MARK: - History Management
    
    func recordPushedVerse(_ match: ScriptureMatch) {
        verseHistory.append(match)
        
        // Keep last 10 verses
        if verseHistory.count > 10 {
            verseHistory.removeFirst()
        }
    }
}

struct ImplicitMatch {
    enum MatchType {
        case recall       // "The verse we just read"
        case famousVerse  // "For God so loved the world"
        case quotation    // Direct quote detected by LLM
    }
    
    let type: MatchType
    var resolvedReference: ScriptureMatch?
    var referenceString: String?
    let matchedPhrase: String
}
```

### Integration with Detection Engine

```swift
// ScriptureDetectionEngine.swift (updated)
class ScriptureDetectionEngine: ObservableObject {
    let phraseDetector = ImplicitPhraseDetector()
    let mlxDetector: MLXScriptureDetector?
    
    @AppStorage("enableImplicitDetection") var enableImplicit = true
    @AppStorage("enableAIQuoteDetection") var enableAIQuote = true
    
    func detectReferences(in text: String) -> [ScriptureMatch] {
        var matches: [ScriptureMatch] = []
        
        // 1. Explicit references (existing)
        matches.append(contentsOf: detectExplicitReferences(in: text))
        
        // 2. Stateful context (Story 7.1)
        if referenceBuffer.isActive {
            matches.append(contentsOf: detectPartialReferences(in: text))
        }
        
        // 3. Implicit references (this story)
        if enableImplicit {
            if let implicit = phraseDetector.detectImplicitReference(in: text) {
                if let resolved = resolveImplicitMatch(implicit) {
                    matches.append(resolved)
                }
            }
            
            // 4. AI-powered quote detection (optional)
            if enableAIQuote, let mlx = mlxDetector, mlx.isModelLoaded {
                Task {
                    if let aiMatch = await mlx.detectQuotedScripture(text: text) {
                        await MainActor.run {
                            // Add to matches with AI-detected flag
                        }
                    }
                }
            }
        }
        
        return matches
    }
    
    private func resolveImplicitMatch(_ implicit: ImplicitMatch) -> ScriptureMatch? {
        switch implicit.type {
        case .recall:
            return implicit.resolvedReference
            
        case .famousVerse:
            guard let refString = implicit.referenceString else { return nil }
            return parseAndFetch(refString, sourceType: .implicit)
            
        case .quotation:
            guard let refString = implicit.referenceString else { return nil }
            return parseAndFetch(refString, sourceType: .implicit)
        }
    }
}
```

### UI: AI-Detected Badge

```swift
// AIDetectedBadge.swift
struct AIDetectedBadge: View {
    let matchType: ImplicitMatch.MatchType
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(label)
        }
        .font(.caption2)
        .foregroundColor(.purple)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(4)
    }
    
    var icon: String {
        switch matchType {
        case .recall: return "arrow.counterclockwise"
        case .famousVerse: return "star.fill"
        case .quotation: return "brain"
        }
    }
    
    var label: String {
        switch matchType {
        case .recall: return "recalled"
        case .famousVerse: return "famous verse"
        case .quotation: return "AI-detected"
        }
    }
}
```

### Model Management UI

```swift
// AIModelSettingsView.swift
struct AIModelSettingsView: View {
    @StateObject var mlxService = MLXScriptureDetector()
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    
    var body: some View {
        Form {
            Section("AI Scripture Detection") {
                Toggle("Enable implicit detection", isOn: $enableImplicit)
                    .help("Detect phrases like 'the verse we just read'")
                
                Toggle("Enable AI quote detection", isOn: $enableAIQuote)
                    .disabled(!mlxService.isModelLoaded)
                    .help("Use local AI to detect quoted scriptures")
            }
            
            Section("AI Model") {
                if mlxService.isModelLoaded {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Model loaded")
                        Spacer()
                        Button("Unload") {
                            mlxService.unloadModel()
                        }
                    }
                } else if isDownloading {
                    VStack {
                        ProgressView("Downloading model...", value: downloadProgress)
                        Text("This is a one-time download (~4GB)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI model not installed")
                            .foregroundColor(.secondary)
                        
                        Button("Download AI Model (4GB)") {
                            Task { await downloadModel() }
                        }
                        
                        Text("Required for AI quote detection. Basic implicit detection works without it.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Hardware Requirements") {
                HStack {
                    Text("Apple Silicon")
                    Spacer()
                    Image(systemName: isAppleSilicon ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isAppleSilicon ? .green : .red)
                }
                
                HStack {
                    Text("Memory (8GB+ recommended)")
                    Spacer()
                    Text("\(totalMemoryGB)GB")
                        .foregroundColor(totalMemoryGB >= 8 ? .primary : .orange)
                }
            }
        }
    }
    
    var isAppleSilicon: Bool {
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return machine.contains("arm64")
    }
    
    var totalMemoryGB: Int {
        Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
    }
}
```

---

## Detection Examples

| Pastor Says | Detection Type | Result |
|-------------|----------------|--------|
| "The verse we just read" | Recall | Last pushed verse |
| "Going back to that passage" | Recall | Recent verse from history |
| "For God so loved the world" | Famous Verse | John 3:16 |
| "I can do all things through Christ" | Famous Verse | Philippians 4:13 |
| "As Paul wrote, 'Love is patient...'" | AI Quote | 1 Corinthians 13:4 |
| "Remember when Jesus said about the sparrows?" | AI Quote | Matthew 10:29 |

---

## Model Options

| Model | Size | Speed | Quality |
|-------|------|-------|---------|
| Llama-3-8B (Q4) | 4GB | Medium | High |
| Mistral-7B (Q4) | 4GB | Fast | High |
| Phi-3-mini (Q4) | 2GB | Very Fast | Medium |

**Recommendation:** Start with Phi-3-mini for speed, upgrade to Llama-3 if accuracy needed.

---

## Dependencies

- Story 7.1 (Reference Buffer) - For verse history
- Story 2.5 (Scripture Detection Engine) ✅ Complete
- Apple MLX Framework (Swift package)
- Quantised LLM model files

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] Phrase pattern detection implemented (no LLM)
- [ ] Famous verse detection working
- [ ] Verse history maintained for recall
- [ ] MLX integration complete (optional feature)
- [ ] Model download/management UI
- [ ] AI-detected badge in UI
- [ ] Latency under 500ms for pattern detection
- [ ] Feature toggle in Settings
- [ ] Works offline
- [ ] Committed to Git

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| LLM too slow for real-time | Medium | High | Use smallest model, async processing |
| False positives from AI | Medium | Medium | Lower confidence score, user confirmation |
| Model download too large | Low | Medium | Make optional, show progress |
| Not Apple Silicon | Low | High | Disable AI features, use pattern-only |

---

## Estimated Effort

| Task | Hours |
|------|-------|
| Phrase pattern detector | 3 |
| Famous verse database | 2 |
| Verse history tracking | 2 |
| MLX integration | 6 |
| Model management UI | 3 |
| Badge & confidence UI | 2 |
| Testing & tuning | 6 |
| **Total** | **24** |

---

## Notes

- **Phase 1**: Ship with pattern detection only (no LLM)
- **Phase 2**: Add optional LLM for quote detection
- This is the "Love Tier" differentiator
- All processing local - no cloud costs
- Famous verse list can be expanded based on usage analytics
