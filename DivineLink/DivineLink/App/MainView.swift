import SwiftUI
import AVFoundation

/// Main content view displayed in the application window
struct MainView: View {
    @StateObject private var pipeline = DetectionPipeline()
    @StateObject private var sessionManager = ServiceSessionManager.shared
    @StateObject private var ppSettings = ProPresenterSettings()
    @StateObject private var ppClient = ProPresenterClient()
    @ObservedObject private var accessibilitySettings = AccessibilitySettings.shared
    @ObservedObject private var adManager = AdManager.shared
    @ObservedObject private var panicService = PanicButtonService.shared
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @ObservedObject private var authService = AuthService.shared
    @State private var hasPermission = true
    @State private var showLoginSheet = false
    @State private var showStatus = false
    @State private var showNewServiceSheet = false
    @State private var selectedVerseId: UUID? = nil
    @State private var pushCoordinator: PushActionCoordinator?
    @State private var f12EventMonitor: Any?

    // Enhanced-recognition (WhisperKit) on-demand model download — first launch, Apple Silicon only.
    @ObservedObject private var whisperModel = WhisperModelManager.shared
    @State private var showModelDownload = false
    /// Offer the one-time download once; if skipped, don't nag on every launch.
    @AppStorage("whisperModelOfferedV1") private var whisperModelOffered = false

    // Bible translation selection
    @AppStorage("selectedTranslation") private var selectedTranslation: String = "KJV"
    
    // Available translations (from database)
    private let availableTranslations = ["KJV", "ASV", "WEB"]
    
    // Observe nested objects directly for proper SwiftUI updates
    @ObservedObject private var audioCapture: AudioCaptureService
    @ObservedObject private var transcriptBuffer: TranscriptBuffer
    // Shared audio-device manager — drives the quick mic selector in the status row.
    @ObservedObject private var audioDeviceManager = AudioDeviceManager.shared
    
    init() {
        let pipeline = DetectionPipeline()
        _pipeline = StateObject(wrappedValue: pipeline)
        _audioCapture = ObservedObject(wrappedValue: pipeline.audioCapture)
        _transcriptBuffer = ObservedObject(wrappedValue: pipeline.transcriptBuffer)
    }
    
    /// Currently selected verse from the list
    private var selectedVerse: PendingVerse? {
        if let id = selectedVerseId {
            return pipeline.buffer.pendingVerses.first { $0.id == id }
        }
        return pipeline.buffer.pendingVerses.first
    }
    
    var body: some View {
        AdContainerView {
            mainContent
        }
        .frame(minWidth: adManager.shouldShowAds ? 580 : 380,
               idealWidth: adManager.shouldShowAds ? 680 : 450,
               maxWidth: 1000,
               minHeight: adManager.shouldShowAds ? 550 : 450,
               idealHeight: adManager.shouldShowAds ? 650 : 550,
               maxHeight: .infinity)
        .background(subscriptionBackgroundTint)
        .animation(.easeInOut(duration: 0.2), value: showStatus)
        .animation(.easeInOut(duration: 0.2), value: adManager.shouldShowAds)
    }

    /// Subtle tier-based background tint for main window only (Epic 7.2). Grey when not signed in or when debug-simulating Free.
    private var subscriptionBackgroundTint: Color {
        guard authService.isAuthenticated else { return Color.gray.opacity(0.04) }
        if subscriptionService.debugSimulateFreeMode { return Color.gray.opacity(0.04) }
        if subscriptionService.isAdmin { return Color.red.opacity(0.06) }
        return subscriptionService.currentTier.themeTint
    }
    
    // MARK: - Main Content (wrapped by AdContainerView)
    
