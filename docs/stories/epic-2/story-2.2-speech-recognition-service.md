# Story 2.2: Speech Recognition Service

**Epic:** 2 - Transcription & Scripture Detection  
**Story ID:** 2.2  
**Status:** Complete  
**Complexity:** Medium  

---

## User Story

**As a** developer,  
**I want** a service that transcribes audio to text using Apple's Speech framework,  
**so that** spoken words can be analysed for scripture references.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | `TranscriptionService` class created using SFSpeechRecognizer | Class compiles and initialises |
| 2 | Service requests and handles microphone/speech recognition permissions | Permission dialog appears; handles denial gracefully |
| 3 | Service receives audio buffer from AudioCaptureService | Audio flows from capture to transcription |
| 4 | Service produces streaming transcription results (partial and final) | Text updates as speech is recognised |
| 5 | Transcription uses British English locale (en-GB) | Recogniser configured for en-GB |
| 6 | Service handles recognition errors gracefully | Errors logged; service recovers |
| 7 | Service can be started/stopped on demand | start()/stop() work correctly |
| 8 | Memory is managed properly during extended operation | No leaks over 30+ minutes |

---

## Technical Notes

### TranscriptionService Implementation

```swift
import Speech
import AVFoundation
import Combine

class TranscriptionService: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    @Published var transcript: String = ""
    @Published var isTranscribing = false
    @Published var error: Error?
    
    // Publisher for new transcription segments
    var transcriptPublisher = PassthroughSubject<String, Never>()
    
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    func start(audioEngine: AVAudioEngine) throws {
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw TranscriptionError.requestCreationFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true // Local processing
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self?.transcript = text
                    self?.transcriptPublisher.send(text)
                }
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self?.error = error
                    self?.handleRecognitionError(error)
                }
            }
        }
        
        isTranscribing = true
    }
    
    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }
    
    func stop() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isTranscribing = false
    }
    
    private func handleRecognitionError(_ error: Error) {
        // Log error, attempt recovery
        print("Recognition error: \(error.localizedDescription)")
        
        // Auto-restart after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            // Restart logic here
        }
    }
}
```

### Permission Handling

```swift
// Check permission status
func checkPermissionStatus() -> SFSpeechRecognizerAuthorizationStatus {
    SFSpeechRecognizer.authorizationStatus()
}

// Handle different states
switch checkPermissionStatus() {
case .authorized:
    // Ready to use
case .denied:
    // Show settings redirect
case .restricted:
    // Device restricted
case .notDetermined:
    // Request permission
}
```

### Integration with AudioCaptureService

```swift
// In main coordinator/view model
audioService.audioBufferPublisher
    .sink { [weak self] buffer in
        self?.transcriptionService.appendAudioBuffer(buffer)
    }
    .store(in: &cancellables)
```

---

## Dependencies

- Story 1.3 (Audio Capture Engine)

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] Permissions requested and handled
- [ ] Real-time transcription working
- [ ] British English locale configured
- [ ] Error recovery implemented
- [ ] Memory tested with Instruments
- [ ] Committed to Git
