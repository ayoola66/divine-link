import Foundation
import AVFoundation
import Combine
import WhisperKit

/// On-device Whisper transcription engine (WhisperKit).
///
/// It consumes the app's EXISTING audio buffers (so BlackHole, the mic selector, and
/// multi-channel interfaces keep working), resamples them to 16 kHz mono, and runs
/// Whisper on a rolling window every `transcribeInterval`. Output is emitted as
/// cumulative window text (`isFinal: false`); on a speech pause or when the window is
/// capped it emits `isFinal: true`, so the existing TranscriptBuffer turns it into
/// clean, pause-delimited lines — with punctuation, unlike Apple's on-device engine.
///
/// Fully offline once the model is present. Runs on the Neural Engine / GPU via CoreML.
final class WhisperTranscriber {

    // MARK: - Tunables (safe to adjust after live testing)

    private let modelVariant: String
    private let targetSampleRate: Double = 16_000
    /// How often Whisper runs over the current window.
    private let transcribeInterval: TimeInterval = 1.5
    /// Max audio kept in a window (Whisper's context is 30s; stay under it for CPU too).
    private let maxWindowSeconds: Double = 28
    /// Audio kept as overlap after a window reset, so words aren't clipped at the seam.
    private let overlapSeconds: Double = 1.5
    /// Minimum audio before the first transcription of a window.
    private let minSecondsToTranscribe: Double = 0.8

    // MARK: - State

    private var whisperKit: WhisperKit?
    private var samples: [Float] = []
    private let lock = NSLock()
    private var audioSub: AnyCancellable?
    private var timer: Timer?
    private var transcribing = false
    private var lastSampleCount = 0
    private var lastEmittedText = ""
    private var hasPendingText = false
    private(set) var isReady = false

    // MARK: - Callbacks (always delivered on the main actor)

    /// (text, isFinal). `isFinal` marks a pause/window boundary → commit a line.
    var onText: ((_ text: String, _ isFinal: Bool) -> Void)?
    var onStateChange: ((_ running: Bool) -> Void)?
    var onError: ((_ message: String) -> Void)?

    init(model: String = "small.en") {
        self.modelVariant = model
    }

