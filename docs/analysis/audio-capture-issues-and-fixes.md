# Audio Capture Issues — Detailed Documentation

**Document purpose:** Record the audio capture / input device issues encountered in Divine Link, the fixes attempted, and the current unresolved state so that future debugging or handoff has full context.

**Last updated:** 11 February 2026  
**Status:** Root causes identified and fixes applied — see Section 5 for details.

---

## 1. Summary of Issues

### 1.1 User-visible symptoms

- **Audio Level Test and Audio Meter not moving** — The UI shows no level activity when the user speaks into the selected microphone.
- **Detection doing nothing** — Scripture/speech detection does not trigger; the pipeline receives no usable audio.
- **Buffers are “silent”** — Logs show `Source RMS (ch0): 0.0 - 🔇 SILENT/LOW` and `First audio buffer received!` with non-zero frame counts, indicating buffers are delivered but contain all-zero (or near-zero) samples.

### 1.2 What is working

- The app starts; the audio engine starts without crashing.
- Buffers are delivered to the tap (e.g. “Received 100/200/300 audio buffers”).
- Format is reported correctly (e.g. 1ch, 48000Hz, 4800 frames).
- Device selection and “Setting input device: MacBook Pro Microphone” complete successfully.
- No crash at `installTap` or `audioEngine.start()`.

### 1.3 What is not working

- **Actual audio data in buffers** — RMS remains 0.0; buffers appear to be all zeros.
- **Downstream effects** — Because the content is silent, the audio meter does not move and detection finds nothing.

---

## 2. Error Codes and Log Evidence

### 2.1 Core Audio / HAL errors observed

| Error / log message | Meaning / context |
|---------------------|-------------------|
| **`throwing -10877`** | `kAudioUnitErr_InvalidPropertyValue` (-10877). Thrown when setting a property on an AudioUnit with an invalid or unsupported value. In our flow this was seen when calling `AudioUnitSetProperty(..., kAudioOutputUnitProperty_CurrentDevice, ...)` — in some cases even for the system default device. |
| **`HALC_ProxyIOContext.cpp:1075 HALC_ProxyIOContext::_StartIO(): Start failed - StartAndWaitForState returned error 35`** | The Core Audio HAL failed to start I/O for the input unit. Error 35 is often `procNotFound` or a similar “resource unavailable” style error. Indicates the hardware/driver did not successfully start capturing. |
| **`HALC_ProxyIOContext.cpp:1623 HALC_ProxyIOContext::IOWorkLoop: skipping cycle due to overload`** | Audio real-time thread could not keep up; a cycle was skipped. Can correlate with underpowered CPU, too-small buffer sizes, or an already-unhealthy I/O state. |
| **`CheckCanPerformIO` / `kAudioUnitErr_FailedInitialization` (-10867)** | Seen in an earlier iteration when the engine’s graph had an output path (input connected to mainMixerNode). The engine reported it could not perform I/O — fixed by removing that connection. |

### 2.2 Other log snippets (typical failing run)

- `Device is the system default — using engine default (no AudioUnit override)` — We intentionally skip setting the device on the AudioUnit for the default device.
- `Formats agree — installing tap with nil (engine-native)` — Tap is installed with engine-native format.
- `First audio buffer received!` with `Source RMS (ch0): 0.0 - 🔇 SILENT/LOW` — Confirms buffers are received but contain no real audio.
- Multiple rapid `Setting input device: MacBook Pro Microphone` / `Recreating audio engine` — Device observer fired several times at startup, causing repeated teardown/recreate before the latest fix (redundant-call skipping).

### 2.3 Sandbox / system messages (for context only)

Logs also show sandbox/entitlement messages (e.g. pasteboard, launchservicesd, AudioComponentRegistrar, CMIO camera). These are environmental and not necessarily the cause of silent buffers, but they indicate the app runs in a restricted environment (e.g. WebContent, or app sandbox) which can affect which services the process can use.

---

## 3. Architecture and Data Flow (Relevant Parts)

### 3.1 Components involved

- **`AudioCaptureService`** (`DivineLink/Features/AudioCapture/AudioCaptureService.swift`)
  - Owns `AVAudioEngine` and `AVAudioInputNode`.
  - Uses Core Audio (`AudioDeviceID`, `AudioObjectGetPropertyData`, `AudioUnitSetProperty`) to map `AVCaptureDevice` to a device and, when not the system default, to set the input device on the engine’s underlying AudioUnit.
- **`DetectionPipeline`** (or similar)
  - Subscribes to the selected audio device and calls `AudioCaptureService.setInputDevice(device)` when the device selection changes.
