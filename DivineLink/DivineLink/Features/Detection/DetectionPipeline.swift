import Foundation
import Combine
import os
import AVFoundation
import CoreAudio

// MARK: - Loggers

extension Logger {
    static let detection = Logger(subsystem: "com.divinelink", category: "Detection")
    static let transcription = Logger(subsystem: "com.divinelink", category: "Transcription")
    static let pipeline = Logger(subsystem: "com.divinelink", category: "Pipeline")
}

// MARK: - Detection Pipeline

/// Coordinates the flow from audio → transcription → detection → pending buffer
@MainActor
class DetectionPipeline: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isActive = false
    @Published var lastDetectedReference: String?
    
    // MARK: - Services
    
    let audioCapture: AudioCaptureService
    let transcription: TranscriptionService
    let detector: ScriptureDetectorService
    let implicitDetector: ImplicitReferenceDetector
    let bible: BibleService
    let buffer: BufferManager
    let transcriptBuffer: TranscriptBuffer
    let correctionService: SpeechCorrectionService
    let audioDeviceManager: AudioDeviceManager
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let sessionManager = ServiceSessionManager.shared
    
    // MARK: - Initialisation
    
    init() {
        self.audioCapture = AudioCaptureService()
        self.transcription = TranscriptionService()
        self.detector = ScriptureDetectorService()
        self.implicitDetector = ImplicitReferenceDetector()
        self.bible = BibleService()
        self.buffer = BufferManager()
        self.transcriptBuffer = TranscriptBuffer()
        self.correctionService = SpeechCorrectionService.shared
        self.audioDeviceManager = AudioDeviceManager.shared
        
        wireDetectorToBible()
        setupPipeline()
        setupDeviceObserver()
    }
    
    /// Give the detector read-only access to the Bible so it can reject impossible
    /// references before they reach the operator or poison the reference context.
    private func wireDetectorToBible() {
        detector.referenceValidator = { [weak self] reference in
            guard let self else { return true }
            return self.bible.referenceExists(reference)
        }
        
        detector.bookNormaliser.chapterCountProvider = { [weak self] bookName in
            self?.bible.maxChapter(forBookNamed: bookName)
        }
    }
    
    /// Observe device selection changes and apply to audio capture.
    /// Debounced to prevent rapid-fire calls at startup from corrupting the Core Audio
    /// HAL state (observers can fire multiple times as AudioDeviceManager discovers and
    /// loads saved devices).
    private func setupDeviceObserver() {
        audioDeviceManager.$selectedDevice
            .compactMap { $0 }
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] device in
                guard let self = self else { return }
                print("🎛️ [Pipeline] Device selection changed to: \(device.localizedName)")
                let _ = self.audioCapture.setInputDevice(device)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Pipeline Setup
    
    private func setupPipeline() {
        // Connect transcription output to detector
        transcription.fullTranscriptPublisher
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] transcript in
                self?.processTranscript(transcript)
            }
            .store(in: &cancellables)
        
        // Finalize in-progress text the moment an STT session stops.
        // This fires BEFORE the new session's first update() can overwrite it,
        // so no spoken text is lost when Apple's recognizer restarts mid-sentence.
        transcription.$isTranscribing
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isTranscribing in
                guard let self, !isTranscribing else { return }
                transcriptBuffer.finalizeInProgressText()
            }
            .store(in: &cancellables)

        // Update transcript buffer from transcription
        transcription.transcriptPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] segment in
                guard let self else { return }
                if segment.isFinal {
                    transcriptBuffer.appendFinalLine(segment.text)
                } else {
                    transcriptBuffer.update(segment.text)
                }
            }
            .store(in: &cancellables)
        
        // Log detections
        detector.detectionPublisher
            .sink { [weak self] result in
                self?.lastDetectedReference = result.displayReference
                Logger.detection.info("Detected scripture: \(result.displayReference)")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Pipeline Control
    
    /// Start the detection pipeline
    func start() async {
        print("🚀 [Pipeline] Starting detection pipeline...")
        Logger.pipeline.info("Starting detection pipeline...")
        
        // Check permissions
        let hasAudioPermission = await AudioCaptureService.checkPermission()
        let hasSpeechPermission = await transcription.requestPermission()
        
        print("🔐 [Pipeline] Permissions - Audio: \(hasAudioPermission), Speech: \(hasSpeechPermission)")
        
        guard hasAudioPermission && hasSpeechPermission else {
            print("❌ [Pipeline] Missing permissions")
            Logger.pipeline.error("Missing permissions - audio: \(hasAudioPermission), speech: \(hasSpeechPermission)")
            return
        }
        
        // Clear state
        transcriptBuffer.clear()
        detector.clearCache()
        
        // Ensure device list is refreshed and apply saved device.
        // Only call setInputDevice if the observer hasn't already configured it
        // (the debounced observer fires on selectedDevice changes and may have
        // already set the correct device, so calling again would be redundant and
        // could cause a disruptive stop/start cycle).
        await audioDeviceManager.refreshDevices()
        if let selectedDevice = audioDeviceManager.selectedDevice {
            // Check if device observer already configured this device
            if let deviceID = audioCapture.currentDeviceID,
               let selectedID = getAudioDeviceID(for: selectedDevice),
               deviceID == selectedID {
                print("🎛️ [Pipeline] Device already configured by observer: \(selectedDevice.localizedName) — skipping")
            } else {
                print("🎛️ [Pipeline] Configuring input device: \(selectedDevice.localizedName)")
                let deviceSet = audioCapture.setInputDevice(selectedDevice)
                print("🎛️ [Pipeline] Device configured: \(deviceSet ? "✅ Success" : "⚠️ Failed, using default")")
            }
        } else {
            print("⚠️ [Pipeline] No device selected, using system default")
        }
        
        // Start audio capture (setInputDevice may have already started it if
        // wasCapturing was true, but the guard in start() prevents double-start)
        print("🎤 [Pipeline] Starting audio capture...")
        audioCapture.start()
        print("✅ [Pipeline] Audio capture started, isCapturing: \(audioCapture.isCapturing)")
        
        // Start transcription
        print("🎙️ [Pipeline] Starting transcription...")
        transcription.start(with: audioCapture)
        print("✅ [Pipeline] Transcription started, isTranscribing: \(transcription.isTranscribing)")
        
        isActive = true
        print("✅ [Pipeline] Pipeline started successfully, isActive: \(isActive)")
        Logger.pipeline.info("Pipeline started successfully")
    }
    
    /// Stop the detection pipeline
    func stop() {
        Logger.pipeline.info("Stopping detection pipeline...")
        
        transcription.stop()
        audioCapture.stop()
        
        isActive = false
    }
    
    /// Helper: resolve an AVCaptureDevice to its Core Audio AudioDeviceID
    /// so we can compare against audioCapture.currentDeviceID without triggering a set.
    private func getAudioDeviceID(for device: AVCaptureDevice) -> AudioDeviceID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize
        ) == noErr else { return nil }
        
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &devices
        ) == noErr else { return nil }
        
        let targetUID = device.uniqueID
        for id in devices {
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            var uidPtr: Unmanaged<CFString>?
            let status = withUnsafeMutablePointer(to: &uidPtr) { ptr in
                AudioObjectGetPropertyData(id, &uidAddress, 0, nil, &uidSize, ptr)
            }
            if status == noErr, let uid = uidPtr?.takeRetainedValue() as String?, uid == targetUID {
                return id
            }
        }
        return nil
    }
    
    /// Toggle the pipeline on/off
    func toggle() async {
        if isActive {
            stop()
        } else {
            await start()
        }
    }
    
    // MARK: - Transcript Processing
    
    /// Fixes STT artifacts where a book name and number are concatenated without a space.
    /// e.g. "Genesis1" → "Genesis 1", "1John" → "1 John", "Romans8" → "Romans 8"
    private func normalizeSTTOutput(_ text: String) -> String {
        // Insert space between a letter immediately followed by a digit
        var result = text.replacingOccurrences(
            of: #"([A-Za-z])(\d)"#,
            with: "$1 $2",
            options: .regularExpression
        )
        // Insert space between a digit immediately followed by a letter
        // (handles "1John" → "1 John")
        result = result.replacingOccurrences(
            of: #"(\d)([A-Za-z])"#,
            with: "$1 $2",
            options: .regularExpression
        )
        return result
    }

    private func processTranscript(_ transcript: String) {
        guard isActive else { return }

        // Normalise STT output before detection (fixes concatenated book+number, e.g. "Genesis1")
        let normalizedTranscript = normalizeSTTOutput(transcript)

        // Apply pastor-specific speech corrections if available
        var correctedTranscript = normalizedTranscript
        let corrections = sessionManager.currentPastorCorrections()
        
        if !corrections.isEmpty {
            correctedTranscript = correctionService.apply(corrections: corrections, to: normalizedTranscript)
        }
        
        // Detect explicit scripture references in corrected text
        let detections = detector.detect(in: correctedTranscript)
        
        for detection in detections {
            processDetection(detection, rawTranscript: transcript)
        }
        
        // Also check for implicit famous verse references
        if let implicitMatch = implicitDetector.bestMatch(in: correctedTranscript),
           let scriptureRef = implicitMatch.scriptureReference,
           implicitMatch.confidence >= 0.6 {
            // Create a detection result for the implicit match
            let implicitDetection = DetectionResult(
                reference: scriptureRef,
                rawMatch: implicitMatch.matchedPhrase,
                confidence: implicitMatch.confidence,
                timestamp: Date()
            )
            processDetection(implicitDetection, rawTranscript: transcript)
            Logger.detection.info("Implicit match: \(implicitMatch.reference) from '\(implicitMatch.matchedPhrase)'")
        }
    }
    
    /// Process a detection manually (from edited transcript)
    func processDetectionManually(_ detection: DetectionResult) {
        processDetection(detection, rawTranscript: "manual-edit")
    }
    
    /// When a reference has an invalid chapter number, attempt to re-interpret it as
    /// concatenated chapter+verse digits (e.g. chapter=123 → ch=1, v=23).
    /// This recovers from STT collapsing "James 1 23" into "James 123".
    /// Returns the first valid split, or nil if none found.
    private func reinterpretConcatenatedRef(_ ref: ScriptureReference) -> ScriptureReference? {
        // Only safe when no verse was actually spoken. When the operator said
        // "verse 8 to 12", the trailing digits of the chapter are not the verse, and
        // splitting them threw the requested passage away: "Amos 91:8-12" silently
        // became "Amos 9:1". A wrong passage on screen is worse than none, so leave
        // these alone and let the detection be rejected with an honest log line.
        guard ref.verseStart == 1, ref.verseEnd == nil else {
            Logger.pipeline.info("Not splitting \(ref.formatted) — the verse was spoken explicitly")
            return nil
        }
        
        let chapterStr = String(ref.chapter)
        guard chapterStr.count >= 2 else { return nil }
        for splitAt in 1..<chapterStr.count {
            let chPart = String(chapterStr.prefix(splitAt))
            let vPart = String(chapterStr.suffix(chapterStr.count - splitAt))
            guard let ch = Int(chPart), let v = Int(vPart), ch >= 1, v >= 1 else { continue }
            let candidate = ScriptureReference(book: ref.book, chapter: ch, verseStart: v, verseEnd: nil)
            if !bible.getVerses(from: candidate).isEmpty {
                return candidate
            }
        }
        return nil
    }

    private func processDetection(_ detection: DetectionResult, rawTranscript: String = "") {
        Logger.pipeline.info("Processing detection: \(detection.displayReference)")
        
        // Look up verse text from Bible database
        guard bible.isLoaded else {
            Logger.pipeline.warning("Bible database not loaded - skipping detection: \(detection.displayReference)")
            return
        }
        
        // Get individual verses from Bible database
        let bibleVerses = bible.getVerses(from: detection.reference)
        
        guard !bibleVerses.isEmpty else {
            // Before rejecting: if the chapter number exceeds the book's valid range, STT may
            // have concatenated chapter+verse (e.g. "James 1 23" → "James 123" → parsed as ch=123).
            // Try splitting the digits and retry lookup.
            if let correctedRef = reinterpretConcatenatedRef(detection.reference) {
                Logger.pipeline.info("♻️ Re-interpreted \(detection.displayReference) → \(correctedRef.formatted) (split concatenated chapter+verse)")
                let corrected = DetectionResult(
                    reference: correctedRef,
                    rawMatch: detection.rawMatch,
                    detectionConfidence: detection.detectionConfidence,
                    timestamp: detection.timestamp,
                    patternType: detection.patternType + "+split"
                )
                processDetection(corrected, rawTranscript: rawTranscript)
                return
            }
            // Verse not found - REJECT this detection (invalid chapter/verse)
            Logger.pipeline.warning("Rejected invalid detection: \(detection.displayReference) - verse not found")
            return
        }
        
        // Convert BibleVerse objects to VerseItem objects for display
        let verseItems = bibleVerses.map { bibleVerse in
            VerseItem(verseNumber: bibleVerse.verse, text: bibleVerse.text)
        }
        
        // Get current translation name
        let translationName = bible.currentTranslation
        
        // Create pending verse with individual verses
        let pendingVerse = PendingVerse(
            reference: detection.reference,
            verses: verseItems,
            translation: translationName,
            timestamp: detection.timestamp,
            confidence: detection.confidence,
            rawTranscript: rawTranscript
        )
        
        // Add to buffer
        buffer.add(pendingVerse)
        
        // Log multi-verse detection
        if verseItems.count > 1 {
            Logger.pipeline.info("Multi-verse detection: \(verseItems.count) verses in \(detection.displayReference)")
        }
        
        // Add to current session if active
        if sessionManager.currentSession != nil {
            let detectedScripture = DetectedScripture(
                reference: detection.displayReference,
                verseText: pendingVerse.fullText,  // Combined text for storage
                translation: translationName,
                rawTranscript: rawTranscript,
                confidence: detection.confidence
            )
            sessionManager.addDetectedScripture(detectedScripture)
        }
    }
}

