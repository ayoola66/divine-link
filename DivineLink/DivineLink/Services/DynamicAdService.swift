import SwiftUI
import Combine

// MARK: - Dynamic Ad Model

/// Represents an ad fetched from Supabase
struct DynamicAd: Codable, Identifiable {
    let id: String
    let name: String
    let slot: String
    let imageUrl: String
    let clickUrl: String
    let altText: String?
    let priority: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, slot, priority
        case imageUrl = "image_url"
        case clickUrl = "click_url"
        case altText = "alt_text"
    }
    
    var imageURL: URL? { URL(string: imageUrl) }
    var clickURL: URL? { URL(string: clickUrl) }
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
    
    /// Ad rotation interval (5 minutes)
    private let rotationInterval: TimeInterval = 300
    
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
    private var rotationIndex: [String: Int] = [:]  // Track rotation per slot
    
    // MARK: - Initialisation
    
    private init() {
        loadCachedAds()
        checkConnectivityStatus()
        startAdRotation()
    }
    
    deinit {
        rotationTimer?.invalidate()
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
    
    /// Rotate to next ad for each slot
    private func rotateAds() {
        let slots = ["sidebar_top", "sidebar_middle", "sidebar_bottom", "bottom_banner"]
        
        for slot in slots {
            let adsForSlot = allAds.filter { $0.slot == slot }
            guard !adsForSlot.isEmpty else { continue }
            
            // Get current index and advance
            let currentIndex = rotationIndex[slot] ?? 0
            let nextIndex = (currentIndex + 1) % adsForSlot.count
            rotationIndex[slot] = nextIndex
            
            // Update current ad for this slot
            currentAds[slot] = adsForSlot[nextIndex]
        }
        
        print("🔄 Ads rotated at \(Date())")
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
        // Map AdSlot enum to database slot names
        let slotKey: String
        switch slot {
        case .sidebarTop: slotKey = "sidebar_top"
        case .sidebarMiddle: slotKey = "sidebar_middle"
        case .sidebarBottom: slotKey = "sidebar_bottom"
        case .bottomBanner: slotKey = "bottom_banner"
        }
        
        // Try dynamic ad first
        if let dynamicAd = currentAds[slotKey] {
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
        
        let deviceId = DeviceIdentifier.getDeviceID()
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
