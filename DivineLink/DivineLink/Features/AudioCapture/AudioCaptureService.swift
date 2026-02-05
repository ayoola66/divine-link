import AVFoundation
import Combine
import CoreAudio

// MARK: - Audio Capture Errors

enum AudioCaptureError: LocalizedError {
    case deviceNotAvailable
    case permissionDenied
    case engineStartFailed(Error)
    case noInputAvailable
    case deviceSetupFailed
    
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
        case .deviceSetupFailed:
            return "Failed to configure audio device"
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
    /// Marked nonisolated(unsafe) because PassthroughSubject.send is thread-safe,
    /// and we need to call it from the audio processing queue
    nonisolated(unsafe) let audioBufferPublisher = PassthroughSubject<AVAudioPCMBuffer, Never>()
    
    // MARK: - Private Properties
    
    private var levelUpdateTimer: Timer?
    private var currentLevel: Float = 0.0
    private let levelSmoothingFactor: Float = 0.3
    
    // Audio processing queue for format conversion
    private let audioProcessingQueue = DispatchQueue(label: "com.divinelink.audio-processing", qos: .userInitiated)
    
    // Debug: Buffer counter to track audio flow
    // Marked nonisolated(unsafe) because it's accessed from audio processing queue
    nonisolated(unsafe) private var bufferCount = 0
    
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
    
    // MARK: - Device Selection
    
    /// Sets the input device for audio capture using Core Audio
    /// - Parameter device: The AVCaptureDevice to use for audio input
    /// - Returns: true if successful, false otherwise
    func setInputDevice(_ device: AVCaptureDevice) -> Bool {
        print("🎛️ [AudioCapture] Setting input device: \(device.localizedName)")
        
        // Stop capture if running
        let wasCapturing = isCapturing
        if wasCapturing {
            stop()
        }
        
        // Get the AudioDeviceID from the AVCaptureDevice's uniqueID
        guard let deviceID = getAudioDeviceID(for: device.uniqueID) else {
            print("❌ [AudioCapture] Could not find Core Audio device for: \(device.localizedName)")
            error = .deviceSetupFailed
            return false
        }
        
        print("🎛️ [AudioCapture] Found AudioDeviceID: \(deviceID)")
        
        // Set the device as the input for AVAudioEngine
        guard setAudioEngineInputDevice(deviceID) else {
            print("❌ [AudioCapture] Failed to set audio engine input device")
            error = .deviceSetupFailed
            return false
        }
        
        print("✅ [AudioCapture] Successfully set input device: \(device.localizedName)")
        
        // Restart capture if it was running
        if wasCapturing {
            start()
        }
        
        return true
    }
    
