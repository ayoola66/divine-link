import AVFoundation
import Combine

// MARK: - Audio Capture Errors

enum AudioCaptureError: LocalizedError {
    case deviceNotAvailable
    case permissionDenied
    case engineStartFailed(Error)
    case noInputAvailable
    
    var errorDescription: String? {
        switch self {
        case .deviceNotAvailable:
            return "Audio device is not available"
        case .permissionDenied:
            return "Microphone permission denied"
        case .engineStartFailed(let error):
            return "Failed to start audio: \(error.localizedDescription)"
        case .noInputAvailable:
            return "No audio input available"
        }
    }
}

// MARK: - Audio Capture Service

/// Service that captures audio from the selected input device
@MainActor
class AudioCaptureService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isCapturing = false
    @Published var error: AudioCaptureError?
    @Published var audioLevel: Float = 0.0
    @Published var peakLevel: Float = 0.0
    
    // MARK: - Audio Engine
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode? { audioEngine?.inputNode }
    
    // MARK: - Buffer Publisher
    
    /// Publisher for audio buffers - used by TranscriptionService
    let audioBufferPublisher = PassthroughSubject<AVAudioPCMBuffer, Never>()
    
    // MARK: - Private Properties
    
    private var levelUpdateTimer: Timer?
    private var currentLevel: Float = 0.0
    private let levelSmoothingFactor: Float = 0.3
    
    // Audio processing queue for format conversion
    private let audioProcessingQueue = DispatchQueue(label: "com.divinelink.audio-processing", qos: .userInitiated)
    
    // MARK: - Initialisation
    
    init() {
        setupAudioEngine()
    }
    
    deinit {
        levelUpdateTimer?.invalidate()
    }
    
    // MARK: - Setup
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
    }
    
    // MARK: - Capture Control
    
    /// Starts audio capture from the current input device
    func start() {
        guard let audioEngine = audioEngine,
              let inputNode = inputNode else {
            error = .noInputAvailable
            return
        }
        
        // Check if already capturing
        guard !isCapturing else { return }
        
        // Clear any previous error
        error = nil
        
        do {
            // Get the input format
            let format = inputNode.outputFormat(forBus: 0)
            
            // Verify format is valid
            guard format.sampleRate > 0 else {
                error = .noInputAvailable
                return
            }
            
            // Install tap on input node with larger buffer to prevent overload
            // Increased from 1024 to 4096 to reduce HALC_ProxyIOContext overload errors
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
                guard let self = self else { return }
                
                // Process audio on dedicated queue to prevent blocking
                self.audioProcessingQueue.async {
                    // Convert to optimal format (16kHz mono) for speech recognition
                    if let convertedBuffer = self.convertToOptimalFormat(buffer, from: format) {
                        // Send converted buffer to subscribers
                        self.audioBufferPublisher.send(convertedBuffer)
                        
                        // Calculate audio level on background thread
                        self.processAudioBufferBackground(convertedBuffer)
                    } else {
                        // Fallback: send original buffer if conversion fails
                        self.audioBufferPublisher.send(buffer)
                        self.processAudioBufferBackground(buffer)
                    }
                }
            }
            
            // Start the engine
            try audioEngine.start()
            
            isCapturing = true
            
            // Start level update timer for smooth UI updates
            startLevelUpdateTimer()
            
        } catch {
            self.error = .engineStartFailed(error)
            isCapturing = false
        }
    }
    
    /// Stops audio capture
    func stop() {
        guard isCapturing else { return }
        
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        
        isCapturing = false
        audioLevel = 0.0
        peakLevel = 0.0
        
        stopLevelUpdateTimer()
    }
    
    /// Toggles audio capture on/off
    func toggle() {
        if isCapturing {
            stop()
        } else {
            start()
        }
    }
    
    // MARK: - Audio Level Processing
    
    /// Process audio buffer on background thread (called from audio tap)
    nonisolated private func processAudioBufferBackground(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        guard frameLength > 0 else { return }
        
        // Calculate RMS (Root Mean Square) for better level representation
        var sum: Float = 0
        var peak: Float = 0
        
        for i in 0..<frameLength {
            let sample = abs(channelData[i])
            sum += sample * sample
            peak = max(peak, sample)
        }
        
        let rms = sqrt(sum / Float(frameLength))
        
        // Convert to a more usable 0-1 range
        // Typical speech is around 0.01-0.1 RMS
        let normalizedLevel = min(rms * 10, 1.0)
        let normalizedPeak = min(peak * 5, 1.0)
        
        // Update UI state on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentLevel = normalizedLevel
            self.peakLevel = max(self.peakLevel * 0.95, normalizedPeak)
        }
    }
    
    // MARK: - Level Update Timer
    
    private func startLevelUpdateTimer() {
        // Update UI at 30fps for smooth animation
        levelUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            // Hop to the main actor before touching any @MainActor-isolated state
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let currentLevelCopy = self.currentLevel
                let smoothingFactor = self.levelSmoothingFactor

                // Smooth the level for less jittery display
                self.audioLevel = self.audioLevel * (1 - smoothingFactor) + currentLevelCopy * smoothingFactor

                // Decay peak level slowly
                self.peakLevel *= 0.98
            }
        }
    }
    
    private func stopLevelUpdateTimer() {
        levelUpdateTimer?.invalidate()
        levelUpdateTimer = nil
    }
    
    // MARK: - Audio Format Conversion
    
    /// Converts audio buffer to optimal format for speech recognition (16kHz mono)
    /// This reduces processing overhead by ~75% compared to typical 48kHz stereo input
    nonisolated private func convertToOptimalFormat(_ buffer: AVAudioPCMBuffer, from sourceFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        // Create optimal format inline (not accessing main actor-isolated property)
        guard let optimalFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false) else {
            return nil
        }
        
        // If already in optimal format, return as-is
        if buffer.format.sampleRate == optimalFormat.sampleRate &&
           buffer.format.channelCount == optimalFormat.channelCount {
            return buffer
        }
        
        // Create converter
        guard let converter = AVAudioConverter(from: sourceFormat, to: optimalFormat) else {
            return nil
        }
        
        // Calculate output buffer size
        let ratio = optimalFormat.sampleRate / sourceFormat.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: optimalFormat, frameCapacity: outputFrameCapacity) else {
            return nil
        }
        
        // Convert
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("⚠️ Audio format conversion error: \(error.localizedDescription)")
            return nil
        }
        
        return outputBuffer
    }
    
    // MARK: - Permission Check
    
    /// Checks and requests microphone permission
    static func checkPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}

