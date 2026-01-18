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
            
            // Install tap on input node
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                // Send buffer to subscribers
                self?.audioBufferPublisher.send(buffer)
                
                // Calculate audio level
                self?.processAudioBuffer(buffer)
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
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
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
        
        // Update on background thread, will be smoothed by timer
        currentLevel = normalizedLevel
        
        // Update peak immediately for responsiveness
        let peakCopy = normalizedPeak
        DispatchQueue.main.async {
            self.peakLevel = max(self.peakLevel * 0.95, peakCopy)
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

