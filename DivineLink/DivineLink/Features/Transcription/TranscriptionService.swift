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

/// Service that transcribes audio to text using Apple's Speech framework.
///
/// Long-form continuous recognition (a 30–45 minute service) is handled by
/// **seamless session handoff**: Apple's `SFSpeechRecognizer` finalises a session
/// on each natural pause (`isFinal`), after which that task will not process any
/// more audio. Rather than tearing the session down and rebuilding it after a
/// timer delay — which used to leave `recognitionRequest == nil` for ~0.5s and
/// DROP every audio buffer (and spoken word) in that window — we now stand up the
/// NEW request+task and swap it in BEFORE retiring the old one, keeping the audio
/// feed live the entire time. No words are lost across the restart boundary.
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
    /// Damped recycle timer — used ONLY for the silence (code 1110) and error
    /// recovery paths, so a quiet room cannot spin session restarts. The isFinal
    /// path uses an immediate seamless handoff (no timer, no audio gap).
    private var restartTimer: Timer?

    /// Weak reference to audio capture — stored at start() so the seamless handoff
    /// can keep feeding buffers into the freshly-created request.
    private weak var audioCaptureService: AudioCaptureService?
    /// Guards against re-entrant restart loops (rapid isFinal / error sequences)
    private var isRestarting = false

    // Configuration
    private let locale: Locale
    private let requiresOnDevice: Bool

    // Custom language model for Bible vocabulary
    private var bibleLanguageModel: BibleLanguageModel?

    // MARK: - Whisper engine (offline WhisperKit) — alternative to Apple on-device STT

    private lazy var whisper = WhisperTranscriber(model: "small.en")
    private var usingWhisper = false
    /// Engine choice. Defaults to WhisperKit (offline, punctuated, better accuracy).
    /// Falls back to Apple automatically if the Whisper model can't load.
    private var useWhisperSetting: Bool {
        if UserDefaults.standard.object(forKey: "useWhisperKit") == nil { return true }
        return UserDefaults.standard.bool(forKey: "useWhisperKit")
    }

    /// WhisperKit runs its CoreML models on the Apple Neural Engine / Metal. On Intel
    /// Macs those ops are unsupported (MPSGraph padded-tensor error) and the float16
    /// decoder init CRASHES with EXC_BAD_ACCESS — which a do/catch cannot recover. So we
    /// gate WhisperKit on Apple-Silicon hardware and fall back to Apple STT on Intel.
    ///
    /// We ALSO require the model to be installed on disk: the ~464 MB model is no longer
    /// bundled — it's downloaded on demand (first launch, Apple Silicon) by
    /// `WhisperModelManager`. Until it's present (or if the owner skipped/deferred the
    /// download, or the download failed), we transcribe with Apple STT so the app is
    /// always usable. Once installed, this flips to Whisper on the next start.
    private var shouldUseWhisper: Bool {
        useWhisperSetting && Self.isAppleSilicon && WhisperModelManager.isInstalled
    }

    /// True only on Apple-Silicon hardware. Single source of truth lives in
    /// `WhisperModelManager.isSupported` (same runtime sysctl) to avoid drift.
    static var isAppleSilicon: Bool { WhisperModelManager.isSupported }

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
        let granted: Bool = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
        // Whisper needs only microphone audio (requested separately by the pipeline), so a
        // denied Speech-Recognition permission must not block the offline Whisper engine.
        return shouldUseWhisper ? true : granted
    }

    /// Check if speech recognition is available
    var isAvailable: Bool {
        if shouldUseWhisper { return true }
        return speechRecognizer?.isAvailable ?? false
    }

    // MARK: - Transcription Control

    /// Start transcribing audio from the given audio capture service.
    /// Routes to the offline Whisper engine when enabled, else Apple's recognizer.
    func start(with audioCapture: AudioCaptureService) {
        audioCaptureService = audioCapture
        if shouldUseWhisper {
            startWhisper(with: audioCapture)
            return
        }
        if useWhisperSetting && !Self.isAppleSilicon {
            print("⚠️ [Transcription] WhisperKit requested but this is an Intel Mac — using Apple STT (Whisper needs Apple Silicon)")
        }
        startApple(with: audioCapture)
    }

    /// Apple SFSpeechRecognizer engine (on-device). Also the fallback when Whisper is off
    /// or its model cannot load.
    private func startApple(with audioCapture: AudioCaptureService) {
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

        // Retire any lingering session from a previous run (full teardown here is
        // fine — this is an external (re)start, not a seamless in-flight handoff).
        restartTimer?.invalidate()
        restartTimer = nil
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRestarting = false

        // Clear previous state
        error = nil
        transcript = ""
        lastTranscript = ""

        // Create the first recognition session
        guard beginRecognitionSession() else {
            // beginRecognitionSession sets `error` on failure
            return
        }

        // Subscribe to audio buffers (once — the seamless handoff keeps this alive)
        setupAudioBufferSubscription(audioCapture: audioCapture)

        isTranscribing = true
        print("✅ [Transcription] Transcription service started successfully")
    }

    /// WhisperKit engine (offline, on-device). Routes Whisper output through the SAME
    /// publishers as the Apple path, so detection, the transcript view, the mic selector,
    /// and the word-edit feature all work unchanged.
    private func startWhisper(with audioCapture: AudioCaptureService) {
        error = nil
        transcript = ""
        lastTranscript = ""
        usingWhisper = true

        whisper.onText = { [weak self] text, isFinal in
            guard let self else { return }
            self.transcript = text
            self.fullTranscriptPublisher.send(text)
            self.transcriptPublisher.send(
                TranscriptionSegment(text: text, timestamp: Date(), isFinal: isFinal)
            )
        }
        whisper.onStateChange = { [weak self] running in
            self?.isTranscribing = running
        }
        whisper.onError = { [weak self] message in
            guard let self else { return }
            print("⚠️ [Transcription] Whisper: \(message) — falling back to Apple recognizer")
            self.usingWhisper = false
            self.whisper.stop()
            self.ensureSpeechAuthThenStartApple(with: audioCapture)
        }

        isTranscribing = true // optimistic; confirmed once the model finishes loading
        whisper.start(audioPublisher: audioCapture.audioBufferPublisher)
        print("✅ [Transcription] Whisper engine starting (small.en, offline)")
    }

    /// Fallback entry that guarantees Speech authorization before starting Apple STT.
    /// `requestPermission()` intentionally masks a denied Speech permission when Whisper is
    /// the preferred engine — so if Whisper then fails to load at runtime, we must actually
    /// request Speech authorization here, or the Apple fallback would silently go dark.
    private func ensureSpeechAuthThenStartApple(with audioCapture: AudioCaptureService) {
        if authorizationStatus == .authorized {
            startApple(with: audioCapture)
            return
        }
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                self?.startApple(with: audioCapture)
            }
        }
    }

    /// Stop transcribing (external stop — full teardown)
    func stop() {
        if usingWhisper {
            whisper.stop()
            usingWhisper = false
        }
        restartTimer?.invalidate()
        restartTimer = nil

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        audioSubscription?.cancel()
        audioSubscription = nil

        isTranscribing = false
        isRestarting = false
        audioCaptureService = nil
    }

    // MARK: - Recognition Session Lifecycle

    /// Create, configure, and start a fresh recognition request + task, assigning
    /// them to `recognitionRequest` / `recognitionTask`. Does NOT touch the audio
    /// subscription, `audioCaptureService`, or `isTranscribing` — those are owned
    /// by start()/stop() and must survive a seamless handoff.
    /// Returns false (and sets `error`) if the recognizer is unavailable.
    @discardableResult
    private func beginRecognitionSession() -> Bool {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("❌ [Transcription] Recognizer not available for session start")
            error = .recognizerNotAvailable
            return false
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        // Only require on-device if the recognizer actually supports it on this device.
        // If supportsOnDeviceRecognition is false (model not downloaded or OS version gap),
        // hard-requiring it causes the recognition task to fail silently — audio flows,
        // meter responds, but no text is produced. Fall back to server-based in that case.
        let canUseOnDevice = speechRecognizer.supportsOnDeviceRecognition
        request.requiresOnDeviceRecognition = requiresOnDevice && canUseOnDevice
        if requiresOnDevice && !canUseOnDevice {
            print("⚠️ [Transcription] On-device recognition not supported on this device — falling back to server-based")
        }

        // Add custom Bible vocabulary if available
        configureCustomVocabulary(request: request)

        // Start recognition task.
        // CRITICAL: dispatch to main before calling handleRecognitionResult.
        // The SFSpeechRecognizer callback fires on a background thread, but this
        // class is @MainActor-isolated.
        let task = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.handleRecognitionResult(result: result, error: error)
            }
        }

        recognitionRequest = request
        recognitionTask = task
        print("✅ [Transcription] Recognition session started (onDevice: \(requiresOnDevice && canUseOnDevice))")
        return true
    }

    /// Seamless session handoff — used after `isFinal`, where dropping audio would
    /// drop spoken words. Stands up the NEW session and swaps it in BEFORE retiring
    /// the old one, so `appendAudioBuffer` always has a live request to feed and no
    /// audio buffer is discarded. `isTranscribing` stays true throughout (the display
    /// buffer relies on that — it only finalises when transcribing actually stops).
    private func restartSeamlessly() {
        guard !isRestarting, isTranscribing, audioCaptureService != nil else { return }
        isRestarting = true
        defer { isRestarting = false }

        let oldRequest = recognitionRequest
        let oldTask = recognitionTask

        // Create + swap in the new session first…
        guard beginRecognitionSession() else {
            // New session failed — keep the old one rather than going dark.
            recognitionRequest = oldRequest
            recognitionTask = oldTask
            print("⚠️ [Transcription] Seamless restart failed to create new session — keeping old")
            return
        }

        // …then retire the old one. Buffers arriving now feed the new request.
        lastTranscript = ""   // the new session's partial results start fresh
        oldRequest?.endAudio()
        oldTask?.cancel()
        print("🔄 [Transcription] Seamless session handoff complete (no audio gap)")
    }

    /// Damped recycle for the silence / error paths only. A quiet room repeatedly
    /// returns "no speech" (code 1110); restarting immediately there would spin the
    /// CPU, so we debounce. No spoken words are at risk during silence.
    private func scheduleDampedRestart() {
        restartTimer?.invalidate()
        restartTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.restartSeamlessly()
            }
        }
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

    /// Append audio buffer to the current recognition request.
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
            handleRecognitionError(error)
            return
        }

        guard let result = result else {
            return
        }

        let newTranscript = result.bestTranscription.formattedString

        // Only update if transcript changed
        if newTranscript != lastTranscript {
            lastTranscript = newTranscript

            transcript = newTranscript
            fullTranscriptPublisher.send(newTranscript)

            // Send segment for processing (display buffer + detection)
            let segment = TranscriptionSegment(
                text: newTranscript,
                timestamp: Date(),
                isFinal: result.isFinal
            )
            transcriptPublisher.send(segment)
        } else if result.isFinal {
            // Final result identical to the last partial: still emit a FINAL segment so
            // the display buffer commits this session as exactly one line. Without this,
            // the in-progress line is never finalised and the next session's cumulative
            // text stacks on top of it — the source of the duplicated-transcript bug.
            transcriptPublisher.send(
                TranscriptionSegment(text: newTranscript, timestamp: Date(), isFinal: true)
            )
        }

        // On final, hand off to a fresh session immediately — no audio gap, so the
        // next utterance is captured without losing the words in between.
        if result.isFinal {
            restartSeamlessly()
        }
    }

    private func handleRecognitionError(_ error: Error) {
        let nsError = error as NSError

        // Ignore cancelled errors — expected when we retire the old task during a
        // seamless handoff, and when stopping.
        if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
            return
        }

        // "No speech detected" — silence. Recycle the session on a damped timer so a
        // quiet room can't spin restarts. No spoken words are at risk here.
        if nsError.code == 1110 {
            scheduleDampedRestart()
            return
        }

        self.error = .recognitionFailed(error)
        print("❌ [Transcription] Recognition error: \(error.localizedDescription)")

        // Attempt recovery on a damped timer.
        scheduleDampedRestart()
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
