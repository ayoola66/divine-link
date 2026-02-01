import SwiftUI
import Combine

// MARK: - Ad Format

/// Types of ad formats supported
enum AdFormat: String, Codable, CaseIterable {
    case square = "square"
    case portrait = "portrait"
    case banner = "banner"
    
    var aspectRatio: CGFloat {
        switch self {
        case .square: return 1.0           // 1:1
        case .portrait: return 9.0 / 16.0  // 9:16 (tall)
        case .banner: return 728.0 / 90.0  // Wide banner
        }
    }
}

// MARK: - Dynamic Ad Model

/// Represents an ad fetched from Supabase
struct DynamicAd: Codable, Identifiable {
    let id: String
    let name: String
    let slot: String
    let format: String?
    let imageUrl: String
    let videoUrl: String?              // Optional: Video/GIF URL for animated ads
    let mediaType: String?              // 'image', 'video', or 'gif'
    let clickUrl: String
    let altText: String?
    let priority: Int
    let isEnforced: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, slot, format, priority
        case imageUrl = "image_url"
        case videoUrl = "video_url"
        case mediaType = "media_type"
        case clickUrl = "click_url"
        case altText = "alt_text"
        case isEnforced = "is_enforced"
    }
    
    var imageURL: URL? { URL(string: imageUrl) }
    var videoURL: URL? { 
        guard let videoUrl = videoUrl else { return nil }
        return URL(string: videoUrl)
    }
    var clickURL: URL? { URL(string: clickUrl) }
    
    var adFormat: AdFormat {
        AdFormat(rawValue: format ?? slot) ?? .square
    }
    
    /// Determine if this ad has video/GIF content
    var hasVideo: Bool {
        videoURL != nil && (mediaType == "video" || mediaType == "gif")
    }
    
    /// Get the primary media URL (video takes priority over image)
    var primaryMediaURL: URL? {
        hasVideo ? videoURL : imageURL
    }
}

// MARK: - Cached Ad Data

/// Cached ad data stored locally
struct CachedAdData: Codable {
    let ads: [DynamicAd]  // All ads
    let cachedAt: Date
    let serverTime: Date?
    
    var isExpired: Bool {
        // Cache expires after 24 hours
        Date().timeIntervalSince(cachedAt) > 86400
    }
}

// MARK: - Connectivity Status

enum ConnectivityStatus {
    case online
    case offlineRecent      // Offline but within grace period
    case offlineExpired     // Offline too long - app should lock
    
    var canUseApp: Bool {
        switch self {
        case .online, .offlineRecent: return true
        case .offlineExpired: return false
        }
    }
}

// MARK: - Dynamic Ad Service

/// Service for fetching and managing dynamic ads from Supabase
class DynamicAdService: ObservableObject {
    static let shared = DynamicAdService()
    
    // MARK: - Configuration
    
    /// Maximum days offline before app locks
    private let maxOfflineDays: Int = 7
    
    /// Ad rotation interval (5 minutes) - rotates between cached ads
    private let rotationInterval: TimeInterval = 300
    
    /// Server refresh interval (15 minutes) - fetches new ads from server
    private let serverRefreshInterval: TimeInterval = 900
    
