# Audio Quality Stress Test Analysis

**Date:** February 1, 2026  
**Test Scenario:** Open speaker audio capture in church auditorium  
**Result:** Poor performance  
**Analyst:** Code Review & Analysis

---

## Executive Summary

The app performed poorly when capturing audio from open speakers in an auditorium environment. This stress test revealed several critical gaps in audio preprocessing that are essential for handling real-world acoustic challenges like echo, reverb, background noise, and varying audio levels.

---

## Identified Issues

### 1. **No Audio Preprocessing Pipeline** ⚠️ CRITICAL

**Current State:**
- Audio buffers are passed directly from `AVAudioEngine` to `SFSpeechRecognizer`
- No noise reduction, echo cancellation, or audio enhancement filters
- Raw audio includes all environmental artifacts (echo, reverb, background noise)

**Impact:**
- Speech recognition accuracy severely degraded in reverberant environments
- Echo from speakers causes recognition to "hear" words multiple times
- Background noise interferes with speech clarity
- Varying audio levels cause recognition to miss quiet passages

**Code Location:**
```swift
// AudioCaptureService.swift:98-106
inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
    guard let self = self else { return }
    
    // Send buffer to subscribers (can be called from any thread)
    self.audioBufferPublisher.send(buffer)  // ← Direct pass-through, no processing
    
    // Calculate audio level on background thread
    self.processAudioBufferBackground(buffer)
}
```

---

### 2. **Suboptimal Buffer Size** ⚠️ HIGH

**Current State:**
- Fixed buffer size of 1024 samples
- No consideration for echo/reverb delay times
- May cause audio artifacts with echo cancellation

**Impact:**
- Too small for effective echo cancellation (typically needs 2048-4096 samples)
- May cause audio dropouts or glitches
- Not optimised for speech recognition (Apple recommends 16000Hz sample rate)

**Code Location:**
```swift
// AudioCaptureService.swift:98
inputNode.installTap(onBus: 0, bufferSize: 1024, format: format)
```

---

### 3. **No Automatic Gain Control (AGC)** ⚠️ HIGH

**Current State:**
- Audio levels are measured but not normalised
- No dynamic range compression
- Speech recognition receives varying input levels

**Impact:**
- Quiet passages may be missed entirely
- Loud passages may cause distortion
- Inconsistent recognition accuracy across volume variations

**Code Location:**
```swift
// AudioCaptureService.swift:148-177
// Only calculates levels, doesn't normalise audio
nonisolated private func processAudioBufferBackground(_ buffer: AVAudioPCMBuffer) {
    // ... calculates RMS and peak levels
    // But doesn't apply gain control to the buffer
}
```

---

### 4. **No Audio Format Optimisation** ⚠️ MEDIUM

**Current State:**
- Uses whatever format the input device provides
- No conversion to optimal format for speech recognition
- May use non-optimal sample rates or bit depths

**Impact:**
- Suboptimal quality for speech recognition
- Unnecessary processing overhead
- Potential compatibility issues

**Recommended:**
- Convert to 16kHz mono (optimal for speech recognition)
- Use 16-bit PCM format
- Ensure consistent sample rate

---

### 5. **No Echo Cancellation** ⚠️ CRITICAL

**Current State:**
- No echo cancellation algorithm implemented
- Audio from speakers feeds back into microphone
- Causes recognition to "hear" delayed/repeated words

**Impact:**
- **Primary cause of poor performance in auditorium test**
- Recognition sees same words multiple times (original + echo)
- Confuses speech recognition engine
- Causes false detections and missed detections

**Technical Note:**
- Echo cancellation requires:
  - Reference signal (what was played through speakers)
  - Delay estimation
  - Adaptive filtering
  - For this use case, simpler approach: high-pass filter + noise gate

---

### 6. **No Noise Gate** ⚠️ MEDIUM

**Current State:**
- All audio is processed, including silence and background noise
- No threshold-based gating

