import AVFoundation
import AppKit
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
    /// When non-nil, audio is working but we fell back to system default input (selected device failed).
    @Published var fallbackToDefaultDeviceMessage: String?
    @Published var audioLevel: Float = 0.0
    @Published var peakLevel: Float = 0.0
    /// True when Voice Processing I/O is active (AEC + noise suppression + AGC from Apple).
    @Published var isVoiceProcessingEnabled: Bool = false
    
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
    /// Used to show "Using system default" when a retry with default device succeeds.
    private var isRetryingWithDefaultDevice = false
    
    /// Tracks the AudioDeviceID currently configured on the engine so we can skip
    /// redundant setInputDevice calls (observers can fire multiple times at startup).
    /// Exposed as internal(set) so the pipeline can check whether a device switch is needed.
    private(set) var currentDeviceID: AudioDeviceID?

    /// Observer token for AVAudioEngineConfigurationChange notifications.
    /// Re-registered each time the engine is recreated so it always targets the live instance.
    private var engineConfigObserver: NSObjectProtocol?
    
    // Debug: Buffer counter to track audio flow
    // Marked nonisolated(unsafe) because it's accessed from audio processing queue
    nonisolated(unsafe) private var bufferCount = 0
    
    /// Counts consecutive silent buffers (RMS < threshold) after engine start.
    /// If we exceed `silentBufferRecoveryThreshold`, we attempt one automatic recovery.
    nonisolated(unsafe) private var consecutiveSilentBuffers = 0
    /// Whether we've already attempted silent-start recovery for this capture session.
    nonisolated(unsafe) private var hasAttemptedSilentRecovery = false
    /// Number of consecutive silent buffers before triggering automatic recovery.
    private let silentBufferRecoveryThreshold = 15
    
    // MARK: - Initialisation
    
    init() {
        setupAudioEngine()
        observeEngineConfiguration()
    }

    deinit {
        levelUpdateTimer?.invalidate()
        if let observer = engineConfigObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Setup
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        // Voice processing is enabled in start() just before installTap,
        // keeping it off the init/setup path to avoid QoS inversion at launch.
    }

    /// Registers a listener for AVAudioEngineConfigurationChange on the current engine instance.
    /// Must be called after every engine creation (init and recreateAudioEngine) so the observer
    /// always targets the live engine. When macOS changes audio routing (device plug/unplug,
    /// Bluetooth connect, sample-rate change), the engine becomes invalid — we restart capture
    /// automatically to recover without crashing or producing silent buffers.
    private func observeEngineConfiguration() {
        if let existing = engineConfigObserver {
            NotificationCenter.default.removeObserver(existing)
            engineConfigObserver = nil
        }
        guard let engine = audioEngine else { return }
        engineConfigObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isCapturing else { return }
                print("⚠️ [AudioCapture] Engine configuration changed (route/device change) — restarting capture")
                self.stop()
                self.start()
            }
        }
    }

    /// Enables Apple's Voice Processing I/O on the input node.
    /// This activates AEC (acoustic echo cancellation), built-in noise suppression,
    /// and automatic gain control — improving STT accuracy in live church environments.
    /// Must be called after engine creation and before installing any tap.
    private func enableVoiceProcessing() {
        guard let audioEngine = audioEngine else { return }
        do {
            try audioEngine.inputNode.setVoiceProcessingEnabled(true)
            isVoiceProcessingEnabled = true
            print("✅ [AudioCapture] Voice Processing I/O enabled (AEC + noise suppression + AGC)")
        } catch {
            isVoiceProcessingEnabled = false
            print("⚠️ [AudioCapture] Voice Processing I/O not available: \(error.localizedDescription) — using standard I/O")
        }
    }
    
    // MARK: - Device Selection
    
    /// Sets the input device for audio capture using Core Audio
    /// - Parameter device: The AVCaptureDevice to use for audio input
    /// - Returns: true if successful, false otherwise
    func setInputDevice(_ device: AVCaptureDevice) -> Bool {
        print("🎛️ [AudioCapture] Setting input device: \(device.localizedName)")
        fallbackToDefaultDeviceMessage = nil
        
        // Get the AudioDeviceID from the AVCaptureDevice's uniqueID
        guard let deviceID = getAudioDeviceID(for: device.uniqueID) else {
            print("❌ [AudioCapture] Could not find Core Audio device for: \(device.localizedName)")
            error = .deviceSetupFailed
            return false
        }
        
        print("🎛️ [AudioCapture] Found AudioDeviceID: \(deviceID)")
        
        // ── Skip if the engine is already configured for this device ──
        // The device-selection observer can fire multiple times at startup for the same
        // device. Recreating the engine each time disrupts the Core Audio HAL state and
        // causes HALC_ProxyIOContext::_StartIO failures (error 35), which results in
        // the tap delivering all-zero (silent) buffers.
        if deviceID == currentDeviceID {
            print("🎛️ [AudioCapture] Device unchanged (ID \(deviceID)) — skipping")
            return true
        }
        
        // Stop capture if running
        let wasCapturing = isCapturing
        if wasCapturing {
            stop()
        }
        
        let systemDefault = getSystemDefaultInputDeviceID()
        let isSystemDefault = (deviceID == systemDefault)
        
        if currentDeviceID == nil && isSystemDefault {
            // ── First call, default device ──
            // The engine created during init already uses the system default input.
            // No need to recreate or modify it — just record the device ID.
            print("🎛️ [AudioCapture] First call for system default device — keeping init engine as-is")
        } else if isSystemDefault {
            // ── Switching back to the default from a non-default device ──
            // Recreate to clear the previous device's cached format, but don't
            // call setAudioEngineInputDevice — the fresh engine defaults to it.
            print("🎛️ [AudioCapture] Switching back to system default — recreating engine")
            recreateAudioEngine()
        } else {
            // ── Switching to a non-default device ──
            // Recreate the engine AND set the device on the AudioUnit.
            print("🎛️ [AudioCapture] Non-default device — recreating engine and setting AudioUnit")
            recreateAudioEngine()
            // Force-initialise the input node before setting the device.
            // On a freshly created AVAudioEngine, inputNode.audioUnit is nil until
            // any property on the node is accessed — AVFoundation initialises the
            // underlying AUHAL lazily. Without this, AudioUnitSetProperty fails
            // silently and the device is never configured.
            _ = audioEngine?.inputNode.inputFormat(forBus: 0)
            guard setAudioEngineInputDevice(deviceID) else {
                print("❌ [AudioCapture] Failed to set audio engine input device")
                error = .deviceSetupFailed
                return false
            }
        }
        
        currentDeviceID = deviceID
        // Reset silent-start recovery so the new device gets a fresh detection window
        hasAttemptedSilentRecovery = false
        consecutiveSilentBuffers = 0
        print("✅ [AudioCapture] Successfully set input device: \(device.localizedName)")
        
        // Restart capture if it was running
        if wasCapturing {
            start()
        }
        
        return true
    }
    
    /// Recreates the AVAudioEngine to clear all cached format state.
    /// This is essential when switching audio devices, as the engine's inputNode
    /// caches the previous device's format and does not update it reliably.
    private func recreateAudioEngine() {
        print("🔄 [AudioCapture] Recreating audio engine for fresh format detection")
        
        // Tear down existing engine completely.
        // NOTE: Do NOT call audioEngine?.reset() here — same reason as stop():
        // reset() corrupts Core Audio HAL state and causes the new engine to
        // deliver silent buffers on start. Just nil out; ARC handles deallocation.
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        
        // Create a fresh engine — its inputNode will pick up the correct hardware format
        // Voice processing is enabled in start() just before installTap.
        audioEngine = AVAudioEngine()
        observeEngineConfiguration()
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
    
    /// Returns the system's current default input AudioDeviceID, or nil on failure.
    private func getSystemDefaultInputDeviceID() -> AudioDeviceID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
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
    
    /// Starts audio capture from the current input device.
    /// When `allowRetryWithDefaultDevice` is true and start fails (e.g. canPerformIO), we recreate the engine
    /// (so it uses system default input) and try once more so the user gets working audio.
    func start(allowRetryWithDefaultDevice: Bool = true) {
        print("🎤 [AudioCapture] Start called (allowRetry: \(allowRetryWithDefaultDevice))")
        
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
        
        // ── Permission gate ──
        // If microphone permission is denied, do NOT attempt to start the engine.
        // Core Audio will deliver zero-filled (silent) buffers when permission is
        // denied, making it look like the engine works but producing no actual audio.
        let permissionStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        guard permissionStatus == .authorized else {
            print("❌ [AudioCapture] Cannot start — microphone permission is \(Self.statusDescription(permissionStatus))")
            self.error = .permissionDenied
            return
        }
        
        // Clear any previous error and fallback message
        error = nil
        if !isRetryingWithDefaultDevice { fallbackToDefaultDeviceMessage = nil }
        
        // Reset silent-buffer detection for this new capture session
        // (hasAttemptedSilentRecovery is reset so each start() gets one recovery chance)
        consecutiveSilentBuffers = 0
        if !hasAttemptedSilentRecovery || allowRetryWithDefaultDevice {
            hasAttemptedSilentRecovery = false
        }
        
        do {
            // Query both the cached output format and the actual hardware format.
            // After a device switch, outputFormat(forBus:) often returns a stale cached
            // format (e.g. 48000Hz/1ch) that doesn't match the new hardware (e.g. 44100Hz/2ch).
            // inputFormat(forBus:) always reflects the real hardware.
            let reportedFormat = inputNode.outputFormat(forBus: 0)
            let hwFormat = inputNode.inputFormat(forBus: 0)
            
            print("🎤 [AudioCapture] Reported output format: \(reportedFormat.sampleRate)Hz, \(reportedFormat.channelCount) channels")
            print("🎤 [AudioCapture] Hardware input format:   \(hwFormat.sampleRate)Hz, \(hwFormat.channelCount) channels")
            
            // Determine whether the formats agree.
            // When they match, we pass nil to installTap so the engine uses its native
            // pipeline — this is the most reliable path for the system-default device.
            // When they differ (after a device switch), we must pass the hardware format
            // explicitly so the engine doesn't use the stale outputFormat.
            let formatsMatch = hwFormat.sampleRate > 0
                && hwFormat.channelCount > 0
                && hwFormat.sampleRate == reportedFormat.sampleRate
                && hwFormat.channelCount == reportedFormat.channelCount
            
            let tapFormat: AVAudioFormat?
            if formatsMatch {
                // Default device or device whose hw format already matches — let the
                // engine resolve format internally (nil = outputFormat, which is correct).
                tapFormat = nil
                print("🎤 [AudioCapture] Formats agree — installing tap with nil (engine-native)")
            } else if hwFormat.sampleRate > 0 && hwFormat.channelCount > 0 {
                // Device switch caused a mismatch — force the hardware format.
                tapFormat = hwFormat
                print("⚠️ [AudioCapture] Format mismatch detected — installing tap with hardware format: \(hwFormat)")
            } else if reportedFormat.sampleRate > 0 {
                tapFormat = reportedFormat
                print("⚠️ [AudioCapture] Hardware format invalid, falling back to reported format")
            } else {
                print("❌ [AudioCapture] Invalid sample rate on both formats")
                error = .noInputAvailable
                return
            }
            
            // Capture references needed in the audio tap closure to avoid MainActor isolation issues
            let processingQueue = self.audioProcessingQueue
            let bufferPublisher = self.audioBufferPublisher
            
            // Voice Processing I/O (AEC/noise suppression) is intentionally disabled.
            // setVoiceProcessingEnabled(true) conflicts with SFSpeechRecognizer's internal
            // audio pipeline, causing HALC overload, encoding failures, and silent transcription.
            // SFSpeechRecognizer applies its own noise reduction; no VP IO needed here.

            // Install the tap. nil lets the engine use its native format (safest for
            // the default device); an explicit format is used after device switches
            // where the cached outputFormat would cause a mismatch.
            print("🎤 [AudioCapture] Installing tap with format: \(tapFormat?.description ?? "nil (engine-native)")")
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { [weak self] buffer, _ in
                // Process audio on dedicated queue to prevent blocking
                processingQueue.async {
                    guard let self = self else {
                        print("⚠️ [AudioCapture] Self is nil in tap closure")
                        return
                    }
                    
                    // Debug: Log first buffer and periodically
                    self.bufferCount += 1
                    if self.bufferCount == 1 {
                        let chCount = Int(buffer.format.channelCount)
                        let frameCount = Int(buffer.frameLength)
                        
                        // Calculate RMS for ALL channels on first buffer for diagnostics
                        var channelRMSInfo = ""
                        var anyChannelHasAudio = false
                        if let channelData = buffer.floatChannelData {
                            for ch in 0..<chCount {
                                var sum: Float = 0
                                for i in 0..<frameCount {
                                    sum += channelData[ch][i] * channelData[ch][i]
                                }
                                let rms = sqrt(sum / Float(max(frameCount, 1)))
                                if rms > 0.001 { anyChannelHasAudio = true }
                                channelRMSInfo += " ch\(ch)=\(String(format: "%.6f", rms))"
                            }
                        }
                        
                        print("🎉 [AudioCapture] First audio buffer received!")
                        print("   Actual buffer format: \(chCount)ch, \(Int(buffer.format.sampleRate))Hz, frames: \(frameCount)")
                        print("   Per-channel RMS:\(channelRMSInfo)")
                        print("   Audio status: \(anyChannelHasAudio ? "🔊 HAS AUDIO" : "🔇 ALL CHANNELS SILENT")")
                    } else if self.bufferCount % 100 == 0 {
                        print("📊 [AudioCapture] Received \(self.bufferCount) audio buffers")
                    }
                    
                    // ── Silent-start detection ──
                    // If the first N buffers are all silent, the Core Audio HAL may be
                    // in a bad state. Attempt automatic recovery by recreating the engine.
                    if !self.hasAttemptedSilentRecovery {
                        // Quick RMS check across all channels
                        var anyAudio = false
                        if let chData = buffer.floatChannelData {
                            let fc = Int(buffer.frameLength)
                            for ch in 0..<Int(buffer.format.channelCount) {
                                var s: Float = 0
                                for i in 0..<fc { s += chData[ch][i] * chData[ch][i] }
                                if sqrt(s / Float(max(fc, 1))) > 0.0005 {
                                    anyAudio = true
                                    break
                                }
                            }
                        }
                        if anyAudio {
                            self.consecutiveSilentBuffers = 0
                        } else {
                            self.consecutiveSilentBuffers += 1
                            if self.consecutiveSilentBuffers >= self.silentBufferRecoveryThreshold {
                                self.hasAttemptedSilentRecovery = true
                                print("⚠️ [AudioCapture] \(self.silentBufferRecoveryThreshold) consecutive silent buffers detected — triggering automatic recovery")
                                Task { @MainActor [weak self] in
                                    self?.performSilentStartRecovery()
                                }
                                return // Skip processing this silent buffer
                            }
                        }
                    }
                    
                    // Convert to mono format for speech recognition
                    // Use the buffer's own format (which reflects actual hardware)
                    if let convertedBuffer = self.convertToOptimalFormat(buffer, from: buffer.format) {
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
            
            if isRetryingWithDefaultDevice {
                fallbackToDefaultDeviceMessage = "Using system default input because the selected device could not be used."
                isRetryingWithDefaultDevice = false
            }
            
            // Start level update timer for smooth UI updates
            startLevelUpdateTimer()
            
            print("🎤 [AudioCapture] Capture is now active, isCapturing: \(isCapturing)")
            
        } catch {
            print("❌ [AudioCapture] Failed to start engine: \(error.localizedDescription)")
            self.error = .engineStartFailed(error)
            isCapturing = false
            // Recreate the engine so we are not left in a half-configured state.
            recreateAudioEngine()
            // One retry with system default input (no device set = default). Often fixes canPerformIO / -10877.
            if allowRetryWithDefaultDevice {
                print("🔄 [AudioCapture] Retrying with system default input...")
                isRetryingWithDefaultDevice = true
                start(allowRetryWithDefaultDevice: false)
                if !isCapturing { isRetryingWithDefaultDevice = false }
            }
        }
    }
    
    /// Stops audio capture.
    /// IMPORTANT: We intentionally do NOT call audioEngine.reset() here.
    /// reset() tears down the entire audio processing graph and corrupts the Core Audio
    /// HAL state, causing subsequent starts to deliver all-zero (silent) buffers — even
    /// after engine recreation. removeTap + stop is sufficient for a clean pause;
    /// recreateAudioEngine() handles full teardown when switching devices.
    func stop() {
        guard isCapturing else { return }
        
        print("🛑 [AudioCapture] Stopping capture (processed \(bufferCount) buffers)")
        
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        // NOTE: Do NOT call audioEngine?.reset() — it corrupts Core Audio HAL state
        // and causes silent buffers on restart (throwing -10877 / StartIO error 35).
        
        isCapturing = false
        audioLevel = 0.0
        peakLevel = 0.0
        bufferCount = 0
        consecutiveSilentBuffers = 0

        stopLevelUpdateTimer()
    }
    
    /// Automatic recovery when the HAL delivers only silent buffers after engine start.
    /// Recreates the engine from scratch (no reset()) and restarts capture once.
    private func performSilentStartRecovery() {
        print("🔄 [AudioCapture] Silent-start recovery: recreating engine and restarting…")
        
        // Stop current capture
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        isCapturing = false
        bufferCount = 0
        consecutiveSilentBuffers = 0
        stopLevelUpdateTimer()
        
        // Recreate engine (this does NOT call reset())
        audioEngine = nil
        audioEngine = AVAudioEngine()
        
        // Re-apply the current device if it was non-default
        if let deviceID = currentDeviceID {
            let systemDefault = getSystemDefaultInputDeviceID()
            if deviceID != systemDefault {
                let _ = setAudioEngineInputDevice(deviceID)
            }
        }
        
        // Restart capture (the hasAttemptedSilentRecovery flag prevents infinite loops)
        start(allowRetryWithDefaultDevice: false)
        
        if isCapturing {
            print("✅ [AudioCapture] Silent-start recovery: engine restarted successfully")
        } else {
            print("❌ [AudioCapture] Silent-start recovery: restart failed")
        }
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
    
    /// Converts audio buffer to mono format for speech recognition.
    /// For multi-channel devices (e.g. Focusrite Vocaster Two with 14 channels),
    /// scans all channels to find the one with the highest RMS and uses that as the
    /// source — channel 0 is not always the physical microphone input on USB interfaces.
    nonisolated private func convertToOptimalFormat(_ buffer: AVAudioPCMBuffer, from sourceFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        // If already mono, return as-is
        if buffer.format.channelCount == 1 {
            return buffer
        }
        
        // For multi-channel audio, find the best channel and extract to mono
        guard let sourceChannelData = buffer.floatChannelData else {
            print("❌ [AudioCapture] No channel data in buffer")
            return nil
        }
        
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        
        // Find the channel with the highest RMS (most likely the active mic input).
        // On multi-channel interfaces like the Vocaster Two, channel 0 may be a
        // mix/monitor bus rather than the physical microphone.
        var bestChannel = 0
        var bestRMS: Float = 0
        
        for ch in 0..<channelCount {
            let channelPtr = sourceChannelData[ch]
            var sum: Float = 0
            for i in 0..<frameCount {
                sum += channelPtr[i] * channelPtr[i]
            }
            let rms = sqrt(sum / Float(max(frameCount, 1)))
            if rms > bestRMS {
                bestRMS = rms
                bestChannel = ch
            }
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
        
        // Copy best channel data to mono buffer
        guard let outputChannelData = outputBuffer.floatChannelData else {
            print("❌ [AudioCapture] No output channel data")
            return nil
        }
        
        let sourceChannel = sourceChannelData[bestChannel]
        let destChannel = outputChannelData[0]
        
        // Copy samples from selected channel
        for i in 0..<frameCount {
            destChannel[i] = sourceChannel[i]
        }
        
        outputBuffer.frameLength = buffer.frameLength
        
        // Log conversion details periodically (and on first buffer for diagnostics)
        if bufferCount == 1 || bufferCount % 500 == 0 {
            // Log per-channel RMS on first buffer for debugging multi-channel devices
            if bufferCount == 1 && channelCount > 2 {
                var channelInfo = "📊 [AudioCapture] Per-channel RMS (\(channelCount)ch):"
                for ch in 0..<min(channelCount, 16) {
                    let chPtr = sourceChannelData[ch]
                    var s: Float = 0
                    for i in 0..<frameCount { s += chPtr[i] * chPtr[i] }
                    let r = sqrt(s / Float(max(frameCount, 1)))
                    channelInfo += " ch\(ch)=\(String(format: "%.6f", r))"
                }
                print(channelInfo)
            }
            print("📊 [AudioCapture] Mono extraction: \(channelCount)ch → 1ch (using ch\(bestChannel)), frames: \(frameCount), RMS: \(String(format: "%.6f", bestRMS))")
        }
        
        return outputBuffer
    }
    
    // MARK: - Permission Check
    
    /// Checks and requests microphone permission, with diagnostic logging.
    static func checkPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        print("🔐 [AudioCapture] Microphone permission status: \(statusDescription(status))")
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            print("🔐 [AudioCapture] Requesting microphone permission…")
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            print("🔐 [AudioCapture] Permission request result: \(granted ? "✅ granted" : "❌ denied")")
            return granted
        case .denied:
            print("❌ [AudioCapture] Microphone permission DENIED — user must grant in System Settings → Privacy & Security → Microphone")
            return false
        case .restricted:
            print("❌ [AudioCapture] Microphone permission RESTRICTED — managed by system policy")
            return false
        @unknown default:
            print("❌ [AudioCapture] Unknown microphone permission status: \(status.rawValue)")
            return false
        }
    }
    
    /// Human-readable description of AVAuthorizationStatus for logging
    private static func statusDescription(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .restricted: return "restricted"
        @unknown default: return "unknown(\(status.rawValue))"
        }
    }
    
    /// Opens System Settings to the Microphone privacy pane so the user can grant permission.
    static func openMicrophonePrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}

