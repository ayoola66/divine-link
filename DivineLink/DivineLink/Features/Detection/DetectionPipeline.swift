import Foundation
import Combine
import os

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
        
        setupPipeline()
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
        
        // Update transcript buffer from transcription
        transcription.transcriptPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] segment in
                self?.transcriptBuffer.update(segment.text)
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
        Logger.pipeline.info("Starting detection pipeline...")
        
        // Check permissions
        let hasAudioPermission = await AudioCaptureService.checkPermission()
        let hasSpeechPermission = await transcription.requestPermission()
        
        guard hasAudioPermission && hasSpeechPermission else {
            Logger.pipeline.error("Missing permissions - audio: \(hasAudioPermission), speech: \(hasSpeechPermission)")
            return
        }
        
        // Clear state
        transcriptBuffer.clear()
        detector.clearCache()
        
        // Start audio capture
        audioCapture.start()
        
        // Start transcription
        transcription.start(with: audioCapture)
        
        isActive = true
        Logger.pipeline.info("Pipeline started successfully")
    }
    
    /// Stop the detection pipeline
    func stop() {
        Logger.pipeline.info("Stopping detection pipeline...")
        
        transcription.stop()
        audioCapture.stop()
        
        isActive = false
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
    
    private func processTranscript(_ transcript: String) {
        guard isActive else { return }
        
        // Apply pastor-specific speech corrections if available
        var correctedTranscript = transcript
        let corrections = sessionManager.currentPastorCorrections()
        
        if !corrections.isEmpty {
            correctedTranscript = correctionService.apply(corrections: corrections, to: transcript)
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
    
    private func processDetection(_ detection: DetectionResult, rawTranscript: String = "") {
        Logger.pipeline.info("Processing detection: \(detection.displayReference)")
        
        // Look up verse text from Bible database
        guard bible.isLoaded else {
            Logger.pipeline.warning("Bible database not loaded - skipping detection: \(detection.displayReference)")
            return
        }
        
        guard let verseText = bible.getVerseText(from: detection.reference) else {
            // Verse not found - REJECT this detection (invalid chapter/verse)
            Logger.pipeline.warning("Rejected invalid detection: \(detection.displayReference) - verse not found")
            return
        }
        
        // Get current translation name
        let translationName = bible.currentTranslation
        
        // Create pending verse
        let pendingVerse = PendingVerse(
            reference: detection.reference,
            fullText: verseText,
            translation: translationName,
            timestamp: detection.timestamp,
            confidence: detection.confidence,
            rawTranscript: rawTranscript
        )
        
        // Add to buffer
        buffer.add(pendingVerse)
        
        // Add to current session if active
        if sessionManager.currentSession != nil {
            let detectedScripture = DetectedScripture(
                reference: detection.displayReference,
                verseText: verseText,
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
        
        // Add sample pending verse
        let sampleReference = ScriptureReference(
            book: "John",
            chapter: 3,
            verseStart: 16,
            verseEnd: nil
        )
        
        let sampleVerse = PendingVerse(
            reference: sampleReference,
            fullText: "For God so loved the world that he gave his only begotten Son, that whoever believes in him should not perish but have everlasting life.",
            translation: "KJV",
            timestamp: Date(),
            confidence: 0.95
        )
        
        pipeline.buffer.add(sampleVerse)
        pipeline.transcriptBuffer.update("For God so loved the world that he gave his only begotten son. John 3:16 is a very famous verse.")
        
        return pipeline
    }
}
