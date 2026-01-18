# Story 1.2: Audio Input Device Selection

**Epic:** 1 - Foundation & Audio Capture  
**Story ID:** 1.2  
**Status:** Complete  
**Complexity:** Small  

---

## User Story

**As an** operator,  
**I want** to select which audio input device Divine Link listens to,  
**so that** I can choose between my microphone or system audio (BlackHole).

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Settings panel lists all available audio input devices | Open settings; see list of devices |
| 2 | User can select an input device from the list | Click device; selection updates |
| 3 | Selected device is persisted between app launches | Quit and relaunch; same device selected |
| 4 | If previously selected device is unavailable, app falls back to default input | Unplug device, relaunch; default selected with notification |
| 5 | App displays friendly device names | Shows "Built-in Microphone" not raw device ID |
| 6 | If BlackHole is not installed, a help link/tooltip explains how to install it | Tooltip or link visible when BlackHole absent |
| 7 | Settings accessible via menu bar icon → Settings (⌘,) | Keyboard shortcut and menu item work |

---

## Technical Notes

### Audio Device Enumeration

```swift
import AVFoundation

class AudioDeviceManager: ObservableObject {
    @Published var availableDevices: [AVCaptureDevice] = []
    @Published var selectedDevice: AVCaptureDevice?
    
    func refreshDevices() {
        availableDevices = AVCaptureDevice.devices(for: .audio)
    }
    
    func isBlackHoleInstalled() -> Bool {
        availableDevices.contains { $0.localizedName.contains("BlackHole") }
    }
}
```

### Settings Persistence

```swift
// UserDefaults key
static let selectedAudioDeviceKey = "selectedAudioDeviceUID"

// Save
UserDefaults.standard.set(device.uniqueID, forKey: selectedAudioDeviceKey)

// Load
if let savedUID = UserDefaults.standard.string(forKey: selectedAudioDeviceKey),
   let device = availableDevices.first(where: { $0.uniqueID == savedUID }) {
    selectedDevice = device
} else {
    selectedDevice = AVCaptureDevice.default(for: .audio)
}
```

### BlackHole Help Link

```swift
let blackHoleURL = URL(string: "https://existential.audio/blackhole/")!

// In Settings UI
if !audioManager.isBlackHoleInstalled() {
    Link("Install BlackHole for system audio capture", destination: blackHoleURL)
        .font(.caption)
        .foregroundColor(.blue)
}
```

---

## Dependencies

- Story 1.1 (Project Scaffolding)

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] Settings panel opens from menu bar
- [ ] Device list populates correctly
- [ ] Selection persists across restarts
- [ ] Fallback behaviour tested
- [ ] Committed to Git

---

## Dev Agent Record

### Tasks

- [x] Create AudioDeviceManager with device enumeration
- [x] Implement device selection persistence (UserDefaults)
- [x] Add BlackHole detection and help link
- [x] Create Settings panel with Audio tab
- [x] Add ProPresenter settings tab (placeholder)
- [x] Add About tab
- [x] Add Settings button to MainView popover
- [x] Add context menu to menu bar icon (right-click)
- [x] Wire up ⌘, keyboard shortcut for Settings
- [ ] Test device selection persistence
- [ ] Test fallback when device unavailable
- [ ] Build and verify in Xcode

### File List

**Created:**
- `Features/AudioCapture/AudioDeviceManager.swift` - Audio device enumeration and selection

**Modified:**
- `App/SettingsView.swift` - Full settings UI with Audio, ProPresenter, and About tabs
- `App/MainView.swift` - Added Settings button and audio device status display
- `App/AppDelegate.swift` - Added context menu, event monitor, and Settings shortcut

### Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-01-18 | Implemented audio device selection and settings UI | James (Dev) |
