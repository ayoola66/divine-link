import Foundation
import Combine
import WhisperKit

/// Owns the on-demand lifecycle of the WhisperKit CoreML model.
///
/// The model (~464 MB) is NOT bundled in the app any more — only the 2.3 MB tokenizer is.
/// On Apple Silicon the model is downloaded ONCE on first launch, with visible progress,
/// into Application Support (so it survives app updates), and used fully offline afterwards.
/// On Intel this manager reports `isSupported == false` and never downloads — the app uses
/// Apple's Speech recognizer instead (WhisperKit crashes on Intel via MPSGraph).
///
/// Resolution helpers are `nonisolated static` so the transcriber and the engine-selection
/// gate can read install state cheaply without hopping onto the main actor.
@MainActor
final class WhisperModelManager: ObservableObject {

    static let shared = WhisperModelManager()

    /// WhisperKit variant name (matches the folder in `argmaxinc/whisperkit-coreml`).
    nonisolated static let modelVariant = "openai_whisper-small.en"

    /// The CoreML components that must ALL be present for the model to be usable. Checking all
    /// three (not just one) means an interrupted/partial download reads as NOT installed — so it
    /// gets re-offered and retried, instead of falsely reading "installed" then failing to load.
    nonisolated static let installMarkers = [
        "AudioEncoder.mlmodelc",
        "MelSpectrogram.mlmodelc",
        "TextDecoder.mlmodelc",
    ]

    /// UserDefaults key holding the exact model-folder path returned by `WhisperKit.download`.
    nonisolated static let storedPathKey = "whisperModelFolderPath"

    // MARK: - Download state

    enum State: Equatable {
        case notInstalled
        case downloading(fraction: Double, received: Int64, total: Int64)
        case installed
        case failed(String)
    }

    @Published private(set) var state: State

    private var isDownloading = false

    // MARK: - Hardware support

    /// True only when running NATIVELY on Apple-Silicon hardware.
    ///
    /// Two conditions, both required:
    ///  1. The hardware is arm64 (`hw.optional.arm64`).
    ///  2. This process is NOT translated by Rosetta (`sysctl.proc_translated != 1`).
    ///
    /// The universal binary normally runs the arm64 slice natively on Apple Silicon, so (2) is
    /// belt-and-suspenders — but a Rosetta-translated x86_64 process reports arm64 *hardware*
    /// yet would crash WhisperKit's Metal/float16 path exactly like real Intel. Treating a
    /// translated process as unsupported routes it to Apple Speech instead of crashing.
    nonisolated static let isSupported: Bool = {
        var isArm: Int32 = 0
        var armSize = MemoryLayout<Int32>.size
        let armOK = sysctlbyname("hw.optional.arm64", &isArm, &armSize, nil, 0) == 0 && isArm == 1

        var translated: Int32 = 0
        var tSize = MemoryLayout<Int32>.size
        // Absent sysctl (Intel / older macOS) → errno, treated as "not translated".
        let isTranslated = sysctlbyname("sysctl.proc_translated", &translated, &tSize, nil, 0) == 0 && translated == 1

        return armOK && !isTranslated
    }()

    nonisolated var isSupported: Bool { Self.isSupported }

    // MARK: - Filesystem resolution (nonisolated — pure fs, no actor state)

    /// WhisperKit downloads into `<base>/models/<repo>/<variant>`. Application Support keeps the
    /// model out of the (read-only, update-replaced) app bundle.
    nonisolated static var downloadBaseURL: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("DivineLink", isDirectory: true)
    }

    /// Deterministic fallback path (used only before the first successful download records the
    /// authoritative path in UserDefaults).
    nonisolated static var defaultModelFolderURL: URL {
        downloadBaseURL
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("argmaxinc", isDirectory: true)
            .appendingPathComponent("whisperkit-coreml", isDirectory: true)
            .appendingPathComponent(modelVariant, isDirectory: true)
    }

    /// True iff every required CoreML component exists directly inside `folder`.
    nonisolated static func isCompleteModel(at folder: URL) -> Bool {
        let fm = FileManager.default
        return installMarkers.allSatisfy {
            fm.fileExists(atPath: folder.appendingPathComponent($0).path)
        }
    }

    /// The resolved model folder if a COMPLETE model is on disk, else nil.
    /// Prefers the exact path recorded by the last successful download.
    nonisolated static func installedModelFolder() -> URL? {
        if let stored = UserDefaults.standard.string(forKey: storedPathKey) {
            let url = URL(fileURLWithPath: stored)
            if isCompleteModel(at: url) { return url }
        }
        let def = defaultModelFolderURL
        if isCompleteModel(at: def) { return def }
        return nil
    }

    /// True iff the CoreML model is present on disk.
    nonisolated static var isInstalled: Bool { installedModelFolder() != nil }

    nonisolated var isInstalled: Bool { Self.isInstalled }

    // MARK: - Init

    private init() {
        self.state = Self.isInstalled ? .installed : .notInstalled
        try? FileManager.default.createDirectory(
            at: Self.downloadBaseURL, withIntermediateDirectories: true
        )
    }

    /// Re-check disk (e.g. after returning to the download screen).
    func refresh() {
        if isDownloading { return }
        state = Self.isInstalled ? .installed : .notInstalled
    }

    // MARK: - Download

    /// Download the model on demand (Apple Silicon only). Idempotent, and resumable — the Hub
    /// snapshot skips files already present, so re-invoking after a failure continues where it
    /// left off rather than starting over.
    func download() async {
        guard Self.isSupported else {
            state = .failed("Enhanced recognition requires an Apple-Silicon Mac.")
            return
        }
        if Self.isInstalled { state = .installed; return }
        guard !isDownloading else { return }
        isDownloading = true
        defer { isDownloading = false }

        state = .downloading(fraction: 0, received: 0, total: 0)

        do {
            let folder = try await WhisperKit.download(
                variant: Self.modelVariant,
                downloadBase: Self.downloadBaseURL,
                progressCallback: { progress in
                    // Called off the main actor by the Hub downloader — hop back to publish.
                    let fraction = progress.fractionCompleted
                    let received = progress.completedUnitCount
                    let total = progress.totalUnitCount
                    Task { @MainActor [weak self] in
                        guard let self, self.isDownloading else { return }
                        self.state = .downloading(fraction: fraction, received: received, total: total)
                    }
                }
            )
            // Record the authoritative folder path returned by the downloader.
            UserDefaults.standard.set(folder.path, forKey: Self.storedPathKey)

            if Self.isInstalled {
                state = .installed
            } else {
                state = .failed("Download finished but model files are missing.")
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