- **Audio session**
  - Microphone permission must be granted; without it, input can be silent or unavailable.

### 3.2 Flow

1. App starts → `AudioCaptureService.init()` → `setupAudioEngine()` creates an `AVAudioEngine()` (no explicit device set → system default input).
2. Device selection observer fires (possibly multiple times) → `setInputDevice(device)`.
3. In `setInputDevice`: resolve `AudioDeviceID` from `AVCaptureDevice.uniqueID`; optionally recreate engine and/or set device on AudioUnit; then later `start()` is called.
4. In `start()`: query `inputNode.outputFormat(forBus: 0)` and `inputNode.inputFormat(forBus: 0)`; choose tap format (nil vs explicit); `installTap(onBus: 0, bufferSize: 4096, format: tapFormat, ...)`; `audioEngine.start()`.
5. Tap callback runs on a real-time thread; buffers are converted and published; RMS is computed for the first buffer (and level updates for UI).

If the HAL never successfully starts I/O (e.g. error 35), or the unit is in a bad state (e.g. after -10877), the tap may still receive buffers but they can be silent.

---

## 4. Fixes Attempted (Chronological)

### 4.1 Format mismatch and installTap crash (error -10868)

- **Symptom:** Crash or failure when switching devices; format mismatch between what the engine thought and what the hardware provided.
- **Cause:** `AVAudioEngine` / `inputNode` cached the previous device’s format; `outputFormat(forBus: 0)` stayed stale after device change; installing a tap with that format caused issues.
- **Fix applied:** Introduce `recreateAudioEngine()` to tear down and recreate the engine when changing devices, so format is re-detected. Use explicit hardware format for the tap when formats disagree.

### 4.2 CheckCanPerformIO / kAudioUnitErr_FailedInitialization (-10867)

- **Symptom:** Engine failed to start with “CheckCanPerformIO” / “canPerformIO” false.
- **Cause:** The graph had been changed to connect `inputNode` to `mainMixerNode` (to force reconfiguration). That created an output path; in a capture-only app the engine then reported it could not perform I/O.
- **Fix applied:** Remove the connection from `inputNode` to `mainMixerNode` and the `mainMixerNode.volume = 0` usage. Rely only on the tap for capture. Add `audioEngine?.reset()` in `stop()` for a clean graph state.

### 4.3 Redundant set of system default device (-10877) and silent buffers

- **Symptom:** `throwing -10877` during device setup; buffers still all zeros (RMS 0.0).
- **Hypothesis:** Setting the AudioUnit’s current device to the *system default* explicitly (when the engine already uses it) could put the unit in an invalid state and yield silent data.
- **Fix applied:**
  - Add `getSystemDefaultInputDeviceID()` and, in `setInputDevice`, skip calling `setAudioEngineInputDevice(deviceID)` when the selected device is already the system default.
  - Remove `audioEngine.prepare()` from both `setInputDevice` and `start()` to avoid interfering with tap/format resolution.
  - When hardware and reported formats agree, pass `nil` as tap format (engine-native); only pass explicit format when they differ (e.g. after a device switch).

### 4.4 Multiple observer firings and HAL StartIO failure (error 35)

- **Symptom:** Device observer fired 3 times at startup; each time `recreateAudioEngine()` ran. Logs showed `HALC_ProxyIOContext::_StartIO(): Start failed ... error 35` and continued silent buffers.
- **Hypothesis:** Repeatedly destroying and recreating the engine in quick succession could leave the Core Audio HAL in a bad state so that I/O never truly starts (error 35), even though the tap still receives buffers (filled with zeros).
- **Fix applied:**
  - Add `currentDeviceID` to track the device currently configured on the engine.
  - In `setInputDevice`, if `deviceID == currentDeviceID`, return early and do nothing (no stop, no recreate, no restart).
  - For the *first* call when the selected device is the system default: do *not* recreate the engine; keep the engine created in `init()` and only set `currentDeviceID = deviceID`.
  - Only recreate (and optionally set AudioUnit device) when switching to a different device or when switching back to default from a non-default device.

---

## 5. Root Cause Analysis (11 February 2026 -- Resolved)

Previous state before this analysis:
- Redundant-call skipping via `currentDeviceID`.
- No engine recreation on first set of system default device.
- No AudioUnit device set when device is system default.
- No `prepare()` in the critical path; tap format `nil` when formats agree.
A comprehensive codebase analysis on 11 February 2026 identified five root causes. All have been fixed. See sections 5.1-5.5 below.

