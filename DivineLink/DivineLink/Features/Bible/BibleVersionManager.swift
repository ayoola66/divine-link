import Foundation
import Combine

/// Owns the lifecycle of DOWNLOADABLE premium Bible versions (WEBBE, YLT, DBY, DRA, BBE, and any
/// future licensed versions like NLT added via the remote catalog).
///
/// - Bundled versions (KJV/WEB/ASV/BSB/LSV) live in the read-only Bible.db and are NOT managed here.
/// - Downloadable versions are fetched on demand into Application Support/DivineLink/bibles/ as
///   standalone SQLite files, which `BibleService` ATTACHes and queries. Mirrors the on-demand
///   pattern used by `WhisperModelManager`.
/// - The catalog (what exists + download URLs) comes from a bundled fallback merged with a remote
///   `catalog.json`, so new versions can appear without an app update.
@MainActor
final class BibleVersionManager: ObservableObject {

    static let shared = BibleVersionManager()

    /// Remote catalog manifest (also the base for the hosted files).
    nonisolated static let catalogURL = URL(string: "https://divinelink.netlify.app/bibles/catalog.json")!

    // MARK: - Catalog entry

    struct CatalogVersion: Identifiable, Equatable {
        let id: String          // e.g. "WEBBE"
        let name: String
        let year: Int
        let tier: String        // "free" | "premium"
        let verseCount: Int
        let fileSize: Int64
        let sha256: String?
        let downloadURL: URL
        let requiresAttribution: Bool
        let attributionText: String?
        let sortOrder: Int
    }

    /// Per-version runtime state for the UI.
    enum DownloadState: Equatable {
        case notInstalled
        case downloading(fraction: Double)
        case installed
        case failed(String)
    }

    @Published private(set) var catalog: [CatalogVersion] = []
    @Published private(set) var state: [String: DownloadState] = [:]

    /// Fired whenever an install/delete changes what's on disk, so BibleService can re-attach.
    let installedDidChange = PassthroughSubject<Void, Never>()

    private var inFlight: Set<String> = []

    // MARK: - Bundled fallback catalog (matches _bible_rebuild/bibles/catalog.json)

    private static let fallbackCatalog: [CatalogVersion] = [
        .init(id: "WEBBE", name: "World English Bible (British Edition)", year: 2000, tier: "premium", verseCount: 31098, fileSize: 0, sha256: nil, downloadURL: url("WEBBE"), requiresAttribution: false, attributionText: "World English Bible British Edition (public domain).", sortOrder: 6),
        .init(id: "YLT", name: "Young's Literal Translation", year: 1898, tier: "premium", verseCount: 31102, fileSize: 0, sha256: nil, downloadURL: url("YLT"), requiresAttribution: false, attributionText: nil, sortOrder: 7),
        .init(id: "DBY", name: "Darby Translation", year: 1890, tier: "premium", verseCount: 31099, fileSize: 0, sha256: nil, downloadURL: url("DBY"), requiresAttribution: false, attributionText: nil, sortOrder: 8),
        .init(id: "DRA", name: "Douay-Rheims 1899", year: 1899, tier: "premium", verseCount: 31438, fileSize: 0, sha256: nil, downloadURL: url("DRA"), requiresAttribution: false, attributionText: nil, sortOrder: 9),
        .init(id: "BBE", name: "Bible in Basic English", year: 1949, tier: "premium", verseCount: 31102, fileSize: 0, sha256: nil, downloadURL: url("BBE"), requiresAttribution: false, attributionText: "Bible in Basic English (public domain).", sortOrder: 10),
    ]
    private static func url(_ id: String) -> URL {
        URL(string: "https://divinelink.netlify.app/bibles/\(id).sqlite")!
    }

    /// Versions shipped INSIDE the app (read-only Bible.db) — shown as "Included" in Settings.
    /// 3 free + 2 premium (premium ones are gated, not downloaded).
    struct BundledVersion: Identifiable { let id: String; let name: String; let isPremium: Bool }
    static let bundledVersions: [BundledVersion] = [
        .init(id: "KJV", name: "King James Version", isPremium: false),
        .init(id: "WEB", name: "World English Bible", isPremium: false),
        .init(id: "ASV", name: "American Standard Version", isPremium: false),
        .init(id: "BSB", name: "Berean Standard Bible", isPremium: true),
        .init(id: "LSV", name: "Literal Standard Version", isPremium: true),
    ]

    /// Attribution/credit lines legally required for bundled versions that ask for them (BSB, LSV).
    /// Downloadable versions carry their own `attributionText` in the catalog. Shown on the
    /// Bible Versions screen so credits are always visible (required before public release).
    static let bundledAttributions: [String] = [
        "The Holy Bible, Berean Standard Bible, BSB. Produced in cooperation with Bible Hub, Discovery Bible, OpenBible.com, and the Berean Bible Translation Committee. Public Domain.",
        "The Holy Bible, Literal Standard Version, LSV. Copyright © 2020 Covenant Press. Released for free, non-commercial use.",
    ]