    /// Cache file location
    private var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("dynamic_ads.json")
    }
    
    /// Last online timestamp storage key
    private let lastOnlineKey = "lastOnlineTimestamp"
    
    // MARK: - Published Properties
    
    /// Currently displayed ads (one per slot)
    @Published var currentAds: [String: DynamicAd] = [:]
    
    /// All available ads from database (multiple per slot possible)
    @Published var allAds: [DynamicAd] = []
    
    @Published var isLoading = false
    @Published var connectivityStatus: ConnectivityStatus = .online
    @Published var showConnectivityWarning = false
    @Published var daysUntilLockout: Int = 7
    
    // MARK: - Private Properties
    
    private var rotationTimer: Timer?
    private var serverRefreshTimer: Timer?
    private var rotationIndex: [String: Int] = [:]  // Track rotation per slot
    
    // MARK: - Initialisation
    
    private init() {
        loadCachedAds()
        checkConnectivityStatus()
        startAdRotation()
        startServerRefresh()
        
        // Initial fetch from server
        Task {
            await fetchAds()
        }
    }
    
    deinit {
        rotationTimer?.invalidate()
        serverRefreshTimer?.invalidate()
    }
    
    // MARK: - Server Refresh
    
    /// Start periodic server refresh to get new ads
    private func startServerRefresh() {
        serverRefreshTimer?.invalidate()
        serverRefreshTimer = Timer.scheduledTimer(withTimeInterval: serverRefreshInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.fetchAds()
            }
        }
        print("🔄 Server refresh scheduled every \(Int(serverRefreshInterval/60)) minutes")
    }
    
    /// Force refresh ads from server (call this after adding new ad in admin)
    func forceRefresh() {
        Task {
            await fetchAds()
        }
    }
    
    // MARK: - Ad Rotation
    
    /// Start the ad rotation timer
    private func startAdRotation() {
        rotationTimer?.invalidate()
        rotationTimer = Timer.scheduledTimer(withTimeInterval: rotationInterval, repeats: true) { [weak self] _ in
            self?.rotateAds()
        }
        // Initial rotation
        rotateAds()
    }
    
    /// Rotate to next ad for each format
    private func rotateAds() {
        let formats = ["square", "portrait", "banner"]
        
        for format in formats {
            // Get ads for this format, prioritising enforced ads
            let adsForFormat = allAds.filter { $0.format == format || $0.slot.contains(format) }
            guard !adsForFormat.isEmpty else { continue }
            
            // Check for enforced ads first - they don't rotate
            if let enforcedAd = adsForFormat.first(where: { $0.isEnforced }) {
                currentAds[format] = enforcedAd
                continue
            }
            
            // Get current index and advance for non-enforced rotation
            let currentIndex = rotationIndex[format] ?? 0
            let nextIndex = (currentIndex + 1) % adsForFormat.count
            rotationIndex[format] = nextIndex
            
            // Update current ad for this format
            currentAds[format] = adsForFormat[nextIndex]
        }
        
        print("🔄 Ads rotated at \(Date()) - \(currentAds.count) active")
    }
    
    // MARK: - Public Methods
    
    /// Fetch all active ads from Supabase
    func fetchAds() async {
        await MainActor.run { isLoading = true }
        
        do {
            // Fetch ALL active ads
            let fetchedAds = try await fetchAllActiveAds()
            
            // Update state
            await MainActor.run {
                self.allAds = fetchedAds
                self.isLoading = false
                self.connectivityStatus = .online
                self.showConnectivityWarning = false
                
                // Trigger initial rotation to display ads
                self.rotateAds()
            }
            
            // Cache the ads
            cacheAllAds(fetchedAds)
            
            // Record successful online check
            recordOnlineTimestamp()
            
            // Send heartbeat
            await sendHeartbeat()
            
            print("✅ Fetched \(fetchedAds.count) ads from server")
            
        } catch {
            print("❌ Failed to fetch ads: \(error)")
            await MainActor.run { isLoading = false }
            
            // Use cached ads as fallback
            loadCachedAds()
            checkConnectivityStatus()
        }
    }
    
    /// Get ad for a specific slot (with fallback to default)
    func ad(for slot: AdSlot) -> AdDisplayContent {
        // Map AdSlot enum to format names
        let formatKey: String
        switch slot {
        case .sidebarTop, .sidebarMiddle, .sidebarBottom:
            formatKey = "square"
        case .bottomBanner:
            formatKey = "banner"
        }
        
        // Try dynamic ad first
        if let dynamicAd = currentAds[formatKey] {
            return AdDisplayContent(
                id: dynamicAd.id,
                imageURL: dynamicAd.imageURL,
                clickURL: dynamicAd.clickURL,
                altText: dynamicAd.altText ?? dynamicAd.name,
                isDefault: false
            )
        }
        
        // Fall back to default upgrade ad
        return AdDisplayContent.defaultUpgradeAd(for: slot)
    }
    
    /// Get ad by format directly
    func ad(for format: AdFormat) -> AdDisplayContent {
        if let dynamicAd = currentAds[format.rawValue] {
            return AdDisplayContent(
                id: dynamicAd.id,
                imageURL: dynamicAd.imageURL,
                clickURL: dynamicAd.clickURL,
                altText: dynamicAd.altText ?? dynamicAd.name,
                isDefault: false
            )
        }
        return AdDisplayContent.defaultUpgradeAd(for: .sidebarTop)
    }
    
    /// Get all ads for a specific format
    func ads(for format: AdFormat) -> [DynamicAd] {
        allAds.filter { $0.format == format.rawValue || $0.slot.contains(format.rawValue) }
    }
    
    /// Check if there's a portrait ad available
    var hasPortraitAd: Bool {
        !ads(for: .portrait).isEmpty
    }
    
    /// Get the current portrait ad if available
    var portraitAd: DynamicAd? {
        currentAds["portrait"]
    }
    
    /// Get current square ads
    var squareAds: [DynamicAd] {
        ads(for: .square)
    }
    
    /// Get current banner ad
    var bannerAd: DynamicAd? {
        currentAds["banner"]
    }
    
    /// Record an ad impression
    func recordImpression(adId: String) {
        Task {
            await recordAdEvent(adId: adId, type: "impression")
        }
    }
    
    /// Record an ad click
    func recordClick(adId: String) {
        Task {
            await recordAdEvent(adId: adId, type: "click")
        }
    }
    
    /// Check if app should be locked due to offline period
    func checkConnectivityStatus() {
        guard let lastOnline = UserDefaults.standard.object(forKey: lastOnlineKey) as? Date else {
            // First run - assume online
            connectivityStatus = .online
            recordOnlineTimestamp()
            return
        }
        
        let daysSinceOnline = Calendar.current.dateComponents([.day], from: lastOnline, to: Date()).day ?? 0
        daysUntilLockout = max(0, maxOfflineDays - daysSinceOnline)
        
        if daysSinceOnline >= maxOfflineDays {
            connectivityStatus = .offlineExpired
            showConnectivityWarning = true
        } else if daysSinceOnline >= 3 {
            // Warn after 3 days offline
            connectivityStatus = .offlineRecent
            showConnectivityWarning = true
        } else {
            connectivityStatus = .offlineRecent
            showConnectivityWarning = false
        }
    }
    
    // MARK: - Private Methods
    
    /// Fetch all active ads from Supabase
    private func fetchAllActiveAds() async throws -> [DynamicAd] {
        let urlString = "\(SupabaseConfig.supabaseURL)/rest/v1/rpc/get_all_active_ads"
        guard let url = URL(string: urlString) else { return [] }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = "{}".data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("⚠️ Failed to fetch ads: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            return []
        }
        
        let ads = try JSONDecoder().decode([DynamicAd].self, from: data)
        return ads
    }
    
    /// Cache all ads locally
    private func cacheAllAds(_ ads: [DynamicAd]) {
        let cachedData = CachedAdData(
            ads: ads,
            cachedAt: Date(),
            serverTime: Date()
        )
        
        do {
            let data = try JSONEncoder().encode(cachedData)
            try data.write(to: cacheURL)
            print("✅ \(ads.count) ads cached successfully")
        } catch {
            print("❌ Failed to cache ads: \(error)")
        }
    }
    
    /// Load cached ads
    private func loadCachedAds() {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            print("ℹ️ No cached ads found")
            return
        }
        
        do {
            let data = try Data(contentsOf: cacheURL)
            let cachedData = try JSONDecoder().decode(CachedAdData.self, from: data)
            
            if !cachedData.isExpired {
                allAds = cachedData.ads
                rotateAds()  // Display the cached ads
                print("✅ Loaded \(cachedData.ads.count) cached ads")
            } else {
                print("ℹ️ Cached ads expired")
            }
        } catch {
            print("❌ Failed to load cached ads: \(error)")
        }
    }
    
    /// Record when we were last online
    private func recordOnlineTimestamp() {
        UserDefaults.standard.set(Date(), forKey: lastOnlineKey)
    }
    
    /// Send heartbeat to server
    private func sendHeartbeat() async {
        let urlString = "\(SupabaseConfig.supabaseURL)/rest/v1/app_heartbeats"
        guard let url = URL(string: urlString) else { return }
        
        let deviceId = DeviceManager.shared.deviceId
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let body: [String: Any] = [
            "device_id": deviceId,
            "last_seen_at": ISO8601DateFormatter().string(from: Date()),
            "app_version": appVersion
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 300 {
                print("✅ Heartbeat sent")
            }
        } catch {
            print("⚠️ Heartbeat failed: \(error)")
        }
    }
    
    /// Record ad impression or click
    private func recordAdEvent(adId: String, type: String) async {
        let function = type == "click" ? "record_ad_click" : "record_ad_impression"
        let urlString = "\(SupabaseConfig.supabaseURL)/rest/v1/rpc/\(function)"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body = ["p_ad_id": adId]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let _ = try await URLSession.shared.data(for: request)
        } catch {
            print("⚠️ Failed to record \(type): \(error)")
        }
    }
}