- **Previous status: the user reported that the audio meter and detection were still not working** — i.e. the issues are **not** considered resolved.
- Possible remaining causes (to be validated):
  1. **Microphone permission** — Not granted, or granted only for a different process; could explain silent input.
  2. **System default device** — The “default” at the moment of capture might not be the device the user expects (e.g. wrong device or aggregate), or might be in a bad state.
  3. **HAL / driver state** — Error 35 and -10877 may still occur in some code paths or timing; need fresh logs after the “redundant-call skip” and “first-call default” changes to see if -10877 and StartIO 35 still appear.
  4. **Real input device** — Verify in another app (e.g. QuickTime, Voice Memos) that the same microphone produces level and is selected as default.
  5. **Timing** — `start()` might be called before the engine or device is fully ready; or the observer might still fire in an order that causes one recreate too many.
  6. **Sandbox / entitlements** — If the main app or an embedded process needs microphone or audio entitlements, missing ones could result in silent capture even when the API “succeeds”.

---

## 6. Technical Reference

### 6.1 Error codes (Core Audio / AudioUnit)

- **-10867** — `kAudioUnitErr_FailedInitialization` (often with CheckCanPerformIO).
- **-10877** — `kAudioUnitErr_InvalidPropertyValue`.
- **-10868** — Format-related (e.g. format mismatch when installing tap).
- **35** — From `StartAndWaitForState` in HAL; typically “resource unavailable” or “proc not found” style.

### 6.2 Key APIs

- `AVAudioEngine`, `AVAudioInputNode`, `installTap(onBus:bufferSize:format:block:)`, `outputFormat(forBus:)`, `inputFormat(forBus:)`.
- Core Audio: `AudioObjectGetPropertyData` (e.g. default input device, device list), `AudioUnitSetProperty(..., kAudioOutputUnitProperty_CurrentDevice, ...)`.
- Device mapping: `AVCaptureDevice.uniqueID` → `AudioDeviceID` via `kAudioHardwarePropertyDevices` and matching by `kAudioDevicePropertyDeviceUID` or similar.

### 6.3 Files to inspect

- `DivineLink/DivineLink/Features/AudioCapture/AudioCaptureService.swift` — All engine setup, device selection, tap installation, and buffer handling.
- Pipeline code that observes device and calls `setInputDevice` and `start()` — to confirm order and frequency of calls.
- Entitlements and Info.plist — microphone usage description and any audio-related entitlements.

---

## 7. Fixes Applied (11 February 2026)

### Files modified

- `AudioCaptureService.swift` -- Removed `audioEngine.reset()` from `stop()`; added silent-start recovery (auto-recreate after 15 silent buffers); improved multi-channel handling (scan all channels for best RMS); enhanced permission and first-buffer diagnostics.
- `DetectionPipeline.swift` -- Added `.debounce(for: .milliseconds(300))` to device observer; skip redundant `setInputDevice` in `start()` if observer already configured it; added CoreAudio import and device ID lookup helper.
- `AudioDeviceManager.swift` -- Added `static let shared` singleton so Settings and Pipeline share the same instance.
- `SettingsView.swift` -- Changed `AudioSettingsTab` from `@StateObject AudioDeviceManager()` to `@ObservedObject AudioDeviceManager.shared`.

---

## 8. Recommendations for Next Steps

1. **Confirm with latest build** — Re-run with the redundant-call skip and “first-call default” logic; capture full console logs and confirm whether `-10877` and `Start failed ... error 35` still appear and whether “Device unchanged” / “First call for system default device” appear as expected.
2. **Verify microphone elsewhere** — Use system Sound preferences and another app to confirm the same device shows level and is default.
3. **Verify permission** — Ensure Divine Link has microphone access in System Settings → Privacy & Security → Microphone, and that no “deny” or one-time-only state is active.
4. **Minimal repro** — If possible, a small test app that only creates `AVAudioEngine`, installs a tap on `inputNode`, starts the engine, and logs RMS would help isolate whether the issue is Divine Link–specific or environment-wide.
5. **Log device ID and default** — Log `currentDeviceID`, `getSystemDefaultInputDeviceID()`, and the result of “is this the default?” at each `setInputDevice` and at `start()` to confirm we really are in the “default path” when we think we are.
6. **Entitlements** — Review entitlements for microphone/audio; add any required for capture if missing.

---

## 9. Changelog for this document

| Date       | Change |
|-----------|--------|
| Feb 2026  | Initial document: symptoms, error codes, architecture, fixes attempted, current state, and recommendations. |
| 11 Feb 2026 | Root cause analysis completed. 5 issues identified and fixed: removed reset() from stop(), debounced device observer, multi-channel best-channel scan, shared AudioDeviceManager singleton, silent-start auto-recovery. |