    // MARK: - Filesystem

    /// Directory holding downloaded version files (survives app updates).
    nonisolated static var bimblesDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("DivineLink/bibles", isDirectory: true)
    }

    nonisolated static func fileURL(for id: String) -> URL {
        bimblesDir.appendingPathComponent("\(id).sqlite")
    }

    nonisolated static func isInstalled(_ id: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: id).path)
    }

    /// (id, fileURL) for every downloaded version present on disk — BibleService ATTACHes these.
    nonisolated static func installedFiles() -> [(id: String, url: URL)] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: bimblesDir, includingPropertiesForKeys: nil) else { return [] }
        return entries
            .filter { $0.pathExtension == "sqlite" }
            .map { (id: $0.deletingPathExtension().lastPathComponent, url: $0) }
    }

    // MARK: - Init

    private init() {
        try? FileManager.default.createDirectory(at: Self.bimblesDir, withIntermediateDirectories: true)
        catalog = Self.fallbackCatalog
        refreshState()
    }

    /// Recompute each catalog version's state from what's on disk.
    func refreshState() {
        var s = state
        for v in catalog {
            if inFlight.contains(v.id) { continue } // don't clobber an active download
            s[v.id] = Self.isInstalled(v.id) ? .installed : .notInstalled
        }
        state = s
    }

    func state(for id: String) -> DownloadState { state[id] ?? .notInstalled }

    // MARK: - Remote catalog refresh (enables future versions with no app update)

    func refreshCatalog() async {
        do {
            let (data, resp) = try await URLSession.shared.data(from: Self.catalogURL)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return }
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let arr = root["versions"] as? [[String: Any]] else { return }
            var parsed: [CatalogVersion] = []
            for o in arr {
                guard let id = o["id"] as? String,
                      let urlStr = o["download_url"] as? String,
                      let url = URL(string: urlStr) else { continue }
                parsed.append(CatalogVersion(
                    id: id,
                    name: o["name"] as? String ?? id,
                    year: o["year"] as? Int ?? 0,
                    tier: o["tier"] as? String ?? "premium",
                    verseCount: o["verse_count"] as? Int ?? 0,
                    fileSize: (o["file_size"] as? NSNumber)?.int64Value ?? 0,
                    sha256: o["sha256"] as? String,
                    downloadURL: url,
                    requiresAttribution: o["requires_attribution"] as? Bool ?? false,
                    attributionText: o["attribution_text"] as? String,
                    sortOrder: o["sort_order"] as? Int ?? 99
                ))
            }
            if !parsed.isEmpty {
                catalog = parsed.sorted { $0.sortOrder < $1.sortOrder }
                refreshState()
            }
        } catch {
            // Offline or catalog unreachable — keep the bundled fallback. Not fatal.
            print("ℹ️ [BibleVersions] catalog refresh skipped: \(error.localizedDescription)")
        }
    }

    // MARK: - Download / delete

    /// Download one version file into Application Support, streaming byte progress.
    func download(_ id: String) async {
        guard let v = catalog.first(where: { $0.id == id }) else { return }
        if Self.isInstalled(id) { state[id] = .installed; return }
        guard !inFlight.contains(id) else { return }
        inFlight.insert(id)
        defer { inFlight.remove(id) }
        state[id] = .downloading(fraction: 0)

        let dest = Self.fileURL(for: id)
        let tmp = dest.appendingPathExtension("partial")

        do {
            let (bytes, response) = try await URLSession.shared.bytes(from: v.downloadURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw NSError(domain: "BibleVersions", code: 1, userInfo: [NSLocalizedDescriptionKey: "Download failed (bad status)"])
            }
            let total = response.expectedContentLength > 0 ? response.expectedContentLength : v.fileSize
            var data = Data()
            data.reserveCapacity(total > 0 ? Int(total) : 5_000_000)
            var lastReport = 0.0
            for try await byte in bytes {
                data.append(byte)
                if total > 0 {
                    let f = Double(data.count) / Double(total)
                    if f - lastReport >= 0.01 { lastReport = f; state[id] = .downloading(fraction: min(f, 0.99)) }
                }
            }
            // Write atomically: temp then move.
            try? FileManager.default.removeItem(at: tmp)
            try data.write(to: tmp)
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tmp, to: dest)

            state[id] = .installed
            installedDidChange.send()
        } catch {
            try? FileManager.default.removeItem(at: tmp)
            state[id] = .failed(error.localizedDescription)
        }
    }

    /// Remove a downloaded version (users can free space).
    func delete(_ id: String) {
        try? FileManager.default.removeItem(at: Self.fileURL(for: id))
        state[id] = .notInstalled
        installedDidChange.send()
    }
}