// MARK: - Ad Display Content

/// Content to display for an ad slot
struct AdDisplayContent {
    let id: String
    let imageURL: URL?
    let clickURL: URL?
    let altText: String
    let isDefault: Bool
    
    /// Default upgrade prompt ad
    static func defaultUpgradeAd(for slot: AdSlot) -> AdDisplayContent {
        AdDisplayContent(
            id: "default-\(slot.rawValue)",
            imageURL: nil,  // Will use bundled asset
            clickURL: nil,  // Will trigger upgrade flow
            altText: "Upgrade to Premium",
            isDefault: true
        )
    }
}

// MARK: - Connectivity Lock View

/// View shown when app is locked due to offline period
struct ConnectivityLockView: View {
    @ObservedObject private var adService = DynamicAdService.shared
    @State private var isChecking = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            Text("Connection Required")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Divine Link requires an internet connection at least once every 7 days to verify your licence and receive updates.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                isChecking = true
                Task {
                    await adService.fetchAds()
                    await MainActor.run {
                        isChecking = false
                    }
                }
            } label: {
                HStack {
                    if isChecking {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    Text(isChecking ? "Connecting..." : "Retry Connection")
                }
                .frame(width: 200)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isChecking)
            
            Text("Please connect to the internet and try again.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(width: 400, height: 350)
    }
}

// MARK: - Connectivity Warning Banner

/// Warning banner shown when offline for a few days
struct ConnectivityWarningBanner: View {
    @ObservedObject private var adService = DynamicAdService.shared
    
    var body: some View {
        if adService.showConnectivityWarning && adService.connectivityStatus != .offlineExpired {
            HStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .foregroundStyle(.orange)
                
                Text("You've been offline for a while. Connect to the internet within \(adService.daysUntilLockout) days to continue using Divine Link.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button("Dismiss") {
                    adService.showConnectivityWarning = false
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
        }
    }
}
