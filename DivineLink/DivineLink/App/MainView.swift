import SwiftUI

/// Main content view displayed in the application window
struct MainView: View {
    @StateObject private var pipeline = DetectionPipeline()
    @StateObject private var sessionManager = ServiceSessionManager.shared
    @StateObject private var ppSettings = ProPresenterSettings()
    @StateObject private var ppClient = ProPresenterClient()
    @State private var hasPermission = true
    @State private var showStatus = false
    @State private var showNewServiceSheet = false
    @State private var selectedVerseId: UUID? = nil
    @State private var pushCoordinator: PushActionCoordinator?
    
    // Bible translation selection
    @AppStorage("selectedTranslation") private var selectedTranslation: String = "KJV"
    
    // Available translations (from database)
    private let availableTranslations = ["KJV", "ASV", "WEB"]
    
    // Observe nested objects directly for proper SwiftUI updates
    @ObservedObject private var audioCapture: AudioCaptureService
    @ObservedObject private var transcriptBuffer: TranscriptBuffer
    
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
        VStack(spacing: 8) {
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
        .frame(minWidth: 380, idealWidth: 450, maxWidth: 700, 
               minHeight: 450, idealHeight: 550, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: showStatus)
        .saturation(pipeline.isActive ? 1.0 : 0.4)
        .animation(.easeInOut(duration: 0.3), value: pipeline.isActive)
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
        }
        .onKeyPress(.space) {
            // Only toggle if not editing transcript
            guard !isEditingTranscript else { return .ignored }
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
                .font(.headline)
            
            // Session info
            if let session = sessionManager.currentSession {
                Text("•")
                    .foregroundStyle(.secondary)
                Text(session.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Button {
                    sessionManager.endCurrentSession()
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
            
            // Listening status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColour)
                    .frame(width: 8, height: 8)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
    
    @State private var isEditingTranscript = false
    @State private var editedTranscript = ""
    @State private var showCorrectionAlert = false
    @State private var suggestedCorrection: (original: String, corrected: String, book: String)?
    
    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Live Transcript")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                Spacer()
                
                if !transcriptBuffer.text.isEmpty {
                    Button {
                        editedTranscript = transcriptBuffer.text
                        isEditingTranscript = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Edit transcript to correct misheard words")
                }
            }
            
            if isEditingTranscript {
                // Editable text field
                HStack {
                    TextField("Edit transcript...", text: $editedTranscript)
                        .textFieldStyle(.plain)
                        .font(.system(.caption, design: .monospaced))
                        .onSubmit {
                            processEditedTranscript()
                        }
                    
                    Button("Detect") {
                        processEditedTranscript()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("Cancel") {
                        isEditingTranscript = false
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Text(transcriptBuffer.text.isEmpty ? "Listening..." : transcriptBuffer.text)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: isEditingTranscript ? 50 : 36)
        .alert("Save Correction?", isPresented: $showCorrectionAlert) {
            Button("Save") {
                if let correction = suggestedCorrection {
                    saveSpeechCorrection(original: correction.original, corrected: correction.book)
                }
            }
            Button("Just This Time", role: .cancel) { }
            Button("Cancel", role: .destructive) {
                suggestedCorrection = nil
            }
        } message: {
            if let correction = suggestedCorrection {
                Text("Add '\(correction.original)' → '\(correction.book)' to learned corrections?\n\nThis will automatically correct '\(correction.original)' in future.")
            }
        }
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
        
        isEditingTranscript = false
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
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(pipeline.buffer.pendingCount) pending")
                    .font(.caption2)
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
    let onPushAll: () -> Void       // Push all verses to Stage
    let onPushOne: () -> Void       // Push current verse to Stage
    let onPushAudience: () -> Void  // Push to Audience screen via PP Bible
    let onDelete: () -> Void
    let onNextVerse: () -> Void     // Navigate to next verse
    let onPreviousVerse: () -> Void // Navigate to previous verse
    let onSelectVerse: (Int) -> Void // Select specific verse by index
    
    @State private var isHovering = false
    @State private var isExpanded = false
    
    /// Background colour based on state
    private var backgroundColor: Color {
        if verse.isPushed {
            // Pushed verses get a green-tinted background
            return Color.green.opacity(isSelected ? 0.2 : 0.1)
        } else if isSelected {
            return Color.divineBlue.opacity(0.1)
        } else if isHovering {
            return Color.gray.opacity(0.05)
        } else {
            return Color.clear
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Pushed indicator
            if verse.isPushed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .help("Pushed \(verse.pushCount) time\(verse.pushCount == 1 ? "" : "s")")
            }
            
            // Main content
            VStack(alignment: .leading, spacing: 4) {
                // Reference and translation
                HStack {
                    Text(verse.displayReference)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(verse.isPushed ? .green : (isSelected ? Color.divineBlue : .primary))
                    
                    // Multi-verse indicator
                    if verse.isMultiVerse {
                        Text("\(verse.verses.count) verses")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.7), in: Capsule())
                    }
                    
                    // Push count badge
                    if verse.pushCount > 1 {
                        Text("×\(verse.pushCount)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green, in: Capsule())
                    }
                    
                    Spacer()
                    
                    // Expand/collapse for multi-verse
                    if verse.isMultiVerse {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(isExpanded ? "Collapse verses" : "Expand verses")
                    }
                    
                    Text(verse.translation)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    
                    // Timestamp
                    Text(verse.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                
                // Verse text - different display based on multi-verse and expansion
                if verse.isMultiVerse && isExpanded {
                    // Expanded view: show each verse individually with current highlighted
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(verse.verses.enumerated()), id: \.element.id) { index, verseItem in
                            let isCurrent = index == verse.currentVerseIndex
                            
                            HStack(alignment: .top, spacing: 6) {
                                // Verse number badge - highlighted if current
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
                                
                                // Verse text
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
                            .onTapGesture {
                                onSelectVerse(index)
                            }
                        }
                    }
                    .padding(.top, 4)
                } else if verse.isMultiVerse {
                    // Collapsed multi-verse: show preview
                    Text("v\(verse.verses.first?.verseNumber ?? 0): \(verse.verses.first?.text ?? "")...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // Single verse
                    Text(verse.fullText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // Action buttons (show on hover or selection)
            if isHovering || isSelected {
                if verse.isMultiVerse {
                    // Multi-verse: show navigation and push options
                    HStack(spacing: 4) {
                        // Previous verse button
                        Button {
                            onPreviousVerse()
                        } label: {
                            Image(systemName: "chevron.left.circle")
                                .foregroundStyle(verse.currentVerseIndex > 0 ? Color.divineBlue : .gray.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .disabled(verse.currentVerseIndex <= 0)
                        .help("Previous verse")
                        
                        // Current verse indicator
                        Text("\(verse.currentVerseIndex + 1)/\(verse.verses.count)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .frame(width: 30)
                        
                        // Next verse button
                        Button {
                            onNextVerse()
                        } label: {
                            Image(systemName: "chevron.right.circle")
                                .foregroundStyle(verse.currentVerseIndex < verse.verses.count - 1 ? Color.divineBlue : .gray.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .disabled(verse.currentVerseIndex >= verse.verses.count - 1)
                        .help("Next verse")
                        
                        Divider()
                            .frame(height: 14)
                        
                        // Push one (current verse) to Stage
                        Button {
                            onPushOne()
                        } label: {
                            Image(systemName: "1.circle.fill")
                                .foregroundStyle(Color.divineGold)
                        }
                        .buttonStyle(.plain)
                        .help("Push verse \(verse.currentVerse?.verseNumber ?? 0) to Stage")
                        
                        // Push all verses to Stage
                        Button {
                            onPushAll()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(Color.divineGold)
                        }
                        .buttonStyle(.plain)
                        .help("Push all \(verse.verses.count) verses to Stage")
                        
                        Divider()
                            .frame(height: 14)
                        
                        // Push to Audience screen (via PP Bible)
                        Button {
                            onPushAudience()
                        } label: {
                            Image(systemName: "person.3.fill")
                                .foregroundStyle(Color.divineBlue)
                        }
                        .buttonStyle(.plain)
                        .help("Push to Audience (PP Bible)")
                        
                        Button {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help("Delete")
                    }
                } else {
                    // Single verse: Stage + Audience push
                    HStack(spacing: 4) {
                        // Stage push
                        Button {
                            onPushAll()
                        } label: {
                            Image(systemName: verse.isPushed ? "arrow.up.circle" : "arrow.up.circle.fill")
                                .foregroundStyle(Color.divineGold)
                        }
                        .buttonStyle(.plain)
                        .help(verse.isPushed ? "Push to Stage again" : "Push to Stage")
                        
                        // Audience push
                        Button {
                            onPushAudience()
                        } label: {
                            Image(systemName: "person.3.fill")
                                .foregroundStyle(Color.divineBlue)
                        }
                        .buttonStyle(.plain)
                        .help("Push to Audience (PP Bible)")
                        
                        Button {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help("Delete")
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.divineGold.opacity(0.5) : (verse.isPushed ? Color.green.opacity(0.3) : Color.clear), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovering = hovering
        }
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