    /// Locates a WhisperKit model folder bundled inside the app (for pure-offline use).
    /// Returns the path to a folder that contains `AudioEncoder.mlmodelc`, searching the
    /// app Resources root and one level of subfolders. Returns nil if none is bundled.
    /// Breadth-first search of the app bundle for a folder that directly contains `marker`.
    private func findBundledFolder(containing marker: String, maxDepth: Int = 4) -> URL? {
        let fm = FileManager.default
        guard let resURL = Bundle.main.resourceURL else { return nil }
        var current = [resURL]
        var depth = 0
        while depth <= maxDepth, !current.isEmpty {
            var next: [URL] = []
            for dir in current {
                if fm.fileExists(atPath: dir.appendingPathComponent(marker).path) { return dir }
                if let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                    for e in entries {
                        var isDir: ObjCBool = false
                        if fm.fileExists(atPath: e.path, isDirectory: &isDir), isDir.boolValue {
                            next.append(e)
                        }
                    }
                }
            }
            current = next
            depth += 1
        }
        return nil
    }

    /// The bundled CoreML model folder (contains `AudioEncoder.mlmodelc`), or nil.
    private func bundledModelFolder() -> String? {
        findBundledFolder(containing: "AudioEncoder.mlmodelc")?.path
    }

    /// The bundled tokenizer folder (contains `tokenizer.json`), or nil. WhisperKit stores
    /// the tokenizer in a SEPARATE repo from the CoreML model, so it must be bundled too.
    private func bundledTokenizerFolder() -> URL? {
        findBundledFolder(containing: "tokenizer.json")
    }

    // MARK: - Lifecycle

    func start(audioPublisher: PassthroughSubject<AVAudioPCMBuffer, Never>) {
        Task { [weak self] in
            guard let self else { return }
            do {
                // Resolve the model folder WITHOUT any network access. Order:
                //   1. The on-demand model downloaded to Application Support (the normal path).
                //   2. A model bundled in the app (legacy builds that still ship it).
                // If neither is present we error out so TranscriptionService falls back to Apple
                // STT — this class NEVER inline-downloads. The one-time download is owned by
                // WhisperModelManager (first-launch, Apple-Silicon only, with visible progress).
                let tokenizer = self.bundledTokenizerFolder()
                let modelPath: String
                if let downloaded = WhisperModelManager.installedModelFolder()?.path {
                    modelPath = downloaded
                    print("✅ [Whisper] Offline downloaded model: \(downloaded)")
                } else if let bundled = self.bundledModelFolder() {
                    modelPath = bundled
                    print("✅ [Whisper] Offline bundled model: \(bundled)")
                } else {
                    print("⚠️ [Whisper] No model installed — falling back to Apple STT (no inline download)")
                    await MainActor.run { self.onError?("Whisper model not installed") }
                    return
                }
                print("✅ [Whisper] Offline tokenizer: \(tokenizer?.path ?? "NOT FOUND — would need network")")
                // download:false → never touch the network; load model + tokenizer from disk.
                let config = WhisperKitConfig(
                    modelFolder: modelPath,
                    tokenizerFolder: tokenizer,
                    load: true,
                    download: false
                )
                let kit = try await WhisperKit(config)
                await MainActor.run {
                    self.whisperKit = kit
                    self.isReady = true
                    self.beginConsuming(audioPublisher: audioPublisher)
                    self.onStateChange?(true)
                    print("✅ [Whisper] Model ready: \(self.modelVariant)")
                }
            } catch {
                await MainActor.run {
                    self.onError?("WhisperKit load failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func stop() {
        audioSub?.cancel(); audioSub = nil
        timer?.invalidate(); timer = nil
        lock.lock(); samples.removeAll(); lock.unlock()
        transcribing = false
        lastSampleCount = 0
        lastEmittedText = ""
        hasPendingText = false
        onStateChange?(false)
    }

    // MARK: - Audio intake

    private func beginConsuming(audioPublisher: PassthroughSubject<AVAudioPCMBuffer, Never>) {
        audioSub = audioPublisher.sink { [weak self] buffer in
            self?.append(buffer)
        }
        timer = Timer.scheduledTimer(withTimeInterval: transcribeInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    /// Called on the audio processing queue — resample to 16 kHz mono and append.
    private func append(_ buffer: AVAudioPCMBuffer) {
        guard let resampled = AudioProcessor.resampleAudio(
            fromBuffer: buffer,
            toSampleRate: targetSampleRate,
            channelCount: 1
        ) else { return }
        let arr = AudioProcessor.convertBufferToArray(buffer: resampled)
        guard !arr.isEmpty else { return }
        lock.lock(); samples.append(contentsOf: arr); lock.unlock()
    }

    // MARK: - Transcription loop

    private func tick() {
        guard isReady, !transcribing, let kit = whisperKit else { return }

        lock.lock()
        let count = samples.count
        let snapshot = samples
        lock.unlock()

        // Speech pause: no new audio since last tick → finalise the current line and
        // reset the window so the next utterance starts fresh (pause = new line).
        if count == lastSampleCount {
            if hasPendingText {
                let finalText = lastEmittedText
                onText?(finalText, true)
                lock.lock(); samples.removeAll(); lock.unlock()
                hasPendingText = false
                lastEmittedText = ""
            }
            lastSampleCount = count
            return
        }
        lastSampleCount = count

        guard count >= Int(targetSampleRate * minSecondsToTranscribe) else { return }

        let capped = count > Int(maxWindowSeconds * targetSampleRate)
        transcribing = true

        Task { [weak self] in
            guard let self else { return }
            do {
                let options = DecodingOptions(
                    task: .transcribe,
                    language: "en",
                    skipSpecialTokens: true,
                    withoutTimestamps: true
                )
                let results = try await kit.transcribe(audioArray: snapshot, decodeOptions: options)
                let text = results.map(\.text).joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                await MainActor.run {
                    if !text.isEmpty {
                        self.onText?(text, false)
                        self.lastEmittedText = text
                        self.hasPendingText = true
                    }
                    if capped {
                        // Window full: commit this line and keep only a short overlap.
                        self.onText?(text, true)
                        self.lock.lock()
                        let keep = Int(self.overlapSeconds * self.targetSampleRate)
                        if self.samples.count > keep {
                            self.samples.removeFirst(self.samples.count - keep)
                        }
                        self.lock.unlock()
                        self.lastSampleCount = 0
                        self.hasPendingText = false
                        self.lastEmittedText = ""
                    }
                    self.transcribing = false
                }
            } catch {
                await MainActor.run {
                    self.transcribing = false
                    self.onError?("transcribe failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
