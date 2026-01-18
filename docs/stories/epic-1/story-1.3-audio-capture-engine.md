# Story 1.3: Audio Capture Engine

**Epic:** 1 - Foundation & Audio Capture  
**Story ID:** 1.3  
**Status:** Complete  
**Complexity:** Medium  

---

## User Story

**As a** developer,  
**I want** a service that captures audio from the selected input device,  
**so that** audio data is available for transcription.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | `AudioCaptureService` class created using AVAudioEngine | Class exists and compiles |
| 2 | Service starts/stops audio capture on demand | Call start()/stop(); audio flows/stops |
| 3 | Service uses the user-selected input device | Change device in settings; audio captured from new device |
| 4 | Audio is captured in a format compatible with SFSpeechRecognizer | Format: 16kHz or 48kHz, mono or stereo |
| 5 | Service handles device disconnection gracefully | Unplug mic; service enters error state, no crash |
| 6 | Service exposes audio buffer for downstream consumers | Buffer accessible for TranscriptionService |
| 7 | Memory is managed properly during extended capture | Run for 30+ minutes; no memory growth |

---

## Technical Notes

### AudioCaptureService Implementation

```swift
import AVFoundation
import Combine

class AudioCaptureService: ObservableObject {
    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode { audioEngine.inputNode }
    
    @Published var isCapturing = false
    @Published var error: Error?
    @Published var audioLevel: Float = 0.0
    
    // Buffer for speech recognition
    var audioBufferPublisher = PassthroughSubject<AVAudioPCMBuffer, Never>()
    
    func start() throws {
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            self?.audioBufferPublisher.send(buffer)
            self?.updateAudioLevel(buffer: buffer)
        }
        
        try audioEngine.start()
        isCapturing = true
    }
    
    func stop() {
        inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isCapturing = false
    }
    
    private func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frames = buffer.frameLength
        
        var sum: Float = 0
        for i in 0..<Int(frames) {
            sum += abs(channelData[i])
        }
        
        let average = sum / Float(frames)
        DispatchQueue.main.async {
            self.audioLevel = average
        }
    }
}
```

### Device Selection Integration

```swift
func setInputDevice(_ device: AVCaptureDevice) throws {
    // Get the audio device ID
    var deviceID = device.uniqueID
    
    // Set as system default or configure engine
    // Note: AVAudioEngine uses system default by default
    // For specific device, may need to use AudioUnit APIs
}
```

### Error Handling

```swift
enum AudioCaptureError: LocalizedError {
    case deviceNotAvailable
    case permissionDenied
    case engineStartFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .deviceNotAvailable:
            return "Audio device is not available"
        case .permissionDenied:
            return "Microphone permission denied"
        case .engineStartFailed(let error):
            return "Failed to start audio: \(error.localizedDescription)"
        }
    }
}
```

---

## Dependencies

- Story 1.1 (Project Scaffolding)
- Story 1.2 (Audio Input Selection)

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] Audio capture starts and stops cleanly
- [ ] Audio buffer accessible for transcription
- [ ] Memory tested with Instruments (no leaks)
- [ ] Error states handled gracefully
- [ ] Committed to Git
