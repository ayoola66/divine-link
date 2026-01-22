import Speech
import AVFoundation
import Combine

// MARK: - Transcription Errors

enum TranscriptionError: LocalizedError {
    case recognizerNotAvailable
    case permissionDenied
    case requestCreationFailed
    case recognitionFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .recognizerNotAvailable:
            return "Speech recognition not available on this device"
        case .permissionDenied:
            return "Speech recognition permission denied"
        case .requestCreationFailed:
            return "Failed to create recognition request"
        case .recognitionFailed(let error):
            return "Recognition failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Transcription Segment

/// Represents a segment of transcribed text with timing info
struct TranscriptionSegment: Identifiable {
    let id = UUID()
    let text: String
    let timestamp: Date
    let isFinal: Bool
}

// MARK: - Transcription Service

/// Service that transcribes audio to text using Apple's Speech framework
@MainActor
class TranscriptionService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var transcript: String = ""
    @Published var isTranscribing = false
    @Published var error: TranscriptionError?
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    // MARK: - Publishers
    
    /// Publishes new transcription segments for processing
    let transcriptPublisher = PassthroughSubject<TranscriptionSegment, Never>()
    
    /// Publishes the full transcript when it updates
    let fullTranscriptPublisher = PassthroughSubject<String, Never>()
    
    // MARK: - Private Properties
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var lastTranscript: String = ""
    private var restartTimer: Timer?
    
    // Configuration
    private let locale: Locale
    private let requiresOnDevice: Bool
    
    // Custom language model for Bible vocabulary
    private var bibleLanguageModel: BibleLanguageModel?
    
    // MARK: - Initialisation
    
    init(locale: Locale = Locale(identifier: "en-GB"), requiresOnDevice: Bool = true) {
        self.locale = locale
        self.requiresOnDevice = requiresOnDevice
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        
        // Check initial authorization status
        self.authorizationStatus = SFSpeechRecognizer.authorizationStatus()
        
        // Initialise Bible language model
        self.bibleLanguageModel = BibleLanguageModel()
    }
    
    // MARK: - Permission Handling
    
    /// Request speech recognition permission
    func requestPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }
    
    /// Check if speech recognition is available
    var isAvailable: Bool {
        speechRecognizer?.isAvailable ?? false
    }
    
    // MARK: - Transcription Control
    
    /// Start transcribing audio from the given audio capture service
    func start(with audioCapture: AudioCaptureService) {
        guard authorizationStatus == .authorized else {
            error = .permissionDenied
            return
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            error = .recognizerNotAvailable
            return
        }
        
        // Cancel any existing task
        stop()
        
        // Clear previous state
        error = nil
        transcript = ""
        lastTranscript = ""
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            error = .requestCreationFailed
            return
        }
        
        // Configure request
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = requiresOnDevice
        
        // Add custom vocabulary if available
        configureCustomVocabulary(request: recognitionRequest)
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error)
        }
        
        // Subscribe to audio buffers
        setupAudioBufferSubscription(audioCapture: audioCapture)
        
        isTranscribing = true
    }
    
    /// Stop transcribing
    func stop() {
        restartTimer?.invalidate()
        restartTimer = nil
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        isTranscribing = false
    }
    
    // MARK: - Audio Buffer Handling
    
    private var audioSubscription: AnyCancellable?
    
    private func setupAudioBufferSubscription(audioCapture: AudioCaptureService) {
        audioSubscription = audioCapture.audioBufferPublisher
            .sink { [weak self] buffer in
                self?.appendAudioBuffer(buffer)
            }
    }
    
    /// Append audio buffer to the recognition request
    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }
    
    // MARK: - Recognition Result Handling
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            handleRecognitionError(error)
            return
        }
        
        guard let result = result else { return }
        
        let newTranscript = result.bestTranscription.formattedString
        
        // Only update if transcript changed
        if newTranscript != lastTranscript {
            lastTranscript = newTranscript
            
            DispatchQueue.main.async { [weak self] in
                self?.transcript = newTranscript
                self?.fullTranscriptPublisher.send(newTranscript)
                
                // Send segment for processing
                let segment = TranscriptionSegment(
                    text: newTranscript,
                    timestamp: Date(),
                    isFinal: result.isFinal
                )
                self?.transcriptPublisher.send(segment)
            }
        }
        
        // If final, prepare for next utterance
        if result.isFinal {
            scheduleRestart()
        }
    }
    
    private func handleRecognitionError(_ error: Error) {
        let nsError = error as NSError
        
        // Ignore cancelled errors (expected when stopping)
        if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
            // Recognition was cancelled - this is normal
            return
        }
        
        // Ignore "no speech detected" errors
        if nsError.code == 1110 {
            // No speech detected - restart listening
            scheduleRestart()
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.error = .recognitionFailed(error)
            print("Recognition error: \(error.localizedDescription)")
        }
        
        // Attempt recovery
        scheduleRestart()
    }
    
    private func scheduleRestart() {
        // Schedule restart after a brief delay
        restartTimer?.invalidate()
        restartTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            // Placeholder for restart logic
            // The caller (DetectionPipeline) handles restart if needed
        }
    }
    
    // MARK: - Custom Vocabulary
    
    private func configureCustomVocabulary(request: SFSpeechAudioBufferRecognitionRequest) {
        // Use Bible language model if available (macOS 14+)
        if let config = bibleLanguageModel?.configuration, bibleLanguageModel?.isReady == true {
            request.customizedLanguageModel = config
            print("✅ Using Bible vocabulary language model")
        } else {
            print("⚠️ Bible language model not ready, using standard recognition")
        }
    }
    
    /// Check if Bible language model is ready
    var isBibleModelReady: Bool {
        bibleLanguageModel?.isReady ?? false
    }
}

// MARK: - Preview Helper

extension TranscriptionService {
    /// Create a mock service for previews
    static var preview: TranscriptionService {
        let service = TranscriptionService()
        service.transcript = "For God so loved the world that he gave his only begotten son"
        service.isTranscribing = true
        return service
    }
}