**Impact:**
- Background noise processed unnecessarily
- Wastes processing power
- May cause false activations

---

### 7. **No High-Pass Filter** ⚠️ MEDIUM

**Current State:**
- Full frequency spectrum captured
- Low-frequency rumble and noise included

**Impact:**
- Low-frequency noise interferes with speech
- Wastes bandwidth on non-speech frequencies
- Reduces signal-to-noise ratio

**Recommended:**
- High-pass filter at 80-100Hz to remove rumble
- Low-pass filter at 8kHz (speech frequencies)

---

## Root Cause Analysis

### Why Performance Was "Awful"

**Evidence from Logs:**

1. **Audio Hardware Overload** ⚠️ CRITICAL
   - `HALC_ProxyIOContext::IOWorkLoop: skipping cycle due to overload` (repeated 50+ times)
   - `throwing -10877` (Core Audio error: kAudioUnitErr_FormatNotSupported or similar)
   - `HALC_ShellObject::SetPropertyData: call to the proxy failed` - Hardware communication failures
   - **Impact:** Audio system cannot keep up with processing demands, causing dropouts and corruption

2. **Severely Degraded Transcription Quality** ⚠️ CRITICAL
   - Common words misidentified as book names:
     - `⚠️ Book not recognized: 'for' (pattern: chapterOnly)`
     - `⚠️ Book not recognized: 'of' (pattern: chapterOnly)`
     - `⚠️ Book not recognized: 'on' (pattern: chapterOnly)`
     - `⚠️ Book not recognized: 'and' (pattern: chapterOnly)`
   - Complete misidentification: `📖 Parsing match: book='drop'→'Romans'`
   - False detection: `Detected scripture: Romans 20:1` (Romans only has 16 chapters)
   - **Impact:** Speech recognition is producing gibberish due to poor audio quality

3. **Echo/Reverb Dominance**
   - Audio from speakers bounces off walls and ceiling
   - Creates delayed, attenuated copies of the original signal
   - Speech recognition engine receives multiple overlapping versions
   - Cannot distinguish original from echo

4. **Poor Signal-to-Noise Ratio**
   - Background noise (HVAC, movement, etc.) mixed with speech
   - No noise reduction means noise competes with speech
   - Recognition engine struggles to identify speech patterns

5. **Varying Audio Levels**
   - Distance from speakers causes level variations
   - No AGC means quiet passages missed, loud passages distorted
   - Inconsistent input quality

6. **No Acoustic Optimisation**
   - Auditorium acoustics not accounted for
   - No compensation for room characteristics
   - Generic processing doesn't adapt to environment

---

## Recommended Solutions

### Priority 0: Emergency Fixes (Immediate - Address Hardware Overload)

#### 0.1 Increase Buffer Size (CRITICAL)
**Purpose:** Reduce audio system overload  
**Current:** 1024 samples  
**Recommended:** 4096 samples (or larger)  
**Implementation:** Change `bufferSize: 1024` to `bufferSize: 4096`  
**Impact:** Reduces CPU load, prevents `HALC_ProxyIOContext` overload errors  
**Code Change:**
```swift
// AudioCaptureService.swift:98
inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) // Changed from 1024
```

#### 0.2 Optimise Audio Format Early
**Purpose:** Reduce processing overhead by converting to optimal format immediately  
**Implementation:** Convert to 16kHz mono immediately after capture  
**Impact:** Reduces data processing by ~75%, prevents format errors  
**Rationale:** Most audio devices output 48kHz stereo, but speech recognition only needs 16kHz mono

#### 0.3 Add Audio Processing Queue
**Purpose:** Prevent blocking audio thread  
**Implementation:** Process audio on dedicated background queue  
**Impact:** Prevents `IOWorkLoop` overload, maintains real-time audio capture

---

### Priority 1: Critical Fixes (Immediate Impact)