    /// Gets the Core Audio AudioDeviceID from an AVCaptureDevice uniqueID
    private func getAudioDeviceID(for uniqueID: String) -> AudioDeviceID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        
        guard status == noErr else {
            print("❌ [AudioCapture] Failed to get devices data size: \(status)")
            return nil
        }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &devices
        )
        
        guard status == noErr else {
            print("❌ [AudioCapture] Failed to get devices: \(status)")
            return nil
        }
        
        // Find the device with matching UID
        for deviceID in devices {
            if let deviceUID = getDeviceUID(for: deviceID), deviceUID == uniqueID {
                return deviceID
            }
        }
        
        return nil
    }
    
    /// Gets the UID string for an AudioDeviceID
    private func getDeviceUID(for deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        var uidPtr: Unmanaged<CFString>?
        
        let status = withUnsafeMutablePointer(to: &uidPtr) { ptr in
            AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &dataSize,
                ptr
            )
        }
        
        guard status == noErr, let uid = uidPtr?.takeRetainedValue() else {
            return nil
        }
        
        return uid as String
    }
    
    /// Sets the input device for AVAudioEngine using Core Audio
    private func setAudioEngineInputDevice(_ deviceID: AudioDeviceID) -> Bool {
        guard let audioEngine = audioEngine else { return false }
        
        // Get the underlying AudioUnit from the input node
        let inputNode = audioEngine.inputNode
        let audioUnit = inputNode.audioUnit
        
        guard let audioUnit = audioUnit else {
            print("❌ [AudioCapture] No AudioUnit available on input node")
            return false
        }
        
        var deviceIDCopy = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceIDCopy,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        
        if status != noErr {
            print("❌ [AudioCapture] Failed to set input device on AudioUnit: \(status)")
            return false
        }
        
        print("✅ [AudioCapture] AudioUnit input device set to: \(deviceID)")
        return true
    }
    
    // MARK: - Capture Control
    
    /// Starts audio capture from the current input device
    func start() {
        print("🎤 [AudioCapture] Start called")
        
        guard let audioEngine = audioEngine,
              let inputNode = inputNode else {
            print("❌ [AudioCapture] No audio engine or input node available")
            error = .noInputAvailable
            return
        }
        
        // Check if already capturing
        guard !isCapturing else {
            print("⚠️ [AudioCapture] Already capturing, skipping start")
            return
        }
        
        // Clear any previous error
        error = nil
        
        do {
            // Get the input format
            let format = inputNode.outputFormat(forBus: 0)
            print("🎤 [AudioCapture] Input format: \(format.sampleRate)Hz, \(format.channelCount) channels")
            
            // Verify format is valid
            guard format.sampleRate > 0 else {
                print("❌ [AudioCapture] Invalid sample rate: \(format.sampleRate)")
                error = .noInputAvailable
                return
            }
            
            // Capture references needed in the audio tap closure to avoid MainActor isolation issues
            let processingQueue = self.audioProcessingQueue
            let bufferPublisher = self.audioBufferPublisher
            
            // Install tap on input node with larger buffer to prevent overload
            // Increased from 1024 to 4096 to reduce HALC_ProxyIOContext overload errors
            print("🎤 [AudioCapture] Installing tap with format: \(format)")
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
                // Process audio on dedicated queue to prevent blocking
                processingQueue.async {
                    guard let self = self else {
                        print("⚠️ [AudioCapture] Self is nil in tap closure")
                        return
                    }
                    
                    // Debug: Log first buffer and every 100 buffers
                    self.bufferCount += 1
                    if self.bufferCount == 1 {
                        // Calculate RMS of source buffer to verify audio input
                        var sourceRMS: Float = 0
                        if let channelData = buffer.floatChannelData?[0] {
                            var sum: Float = 0
                            let frameCount = Int(buffer.frameLength)
                            for i in 0..<frameCount {
                                sum += channelData[i] * channelData[i]
                            }
                            sourceRMS = sqrt(sum / Float(max(frameCount, 1)))
                        }
                        print("🎉 [AudioCapture] First audio buffer received!")
                        print("   Source: \(format.channelCount)ch, \(Int(format.sampleRate))Hz, frames: \(buffer.frameLength)")
                        print("   Source RMS (ch0): \(sourceRMS) - \(sourceRMS > 0.001 ? "🔊 HAS AUDIO" : "🔇 SILENT/LOW")")
                    } else if self.bufferCount % 100 == 0 {
                        print("📊 [AudioCapture] Received \(self.bufferCount) audio buffers")
                    }
                    
                    // Convert to optimal format (16kHz mono) for speech recognition
                    if let convertedBuffer = self.convertToOptimalFormat(buffer, from: format) {
                        // Send converted buffer to subscribers
                        bufferPublisher.send(convertedBuffer)
                        
                        // Calculate audio level on background thread
                        self.processAudioBufferBackground(convertedBuffer)
                    } else {
                        // Fallback: send original buffer if conversion fails
                        print("⚠️ [AudioCapture] Format conversion failed, using original buffer")
                        bufferPublisher.send(buffer)
                        self.processAudioBufferBackground(buffer)
                    }
                }
            }
            print("✅ [AudioCapture] Tap installed successfully")
            
            // Start the engine
            try audioEngine.start()
            print("✅ [AudioCapture] Audio engine started successfully")
            
            isCapturing = true
            
            // Start level update timer for smooth UI updates
            startLevelUpdateTimer()
            
            print("🎤 [AudioCapture] Capture is now active, isCapturing: \(isCapturing)")
            
        } catch {
            print("❌ [AudioCapture] Failed to start engine: \(error.localizedDescription)")
            self.error = .engineStartFailed(error)
            isCapturing = false
        }
    }
    
    /// Stops audio capture
    func stop() {
        guard isCapturing else { return }
        
        print("🛑 [AudioCapture] Stopping capture (processed \(bufferCount) buffers)")
        
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        
        isCapturing = false
        audioLevel = 0.0
        peakLevel = 0.0
        bufferCount = 0
        
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
        
        // Update UI state on main actor
        Task { @MainActor [weak self] in
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
            Task { @MainActor [weak self] in
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
    
    /// Converts audio buffer to mono format for speech recognition
    /// Extracts first channel and keeps original sample rate (Speech framework handles rate conversion)
    nonisolated private func convertToOptimalFormat(_ buffer: AVAudioPCMBuffer, from sourceFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        // If already mono, return as-is
        if buffer.format.channelCount == 1 {
            return buffer
        }
        
        // For multi-channel audio, extract first channel to create mono buffer
        guard let sourceChannelData = buffer.floatChannelData else {
            print("❌ [AudioCapture] No channel data in buffer")
            return nil
        }
        
        // Create mono format with same sample rate
        guard let monoFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, 
                                              sampleRate: sourceFormat.sampleRate, 
                                              channels: 1, 
                                              interleaved: false) else {
            print("❌ [AudioCapture] Failed to create mono format")
            return nil
        }
        
        // Create output buffer
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: buffer.frameLength) else {
            print("❌ [AudioCapture] Failed to create mono output buffer")
            return nil
        }
        
        // Copy first channel data to mono buffer
        guard let outputChannelData = outputBuffer.floatChannelData else {
            print("❌ [AudioCapture] No output channel data")
            return nil
        }
        
        let frameCount = Int(buffer.frameLength)
        let sourceChannel = sourceChannelData[0] // First channel
        let destChannel = outputChannelData[0]
        
        // Copy samples from first channel
        for i in 0..<frameCount {
            destChannel[i] = sourceChannel[i]
        }
        
        outputBuffer.frameLength = buffer.frameLength
        
        // Log conversion details periodically
        if bufferCount % 500 == 1 {
            // Calculate RMS of output to verify audio data
            var rms: Float = 0
            var sum: Float = 0
            for i in 0..<frameCount {
                sum += destChannel[i] * destChannel[i]
            }
            rms = sqrt(sum / Float(max(frameCount, 1)))
            
            print("📊 [AudioCapture] Mono extraction: \(sourceFormat.channelCount)ch → 1ch, frames: \(frameCount), RMS: \(rms)")
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