// MARK: - Preview Helper

extension DetectionPipeline {
    /// Create a preview pipeline with sample data
    static var preview: DetectionPipeline {
        let pipeline = DetectionPipeline()
        
        // Add sample single verse
        let singleReference = ScriptureReference(
            book: "John",
            chapter: 3,
            verseStart: 16,
            verseEnd: nil
        )
        
        let singleVerse = PendingVerse(
            reference: singleReference,
            verses: [
                VerseItem(verseNumber: 16, text: "For God so loved the world that he gave his only begotten Son, that whoever believes in him should not perish but have everlasting life.")
            ],
            translation: "KJV",
            timestamp: Date(),
            confidence: 0.95
        )
        pipeline.buffer.add(singleVerse)
        
        // Add sample multi-verse reference
        let multiReference = ScriptureReference(
            book: "John",
            chapter: 3,
            verseStart: 16,
            verseEnd: 18
        )
        
        let multiVerse = PendingVerse(
            reference: multiReference,
            verses: [
                VerseItem(verseNumber: 16, text: "For God so loved the world that he gave his only begotten Son, that whoever believes in him should not perish but have everlasting life."),
                VerseItem(verseNumber: 17, text: "For God sent not his Son into the world to condemn the world; but that the world through him might be saved."),
                VerseItem(verseNumber: 18, text: "He that believeth on him is not condemned: but he that believeth not is condemned already, because he hath not believed in the name of the only begotten Son of God.")
            ],
            translation: "KJV",
            timestamp: Date().addingTimeInterval(-60),
            confidence: 0.92
        )
        pipeline.buffer.add(multiVerse)
        
        pipeline.transcriptBuffer.update("For God so loved the world that he gave his only begotten son. John 3:16 is a very famous verse.")
        
        return pipeline
    }
}
