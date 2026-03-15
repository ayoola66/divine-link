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

    /// Weak reference to audio capture — stored at start() so scheduleRestart can rebuild the session
    private weak var audioCaptureService: AudioCaptureService?
    /// Guards against re-entrant restart loops (rapid error sequences)
    private var isRestarting = false
    
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
        audioCaptureService = audioCapture
        print("🎙️ [Transcription] Starting transcription service...")
        
        guard authorizationStatus == .authorized else {
            print("❌ [Transcription] Permission denied")
            error = .permissionDenied
            return
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("❌ [Transcription] Recognizer not available")
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
            print("❌ [Transcription] Failed to create recognition request")
            error = .requestCreationFailed
            return
        }
        
        // Configure request
        recognitionRequest.shouldReportPartialResults = true
        // Only require on-device if the recognizer actually supports it on this device.
        // If supportsOnDeviceRecognition is false (model not downloaded or OS version gap),
        // hard-requiring it causes the recognition task to fail silently — audio flows,
        // meter responds, but no text is produced. Fall back to server-based in that case.
        let canUseOnDevice = speechRecognizer.supportsOnDeviceRecognition
        recognitionRequest.requiresOnDeviceRecognition = requiresOnDevice && canUseOnDevice
        if requiresOnDevice && !canUseOnDevice {
            print("⚠️ [Transcription] On-device recognition not supported on this device — falling back to server-based")
        }
        print("📝 [Transcription] Recognition request created, onDevice: \(requiresOnDevice && canUseOnDevice)")
        
        // Add custom vocabulary if available
        configureCustomVocabulary(request: recognitionRequest)
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error)
        }
        print("✅ [Transcription] Recognition task started")
        
        // Subscribe to audio buffers
        setupAudioBufferSubscription(audioCapture: audioCapture)
        
        isTranscribing = true
        print("✅ [Transcription] Transcription service started successfully")
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
        isRestarting = false
        audioCaptureService = nil
    }
    
    // MARK: - Audio Buffer Handling
    
    private var audioSubscription: AnyCancellable?
    private var receivedBufferCount = 0
    
    private func setupAudioBufferSubscription(audioCapture: AudioCaptureService) {
        print("🔊 [Transcription] Setting up audio buffer subscription")
        receivedBufferCount = 0
        audioSubscription = audioCapture.audioBufferPublisher
            .sink { [weak self] buffer in
                self?.appendAudioBuffer(buffer)
            }
        print("✅ [Transcription] Audio buffer subscription established")
    }
    
    /// Append audio buffer to the recognition request
    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        receivedBufferCount += 1
        
        // Log first buffer with format details
        if receivedBufferCount == 1 {
            let format = buffer.format
            let frameCount = buffer.frameLength
            
            // Calculate RMS to verify audio data
            var rms: Float = 0
            if let channelData = buffer.floatChannelData?[0], frameCount > 0 {
                var sum: Float = 0
                for i in 0..<Int(frameCount) {
                    sum += channelData[i] * channelData[i]
                }
                rms = sqrt(sum / Float(frameCount))
            }
            
            print("🎉 [Transcription] First audio buffer received!")
            print("   Format: \(format.channelCount)ch, \(Int(format.sampleRate))Hz")
            print("   Frames: \(frameCount), RMS: \(rms)")
        } else if receivedBufferCount % 100 == 0 {
            print("📊 [Transcription] Received \(receivedBufferCount) audio buffers")
        }
        
        guard recognitionRequest != nil else {
            if receivedBufferCount <= 5 {
                print("⚠️ [Transcription] Recognition request is nil, cannot append buffer (\(receivedBufferCount))")
            }
            return
        }
        recognitionRequest?.append(buffer)
    }
    
    // MARK: - Recognition Result Handling
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            print("❌ [Transcription] Recognition error: \(error.localizedDescription)")
            handleRecognitionError(error)
            return
        }
        
        guard let result = result else {
            print("⚠️ [Transcription] Result is nil")
            return
        }
        
        let newTranscript = result.bestTranscription.formattedString
        print("📝 [Transcription] Received: \"\(newTranscript)\" (isFinal: \(result.isFinal))")
        
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
        restartTimer?.invalidate()
        restartTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self,
                      !self.isRestarting,
                      let audioCapture = self.audioCaptureService else { return }
                self.isRestarting = true
                self.stop()
                self.start(with: audioCapture)
                self.isRestarting = false
                print("🔄 [Transcription] Session restarted after isFinal/error")
            }
        }
    }
    
    // MARK: - Custom Vocabulary
    
    private func configureCustomVocabulary(request: SFSpeechAudioBufferRecognitionRequest) {
        // Use Bible language model if available (macOS 14+)
        if let model = bibleLanguageModel, model.isReady {
            model.applyTo(request: request)
            print("✅ Applied Bible vocabulary (\(model.contextualStrings.count) contextual strings)")
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