#### 1.1 Add High-Pass Filter
**Purpose:** Remove low-frequency rumble and noise  
**Implementation:** Use `AVAudioUnitEQ` with high-pass filter at 80-100Hz  
**Impact:** Improves signal-to-noise ratio, reduces processing overhead

#### 1.2 Implement Noise Gate
**Purpose:** Only process audio above threshold  
**Implementation:** Gate audio below -40dB to -50dB threshold  
**Impact:** Reduces false activations, saves processing power

#### 1.3 Add Automatic Gain Control (AGC)
**Purpose:** Normalise audio levels for consistent recognition  
**Implementation:** Use `AVAudioUnitEQ` with dynamic range compression  
**Impact:** Consistent recognition accuracy across volume variations

#### 1.4 Improve Pattern Matching Robustness
**Purpose:** Prevent false detections from poor transcription  
**Implementation:** 
- Add stricter validation before pattern matching
- Require minimum confidence scores
- Reject single-word "book names" that are common words
**Impact:** Prevents false detections like "drop" → "Romans"

---

### Priority 2: High-Impact Improvements

#### 2.1 Optimise Buffer Size
**Purpose:** Better handling of echo/reverb delays  
**Implementation:** Increase to 2048 or 4096 samples  
**Impact:** More stable audio processing, better for echo cancellation

#### 2.2 Convert to Optimal Format
**Purpose:** Optimise for speech recognition  
**Implementation:** Convert to 16kHz mono 16-bit PCM  
**Impact:** Better recognition accuracy, reduced processing overhead

#### 2.3 Add Noise Reduction
**Purpose:** Reduce background noise interference  
**Implementation:** Use `AVAudioUnitEQ` with noise reduction or spectral subtraction  
**Impact:** Improved speech clarity, better recognition accuracy

---

### Priority 3: Advanced Features (Future)

#### 3.1 Adaptive Echo Cancellation
**Purpose:** Remove echo from speaker audio  
**Implementation:** Requires reference signal (what was played)  
**Complexity:** High - may require system audio capture  
**Impact:** Significant improvement in auditorium environments

#### 3.2 Multi-Band Compression
**Purpose:** Better dynamic range control  
**Implementation:** Separate compression for different frequency bands  
**Impact:** More natural sound, better recognition

#### 3.3 Voice Activity Detection (VAD)
**Purpose:** Only process when speech is detected  
**Implementation:** Detect speech vs. silence/noise  
**Impact:** Reduces false processing, improves accuracy

---

## Implementation Plan

### Phase 0: Emergency Fixes (Immediate - 2-4 hours)
**Goal:** Stop hardware overload and reduce false detections

1. **Increase buffer size to 4096** (5 minutes)
   - Single line change in `AudioCaptureService.swift`
   - Immediate reduction in `HALC_ProxyIOContext` overload errors

2. **Add pattern matching safeguards** (1-2 hours)
   - Reject common words as book names ("for", "of", "on", "and", etc.)
   - Add minimum confidence threshold
   - Improve validation before pattern matching

3. **Add audio format conversion** (1-2 hours)
   - Convert to 16kHz mono early in pipeline
   - Reduces processing overhead by ~75%

### Phase 1: Quick Wins (1-2 days)
1. Add high-pass filter (80-100Hz)
2. Implement noise gate (-40dB threshold)
3. Add basic AGC (simple compression)

### Phase 2: Core Improvements (3-5 days)
1. Optimise buffer size further if needed
2. Add noise reduction filter
3. Implement audio processing queue

### Phase 3: Advanced Features (1-2 weeks)
1. Adaptive echo cancellation (if feasible)
2. Multi-band compression
3. Voice activity detection

---

## Code Changes Required

### New Audio Processing Pipeline