    private var mainContent: some View {
        VStack(spacing: 8) {
            // Subscription warning banner (grace period countdown / expired)
            SubscriptionWarningBanner()
            
            // Header row: Logo + Title + Listening status + Gear
            headerView
            
            // Action buttons row (below header)
            actionButtonsRow
            
            Divider()
            
            // Status indicators row
            statusIndicatorsRow
            
            // Zone 1: Transcript Feed (compact)
            transcriptSection
            
            // Audio level indicator
            audioLevelView
            
            Divider()
            
            // Zone 2: Scrollable list of detected verses (main area)
            detectedVersesList
            
            // Expandable status panel
            if showStatus {
                statusPanel
            }
        }
        .padding(16)
        .saturation(pipeline.isActive ? 1.0 : 0.4)
        .overlay {
            // Loading overlay when Bible database is loading
            if pipeline.bible.isLoading {
                ZStack {
                    Color.black.opacity(0.6)
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("Loading Bible Database")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text(pipeline.bible.loadingProgress)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(30)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .task {
            // Check permissions and auto-start
            hasPermission = await AudioCaptureService.checkPermission()
            if hasPermission {
                await pipeline.start()
            }
            
            // Configure ProPresenter client with saved settings
            if let url = ppSettings.connectionURL {
                ppClient.configure(baseURL: url)
            }
            
            // Configure panic button service with dependencies
            panicService.configure(ppClient: ppClient, buffer: pipeline.buffer)

            // First launch on Apple Silicon: offer the one-time enhanced-recognition download.
            // Intel Macs (isSupported == false) never see this — they use Apple Speech directly.
            // NB: the "offered" flag is flipped ONLY when the user explicitly declines (below),
            // NOT here at show-time — so an Escape-dismiss or a quit mid-download re-offers next
            // launch instead of permanently stranding the feature.
            if WhisperModelManager.isSupported, !whisperModel.isInstalled, !whisperModelOffered {
                showModelDownload = true
            }
        }
        .onKeyPress(.space) {
            // Only toggle if not editing transcript, not in a modal sheet, and has microphone permission
            guard !showCorrectionPopover && !showNewServiceSheet && !showLoginSheet && hasPermission else { return .ignored }
            Task {
                await pipeline.toggle()
            }
            return .handled
        }
        .onKeyPress(.return) {
            pushSelectedVerse()
            return .handled
        }
        .onKeyPress(.delete) {
            deleteSelectedVerse()
            return .handled
        }
        // Note: Cmd+Escape panic shortcut is handled in setupF12KeyHandler via NSEvent
        // Clear feedback overlay
        .overlay {
            ClearFeedbackOverlay(service: panicService)
        }
        // F12 global shortcut handler using NSEvent monitor
        .onAppear {
            setupF12KeyHandler()
        }
        .onDisappear {
            removeF12KeyHandler()
        }
        .sheet(isPresented: $showModelDownload) {
            WhisperDownloadView(
                manager: whisperModel,
                onUseStandard: {
                    // Explicit decline → don't auto-offer again. Re-reachable from Settings.
                    whisperModelOffered = true
                    showModelDownload = false
                },
                onClose: { showModelDownload = false }
            )
        }
    }

    // MARK: - F12 Key Handler
    
    private func setupF12KeyHandler() {
        // Monitor for F12 key press and Cmd+Escape (local events when window is focused)
        f12EventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // F12 key code is 111
            if event.keyCode == 111 {
                Task { @MainActor in
                    await panicService.triggerClear()
                }
                return nil // Consume the event
            }
            
            // Cmd+Escape: keyCode 53 is Escape
            if event.keyCode == 53 && event.modifierFlags.contains(.command) {
                Task { @MainActor in
                    await panicService.triggerClear()
                }
                return nil // Consume the event
            }
            
            return event // Pass through other events
        }
    }
    
    private func removeF12KeyHandler() {
        if let monitor = f12EventMonitor {
            NSEvent.removeMonitor(monitor)
            f12EventMonitor = nil
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            // App icon and title
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: "book.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
            
            Text("Divine Link")
                .scaledFont(size: 14, weight: .semibold)
            
            // Session info
            if let session = sessionManager.currentSession {
                Text("•")
                    .foregroundStyle(.secondary)
                Text(session.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Button {
                    saveSessionTranscript()
                    sessionManager.endCurrentSession()
                    transcriptBuffer.clear()
                } label: {
                    Text("End")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            
            Spacer()
            
            // ProPresenter connection status
            ConnectionStatusIndicator(
                status: ppClient.connectionStatus,
                ipAddress: ppSettings.ipAddress,
                port: ppSettings.port
            )
            
            // Listening status indicator (clickable when permission denied)
            if !hasPermission {
                Button {
                    AudioCaptureService.openMicrophonePrivacySettings()
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColour)
                            .frame(width: 8, height: 8)
                        
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .buttonStyle(.plain)
                .help("Click to open System Settings and grant microphone permission")
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColour)
                        .frame(width: 8, height: 8)
                    
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            SettingsLink {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings (⌘,)")
        }
        .sheet(isPresented: $showNewServiceSheet) {
            NewServiceSheet(sessionManager: sessionManager) { session in
                print("[MainView] Session started: \(session.name)")
            }
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginView()
        }
    }
    
    // MARK: - Action Buttons Row (below header)
    
    private var actionButtonsRow: some View {
        HStack(spacing: 10) {
            // New Service button (if no session)
            if sessionManager.currentSession == nil {
                Button {
                    showNewServiceSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New Service")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // Start/Pause toggle
            Button {
                Task {
                    await pipeline.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: pipeline.isActive ? "pause.fill" : "play.fill")
                    Text(pipeline.isActive ? "Pause" : "Start")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(pipeline.isActive ? Color.divineMuted : Color.divineBlue)
            .controlSize(.small)
            .disabled(!hasPermission)
            .help("Space to toggle")
            
            // Panic/Clear button
            PanicButton(service: panicService) {
                Task { await panicService.triggerClear() }
            }
            
            // Sign In (main window) — when not logged in, blue and distinct; opens login sheet on top
            if !authService.isAuthenticated {
                Button {
                    showLoginSheet = true
                } label: {
                    HStack {
                        Image(systemName: "person.circle.fill")
                        Text("Sign In")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.small)
                .help("Sign in to access premium features and sync across devices")
            }
            
            Spacer()
            
            // Push selected (if verse selected)
            if selectedVerse != nil {
                Button {
                    pushSelectedVerse()
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("Push")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.divineGold)
                .controlSize(.small)
                .help("Enter to push")
                
                Button {
                    deleteSelectedVerse()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Delete to remove")
            }
            
            // Close window button
            Button {
                // Close the window (app stays running in menu bar)
                NSApp.keyWindow?.close()
            } label: {
                Text("Close")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Close window (app stays in menu bar)")
        }
    }
    
    // MARK: - Transcript Section

    /// Text currently selected in the NSTextView (empty = nothing selected).
    @State private var selectedTranscriptText: String = ""
    /// Controls the correction popover.
    @State private var showCorrectionPopover: Bool = false
    /// Pre-fills the replacement field in the popover.
    @State private var correctionReplacement: String = ""

    // Legacy state kept for processEditedTranscript compatibility
    @State private var editedTranscript = ""
    @State private var showCorrectionAlert = false
    @State private var suggestedCorrection: (original: String, corrected: String, book: String)?

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // ── Header ────────────────────────────────────────────────────
            HStack(alignment: .center, spacing: 6) {
                Text("Live Transcript")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                // Hint label — only visible when there's text to select
                if !transcriptBuffer.lines.isEmpty {
                    Text("Select words to edit")
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)
                }

                // Pencil button — activates when text is selected
                Button {
                    correctionReplacement = selectedTranscriptText
                    showCorrectionPopover = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 14))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedTranscriptText.isEmpty ? Color.secondary.opacity(0.3) : Color.accentColor)
                .disabled(selectedTranscriptText.isEmpty)
                .help(selectedTranscriptText.isEmpty
                      ? "Select words in the transcript, then click to correct"
                      : "Correct selected: \"\(selectedTranscriptText)\"")
                .popover(isPresented: $showCorrectionPopover, arrowEdge: .top) {
                    correctionPopover
                }
            }

            // ── NSTextView transcript area ─────────────────────────────────
            TranscriptTextView(
                lines: transcriptBuffer.lines,
                currentText: transcriptBuffer.text,
                selectedText: $selectedTranscriptText,
                onCorrection: { original, replacement in
                    processLineCorrection(original: original, edited: replacement)
                }
            )
            .frame(minHeight: 75, maxHeight: 140)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .alert("Save Correction?", isPresented: $showCorrectionAlert) {
            Button("Save") {
                if let correction = suggestedCorrection {
                    saveSpeechCorrection(original: correction.original, corrected: correction.book)
                }
            }
            Button("Just This Time", role: .cancel) { }
            Button("Cancel", role: .destructive) { suggestedCorrection = nil }
        } message: {
            if let correction = suggestedCorrection {
                Text("Add '\(correction.original)' → '\(correction.book)' to learned corrections?\n\nThis will automatically correct '\(correction.original)' in future.")
            }
        }
    }

    /// Popover that appears when the user clicks the pencil with a selection.
    private var correctionPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Correct Transcript")
                .font(.headline)

            VStack(alignment: .leading, spacing: 3) {
                Text("Heard:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(selectedTranscriptText)
                    .font(.system(.body, design: .monospaced))
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .strikethrough(true, color: .secondary)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Replace with:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Type corrected text…", text: $correctionReplacement)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { applyCorrection() }
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") {
                    showCorrectionPopover = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button("Apply") {
                    applyCorrection()
                }
                .buttonStyle(.borderedProminent)
                .disabled(correctionReplacement.trimmingCharacters(in: .whitespaces).isEmpty
                          || correctionReplacement == selectedTranscriptText)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private func applyCorrection() {
        let original = selectedTranscriptText
        let replacement = correctionReplacement.trimmingCharacters(in: .whitespaces)
        guard !replacement.isEmpty, replacement != original else {
            showCorrectionPopover = false
            return
        }
        showCorrectionPopover = false
        selectedTranscriptText = ""
        processLineCorrection(original: original, edited: replacement)
    }

    private func processLineCorrection(original: String, edited: String) {
        guard edited != original else { return }
        editedTranscript = edited
        processEditedTranscript()
    }
    
    private func processEditedTranscript() {
        // Common words that should never be suggested as corrections
        let ignoreWords = Set(["let's", "lets", "the", "to", "our", "a", "an", "in", "on", "of", "for", "and", "or", "is", "it", "we", "i", "you", "he", "she", "they", "this", "that", "be", "at", "as", "by", "from", "with", "open", "bible", "chapter", "verse", "turn", "read", "go"])
        
        // Check if the edited transcript differs and might contain a correction
        let original = transcriptBuffer.text
        let edited = editedTranscript
        
        // Find what was changed - look for NEW words in edited that weren't in original
        let originalWords = Set(original.lowercased().split(separator: " ").map(String.init))
        let editedWords = edited.lowercased().split(separator: " ").map(String.init)
        
        // Look for words in edited that are valid book names but weren't in original
        for editedWord in editedWords {
            // Skip if word was already in original or is a common word
            if originalWords.contains(editedWord) || ignoreWords.contains(editedWord) {
                continue
            }
            
            // Check if the edited word is a valid book name
            if let book = pipeline.detector.bookNormaliser.normalise(editedWord) {
                // Find the most likely misheard word from original (similar length, not a book name)
                let possibleMisheard = originalWords.filter { word in
                    !ignoreWords.contains(word) &&
                    pipeline.detector.bookNormaliser.normalise(word) == nil &&
                    abs(word.count - editedWord.count) <= 3  // Similar length
                }
                
                if let misheardWord = possibleMisheard.first {
                    // Offer to save the correction
                    suggestedCorrection = (original: misheardWord, corrected: editedWord, book: book)
                    showCorrectionAlert = true
                    break
                }
            }
        }
        
        // Detect from edited text
        let detections = pipeline.detector.detect(in: edited)
        for detection in detections {
            pipeline.processDetectionManually(detection)
        }
        
        showCorrectionPopover = false
    }

    /// Saves the full session transcript to a text file in ~/Documents/DivineLink Transcripts/.
    /// File name format: "ServiceName_YYYY-MM-DD.txt"
    private func saveSessionTranscript() {
        guard let session = sessionManager.currentSession else { return }

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFmt.string(from: session.date)

        let displayFmt = DateFormatter()
        displayFmt.dateStyle = .long
        displayFmt.timeStyle = .none
        let displayDate = displayFmt.string(from: session.date)

        let timeFmt = DateFormatter()
        timeFmt.timeStyle = .short
        timeFmt.dateStyle = .none

        let safeName = session.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let fileName = "\(safeName)_\(dateStr).txt"

        // ── Build formatted content ──────────────────────────────────────
        var lines: [String] = []
        let divider = String(repeating: "─", count: 56)
        let heavyDivider = String(repeating: "═", count: 56)

        lines.append(heavyDivider)
        lines.append("  DIVINE LINK — SERVICE TRANSCRIPT")
        lines.append(heavyDivider)
        lines.append("  Service:   \(session.name)")
        lines.append("  Type:      \(session.serviceType)")
        lines.append("  Date:      \(displayDate)")
        if let pastorId = session.pastorId,
           let pastor = sessionManager.pastor(for: pastorId) {
            lines.append("  Pastor:    \(pastor.name)")
        }
        lines.append("  Started:   \(timeFmt.string(from: session.startTime))")
        lines.append("  Duration:  \(session.formattedDuration)")
        lines.append(heavyDivider)
        lines.append("")

        // ── Detected Scriptures ──────────────────────────────────────────
        let scriptures = session.detectedScriptures
        if !scriptures.isEmpty {
            lines.append("  DETECTED SCRIPTURES (\(scriptures.count))")
            lines.append(divider)
            for (i, scripture) in scriptures.enumerated() {
                let pushed = scripture.wasPushed ? "  ✓ Sent to ProPresenter" : ""
                lines.append("  [\(i + 1)]  \(scripture.reference)  (\(scripture.translation))\(pushed)")
                if !scripture.verseText.isEmpty {
                    lines.append("       \"\(scripture.verseText)\"")
                }
                lines.append("       Heard: \"\(scripture.rawTranscript)\"")
                lines.append("       Time:  \(timeFmt.string(from: scripture.timestamp))")
                lines.append("")
            }
            lines.append(heavyDivider)
            lines.append("")
        }

        // ── Live Transcript ──────────────────────────────────────────────
        let transcriptLines = transcriptBuffer.lines
        if !transcriptLines.isEmpty {
            lines.append("  LIVE TRANSCRIPT")
            lines.append(divider)
            lines.append("")
            for line in transcriptLines {
                lines.append("  \(line.text)")
            }
            lines.append("")
            lines.append(heavyDivider)
        }

        lines.append("  Generated by Divine Link")
        lines.append(heavyDivider)

        let content = lines.joined(separator: "\n")

        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dirURL = docsURL.appendingPathComponent("DivineLink Transcripts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        let fileURL = dirURL.appendingPathComponent(fileName)
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        print("📄 Transcript saved: \(fileURL.path)")
    }

    private func saveSpeechCorrection(original: String, corrected: String) {
        // Add to book mappings
        pipeline.detector.bookNormaliser.addMapping(original, to: corrected)
        
        // Also save to current pastor's corrections if in a session
        if let pastorId = sessionManager.currentSession?.pastorId {
            let correction = SpeechCorrection(
                heard: original,
                corrected: corrected,
                occurrences: 1,
                lastUsed: Date()
            )
            if var profile = sessionManager.pastorProfiles.first(where: { $0.id == pastorId }) {
                profile.speechCorrections.append(correction)
                sessionManager.updatePastorProfile(profile)
            }
        }
        
        print("✅ Saved correction: '\(original)' → '\(corrected)'")
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
    
    // MARK: - Detected Verses List (Scrollable)
    
    private var detectedVersesList: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack {
                Text("Detected Scriptures")
                    .scaledFont(size: 11, weight: .semibold)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(pipeline.buffer.pendingCount) pending")
                    .scaledCaptionFont()
                    .foregroundStyle(.tertiary)
            }
            
            // Scrollable list
            if pipeline.buffer.pendingVerses.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    
                    if pipeline.isActive {
                        Text("Listening for scripture references...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Press Start to begin listening")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        // Show verses with newest at top
                        ForEach(pipeline.buffer.pendingVerses.reversed()) { verse in
                            VerseRowView(
                                verse: verse,
                                isSelected: selectedVerseId == verse.id,
                                onSelect: {
                                    selectedVerseId = verse.id
                                },
                                onPushAll: {
                                    pushVerseAll(verse)
                                },
                                onPushOne: {
                                    pushVerseOne(verse)
                                },
                                onPushAudience: {
                                    pushToAudience(verse)
                                },
                                onDelete: {
                                    deleteVerse(verse)
                                },
                                onNextVerse: {
                                    _ = pipeline.buffer.nextVerse(id: verse.id)
                                },
                                onPreviousVerse: {
                                    _ = pipeline.buffer.previousVerse(id: verse.id)
                                },
                                onSelectVerse: { index in
                                    pipeline.buffer.setCurrentVerse(id: verse.id, index: index)
                                },
                                availableTranslations: availableTranslations,
                                onChangeTranslation: { translation in
                                    changeTranslation(verse, to: translation)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(minHeight: 150)
    }
    
    // MARK: - Verse Actions
    
    private func pushSelectedVerse() {
        if let verse = selectedVerse {
            pushVerseAll(verse)
        }
    }
    
    private func deleteSelectedVerse() {
        if let verse = selectedVerse {
            deleteVerse(verse)
        }
    }
    
    /// Push all verses (full text) to ProPresenter
    private func pushVerseAll(_ verse: PendingVerse) {
        print("[Push All] \(verse.displayReference) (\(verse.verses.count) verses)")
        
        // Push to ProPresenter
        Task {
            do {
                let message = ppClient.formatStageMessage(from: verse)
                try await ppClient.sendStageMessage(message)
                print("✅ Pushed all to ProPresenter: \(verse.displayReference)")
            } catch {
                print("❌ Failed to push to ProPresenter: \(error.localizedDescription)")
                // Still mark as pushed locally even if PP fails
            }
        }
        
        // Mark as pushed (keeps it in list with visual indicator)
        pipeline.buffer.markAsPushed(id: verse.id)
    }
    
    /// Push only the current verse to ProPresenter
    private func pushVerseOne(_ verse: PendingVerse) {
        guard let currentVerse = verse.currentVerse else {
            print("[Push One] No current verse selected")
            return
        }
        
        let reference = verse.reference
        let singleRef = "\(reference.book) \(reference.chapter):\(currentVerse.verseNumber)"
        print("[Push One] \(singleRef)")
        
        // Push to ProPresenter
        Task {
            do {
                // Format as single verse message
                let message = "\(singleRef)\n\(currentVerse.text)"
                try await ppClient.sendStageMessage(message)
                print("✅ Pushed single verse to ProPresenter: \(singleRef)")
                
                // Auto-advance to next verse after push
                if pipeline.buffer.nextVerse(id: verse.id) {
                    print("[Push One] Auto-advanced to next verse")
                }
            } catch {
                print("❌ Failed to push to ProPresenter: \(error.localizedDescription)")
            }
        }
        
        // Mark as pushed
        pipeline.buffer.markAsPushed(id: verse.id)
    }
    
    /// Push to Audience screen via ProPresenter's native Bible feature (⌘B automation)
    private func pushToAudience(_ verse: PendingVerse) {
        print("[Push Audience] \(verse.displayReference)")
        
        Task {
            let success = await ppClient.pushToAudience(reference: verse.reference)
            
            if success {
                print("✅ Pushed to Audience via PP Bible: \(verse.displayReference)")
                // Mark as pushed
                pipeline.buffer.markAsPushed(id: verse.id)
            } else {
                print("❌ Failed to push to Audience - check Accessibility permissions")
                // Check if we need to request permission
                if !ppClient.hasKeyboardPermission() {
                    ppClient.requestKeyboardPermission()
                }
            }
        }
    }
    
    private func deleteVerse(_ verse: PendingVerse) {
        print("[Delete] \(verse.displayReference)")
        
        // Remove from pending list
        pipeline.buffer.remove(id: verse.id)
        
        // Clear selection if it was the selected verse
        if selectedVerseId == verse.id {
            selectedVerseId = pipeline.buffer.pendingVerses.first?.id
        }
    }

    /// Switch a single detected verse card to a different Bible translation, in place.
    /// Re-fetches the same reference in the chosen version and updates just that card —
    /// the app-wide default translation is left untouched.
    private func changeTranslation(_ verse: PendingVerse, to translation: String) {
        guard translation != verse.translation else { return }
        let bibleVerses = pipeline.bible.getVerses(from: verse.reference, translation: translation)
        let items = bibleVerses.map { VerseItem(verseNumber: $0.verse, text: $0.text) }
        pipeline.buffer.updateTranslation(id: verse.id, translation: translation, verses: items)
    }
    
    // MARK: - Mic Selector (quick audio-input switcher)

    /// Quick audio-input selector in the status row — change the mic/input device
    /// without opening Settings → Audio. Reflects and updates the shared
    /// AudioDeviceManager, which the pipeline already observes to switch input live.
    private var micSelector: some View {
        Menu {
            if audioDeviceManager.availableDevices.isEmpty {
                Text("No input devices found")
            }
            ForEach(audioDeviceManager.availableDevices, id: \.uniqueID) { device in
                Button {
                    Task { await audioDeviceManager.selectDevice(device) }
                } label: {
                    HStack {
                        Text(device.localizedName)
                        if device.uniqueID == audioDeviceManager.selectedDevice?.uniqueID {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Divider()
            Button {
                Task { await audioDeviceManager.refreshDevices() }
            } label: {
                Label("Refresh devices", systemImage: "arrow.clockwise")
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 8))
                Text(shortDeviceName(audioDeviceManager.selectedDevice?.localizedName))
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(audioCapture.isCapturing ? Color.green.opacity(0.2) : Color.gray.opacity(0.12))
            .foregroundStyle(audioCapture.isCapturing ? .green : .secondary)
            .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Change audio input device")
    }

    /// Shorten long device names for the compact status pill.
    private func shortDeviceName(_ name: String?) -> String {
        guard let name, !name.isEmpty else { return "Input" }
        return name.count > 18 ? String(name.prefix(17)) + "…" : name
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

            micSelector

            StatusPill(
                icon: "text.bubble.fill",
                label: "Speech",
                isActive: pipeline.transcription.isTranscribing,
                color: .blue
            )
            
            // Bible pill - clickable to change translation
            Menu {
                ForEach(availableTranslations, id: \.self) { translation in
                    Button {
                        selectedTranslation = translation
                    } label: {
                        HStack {
                            Text(translation)
                            if translation == selectedTranslation {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 8))
                    Text(selectedTranslation)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(pipeline.bible.isLoaded ? Color.purple.opacity(0.2) : Color.gray.opacity(0.1))
                .foregroundStyle(pipeline.bible.isLoaded ? .purple : .gray)
                .clipShape(Capsule())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            
            StatusPill(
                icon: "magnifyingglass",
                label: "Detect",
                isActive: pipeline.detector.lastDetection != nil,
                color: .orange
            )
            
            // Panic button status indicator (shows clearing/cleared states)
            ClearStatusIndicator(service: panicService)
            
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
                         status: pipeline.bible.isLoaded ? "Loaded (\(selectedTranslation))" : "Not Found",
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

// MARK: - Verse Row View (for scrollable list)

struct VerseRowView: View {
    let verse: PendingVerse
    let isSelected: Bool
    let onSelect: () -> Void
    let onPushAll: () -> Void
    let onPushOne: () -> Void
    let onPushAudience: () -> Void
    let onDelete: () -> Void
    let onNextVerse: () -> Void
    let onPreviousVerse: () -> Void
    let onSelectVerse: (Int) -> Void
    let availableTranslations: [String]
    let onChangeTranslation: (String) -> Void

    @ObservedObject private var detectionSettings = DetectionSettings.shared
    @State private var isHovering = false
    @State private var isExpanded = false
    
    private var isLowConfidenceBySettings: Bool {
        detectionSettings.isLowConfidence(verse.detectionConfidence)
    }
    
    private var backgroundColor: Color {
        if verse.isPushed {
            return Color.green.opacity(isSelected ? 0.2 : 0.1)
        } else if isLowConfidenceBySettings && detectionSettings.autoHoldLowConfidence {
            return Color.orange.opacity(isSelected ? 0.15 : 0.08)
        } else if isSelected {
            return Color.divineBlue.opacity(0.1)
        } else if isHovering {
            return Color.gray.opacity(0.05)
        } else {
            return Color.clear
        }
    }
    
    var body: some View {
        rowContent
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(backgroundColor))
            .overlay(rowBorder)
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }
            .onHover { isHovering = $0 }
    }
    
    private var rowContent: some View {
        HStack(spacing: 8) {
            pushedIndicator
            mainContentStack
            actionButtonsSection
        }
    }
    
    @ViewBuilder
    private var pushedIndicator: some View {
        if verse.isPushed {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .help("Pushed \(verse.pushCount) time\(verse.pushCount == 1 ? "" : "s")")
        }
    }
    
    private var mainContentStack: some View {
        VStack(alignment: .leading, spacing: 4) {
            referenceHeader
            verseTextContent
            lowConfidenceWarningSection
        }
    }
    
    private var referenceHeader: some View {
        HStack {
            Text(verse.displayReference)
                .scaledFont(size: 13, weight: .semibold)
                .foregroundStyle(verse.isPushed ? .green : (isSelected ? Color.divineBlue : .primary))
            
            if detectionSettings.showConfidenceIndicators {
                ConfidenceIndicatorView(confidence: verse.detectionConfidence)
            }
            
            multiVerseBadge
            pushCountBadge
            Spacer()
            expandCollapseButton
            translationAndTimestamp
        }
    }
    
    @ViewBuilder
    private var multiVerseBadge: some View {
        if verse.isMultiVerse {
            Text("\(verse.verses.count) verses")
                .font(.caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.blue.opacity(0.7), in: Capsule())
        }
    }
    
    @ViewBuilder
    private var pushCountBadge: some View {
        if verse.pushCount > 1 {
            Text("×\(verse.pushCount)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.green, in: Capsule())
        }
    }
    
    @ViewBuilder
    private var expandCollapseButton: some View {
        if verse.isMultiVerse {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Collapse verses" : "Expand verses")
        }
    }
    
    private var translationAndTimestamp: some View {
        HStack(spacing: 4) {
            translationPicker
            Text(verse.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    /// Per-card Bible-version switcher. Tapping shows the available translations;
    /// choosing one re-renders THIS verse in that version without changing the
    /// app-wide default — lets the operator flick a detected verse between versions.
    private var translationPicker: some View {
        Menu {
            ForEach(availableTranslations, id: \.self) { translation in
                Button {
                    onChangeTranslation(translation)
                } label: {
                    HStack {
                        Text(translation)
                        if translation == verse.translation {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 2) {
                Text(verse.translation)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 7))
                    .foregroundStyle(.tertiary)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Switch Bible version for this verse")
    }
    
    @ViewBuilder
    private var verseTextContent: some View {
        if verse.isMultiVerse && isExpanded {
            expandedVersesView
        } else if verse.isMultiVerse {
            collapsedMultiVersePreview
        } else {
            singleVerseText
        }
    }
    
    private var expandedVersesView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(verse.verses.enumerated()), id: \.element.id) { index, verseItem in
                ExpandedVerseItemView(
                    verseItem: verseItem,
                    isCurrent: index == verse.currentVerseIndex,
                    onTap: { onSelectVerse(index) }
                )
            }
        }
        .padding(.top, 4)
    }
    
    private var collapsedMultiVersePreview: some View {
        Text("v\(verse.verses.first?.verseNumber ?? 0): \(verse.verses.first?.text ?? "")...")
            .scaledBodyFont()
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var singleVerseText: some View {
        let dimmed = isLowConfidenceBySettings && detectionSettings.autoHoldLowConfidence
        // Compact 2-line preview by default; the selected card expands to full text so
        // the card grows dynamically to fit any translation's length (KJV/ASV/WEB).
        return Text(verse.fullText)
            .scaledBodyFont()
            .foregroundStyle(Color.secondary.opacity(dimmed ? 0.7 : 1.0))
            .lineLimit(isSelected ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
    
    @ViewBuilder
    private var lowConfidenceWarningSection: some View {
        if isLowConfidenceBySettings && detectionSettings.autoHoldLowConfidence {
            LowConfidenceWarning(confidence: verse.detectionConfidence)
        }
    }
    
    @ViewBuilder
    private var actionButtonsSection: some View {
        if isHovering || isSelected {
            if verse.isMultiVerse {
                multiVerseActionButtons
            } else {
                singleVerseActionButtons
            }
        }
    }
    
    private var multiVerseActionButtons: some View {
        HStack(spacing: 4) {
            navigationButtons
            Divider().frame(height: 14)
            pushButtons
            Divider().frame(height: 14)
            audienceAndDeleteButtons
        }
    }
    
    private var navigationButtons: some View {
        HStack(spacing: 4) {
            Button { onPreviousVerse() } label: {
                Image(systemName: "chevron.left.circle")
                    .foregroundStyle(verse.currentVerseIndex > 0 ? Color.divineBlue : .gray.opacity(0.5))
            }
            .buttonStyle(.plain)
            .disabled(verse.currentVerseIndex <= 0)
            .help("Previous verse")
            
            Text("\(verse.currentVerseIndex + 1)/\(verse.verses.count)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(width: 30)
            
            Button { onNextVerse() } label: {
                Image(systemName: "chevron.right.circle")
                    .foregroundStyle(verse.currentVerseIndex < verse.verses.count - 1 ? Color.divineBlue : .gray.opacity(0.5))
            }
            .buttonStyle(.plain)
            .disabled(verse.currentVerseIndex >= verse.verses.count - 1)
            .help("Next verse")
        }
    }
    
    private var pushButtons: some View {
        HStack(spacing: 4) {
            Button { onPushOne() } label: {
                Image(systemName: "1.circle.fill").foregroundStyle(Color.divineGold)
            }
            .buttonStyle(.plain)
            .help("Push verse \(verse.currentVerse?.verseNumber ?? 0) to Stage")
            
            Button { onPushAll() } label: {
                Image(systemName: "arrow.up.circle.fill").foregroundStyle(Color.divineGold)
            }
            .buttonStyle(.plain)
            .help("Push all \(verse.verses.count) verses to Stage")
        }
    }
    
    private var audienceAndDeleteButtons: some View {
        HStack(spacing: 4) {
            Button { onPushAudience() } label: {
                Image(systemName: "person.3.fill").foregroundStyle(Color.divineBlue)
            }
            .buttonStyle(.plain)
            .help("Push to Audience (PP Bible)")
            
            Button { onDelete() } label: {
                Image(systemName: "trash").foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Delete")
        }
    }
    
    private var singleVerseActionButtons: some View {
        HStack(spacing: 4) {
            Button { onPushAll() } label: {
                Image(systemName: verse.isPushed ? "arrow.up.circle" : "arrow.up.circle.fill")
                    .foregroundStyle(Color.divineGold)
            }
            .buttonStyle(.plain)
            .help(verse.isPushed ? "Push to Stage again" : "Push to Stage")
            
            Button { onPushAudience() } label: {
                Image(systemName: "person.3.fill").foregroundStyle(Color.divineBlue)
            }
            .buttonStyle(.plain)
            .help("Push to Audience (PP Bible)")
            
            Button { onDelete() } label: {
                Image(systemName: "trash").foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Delete")
        }
    }
    
    private var rowBorder: some View {
        let borderColor: Color = {
            if isSelected {
                return Color.divineGold.opacity(0.5)
            } else if verse.isPushed {
                return Color.green.opacity(0.3)
            } else {
                return Color.clear
            }
        }()
        return RoundedRectangle(cornerRadius: 6).stroke(borderColor, lineWidth: 1)
    }
}

// MARK: - Expanded Verse Item View (helper for VerseRowView)

private struct ExpandedVerseItemView: View {
    let verseItem: VerseItem
    let isCurrent: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("v\(verseItem.verseNumber)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    isCurrent ? Color.divineGold : Color.divineBlue.opacity(0.8),
                    in: RoundedRectangle(cornerRadius: 4)
                )
            
            Text(verseItem.text)
                .font(.caption)
                .foregroundStyle(isCurrent ? .primary : .secondary)
                .fontWeight(isCurrent ? .medium : .regular)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isCurrent ? Color.divineGold.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Pending Scripture Card (legacy, kept for reference)

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