```swift
Audio Input (48kHz stereo typical)
    ↓
[Format Conversion] ← Convert to 16kHz mono EARLY (Priority 0)
    ↓
[High-Pass Filter] ← Remove rumble (80-100Hz)
    ↓
[Noise Gate] ← Only process above threshold (-40dB)
    ↓
[AGC/Compression] ← Normalise levels
    ↓
[Noise Reduction] ← Reduce background noise
    ↓
Speech Recognition (16kHz mono optimal)
```

### Files to Modify

1. **AudioCaptureService.swift** (Priority 0)
   - Increase buffer size: `bufferSize: 4096`
   - Add format conversion to 16kHz mono
   - Add audio processing queue

2. **ScriptureDetectorService.swift** (Priority 0)
   - Add common word exclusion list
   - Add minimum confidence threshold
   - Improve validation before pattern matching

3. **AudioCaptureService.swift** (Priority 1)
   - Add audio processing pipeline
   - Implement filters using `AVAudioUnitEQ`
   - Add high-pass filter, noise gate, AGC

4. **New File: AudioProcessor.swift** (Priority 1)
   - Centralised audio processing logic
   - Reusable filter chain
   - Configuration management

---

## Testing Recommendations

### Test Scenarios

1. **Baseline Test**
   - Direct microphone input (current best case)
   - Measure accuracy baseline

2. **Echo Test**
   - Speaker playback with microphone capture
   - Measure echo impact

3. **Noise Test**
   - Add background noise (HVAC, movement)
   - Measure noise tolerance

4. **Distance Test**
   - Vary distance from speakers
   - Measure level variation handling

5. **Reverb Test**
   - Test in different room sizes
   - Measure reverb tolerance

### Success Metrics

- **Recognition Accuracy:** >85% in auditorium environment
- **False Detection Rate:** <5%
- **Latency:** <500ms processing overhead
- **CPU Usage:** <20% additional overhead

---

## Alternative Approaches

### Option A: Hardware Solution (Recommended for Production)
- Use direct line input from mixing desk
- Bypasses all acoustic issues
- Cleanest audio source
- Requires hardware setup

### Option B: Software Solution (This Analysis)
- Add audio preprocessing
- Works with existing hardware
- More complex implementation
- May not match hardware quality

### Option C: Hybrid Approach
- Prefer direct input when available
- Fall back to processed microphone when needed
- Best of both worlds

---

## Conclusion

The poor performance in the auditorium stress test is primarily due to:

### Critical Issues (From Logs):

1. **Audio hardware overload** ⚠️ CRITICAL
   - `HALC_ProxyIOContext` overload causing system failures
   - Buffer size too small (1024) for processing demands
   - **Fix:** Increase to 4096 samples immediately

2. **Severely degraded transcription** ⚠️ CRITICAL
   - Common words ("for", "of", "on", "and") misidentified as book names
   - Complete misidentification ("drop" → "Romans")
   - False detections (Romans 20:1 when Romans only has 16 chapters)
   - **Fix:** Add pattern matching safeguards, improve validation

3. **No audio preprocessing** (critical)
   - Raw audio with echo/reverb fed directly to speech recognition
   - No noise reduction or filtering
   - **Fix:** Add high-pass filter, noise gate, AGC

4. **Suboptimal audio format** (high)
   - Processing 48kHz stereo when only 16kHz mono needed
   - Wastes 75% of processing power
   - **Fix:** Convert to 16kHz mono early in pipeline

5. **No automatic gain control** (high)
   - Varying levels cause recognition failures
   - **Fix:** Add AGC/compression

### Immediate Action Required:

**Phase 0 (Emergency - Do Today):**
1. Increase buffer size to 4096 (5 minutes)
2. Add pattern matching safeguards (1-2 hours)
3. Add format conversion to 16kHz mono (1-2 hours)

**Phase 1 (This Week):**
1. Add high-pass filter
2. Implement noise gate
3. Add basic AGC

**Recommendation:** Implement Phase 0 fixes immediately (today). These will address the hardware overload and false detection issues. Then proceed with Phase 1 for audio quality improvements.
