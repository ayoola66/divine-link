import Foundation
import Combine

// MARK: - Subscription Models

/// Subscription tier levels
enum SubscriptionTier: String, Codable, CaseIterable {
    case mercy = "free"       // Free tier
    case grace = "grace"      // Premium tier (£9.99/month)
    case love = "love"        // Pro tier (£19.99/month)
    
    /// Pastor profile limit for each tier
    var pastorProfileLimit: Int {
        switch self {
        case .mercy: return 0
        case .grace: return 2
        case .love: return 5
        }
    }
    
    /// Display name for the tier
    var displayName: String {
        switch self {
        case .mercy: return "Mercy (Free)"
        case .grace: return "Grace (Premium)"
        case .love: return "Love (Pro)"
        }
    }
    
    /// Device limit for each tier
    var deviceLimit: Int {
        switch self {
        case .mercy: return 1
        case .grace: return 2
        case .love: return 5
        }
    }
}

/// API subscription status (simple string for Codable)
enum APISubscriptionStatus: String, Codable {
    case free
    case trial
    case premium
    case grace      // Grace tier specifically
    case love       // Love tier specifically
    case cancelled
    case expired
    
    /// Convert to app's SubscriptionStatus enum
    var toAppStatus: SubscriptionStatus {
        switch self {
        case .free, .cancelled, .expired:
            return .free
        case .trial:
            return .trial(daysLeft: 7) // Default trial days
        case .premium, .grace, .love:
            return .premium
        }
    }
    
    /// Convert to subscription tier
    var toTier: SubscriptionTier {
        switch self {
        case .love:
            return .love
        case .grace, .premium, .trial:
            return .grace
        case .free, .cancelled, .expired:
            return .mercy
        }
    }
}

struct Subscription: Codable {
    let id: String
    let userId: String
    let status: APISubscriptionStatus
    let stripeCustomerId: String?
    let stripeSubscriptionId: String?
    let currentPeriodStart: Date?
    let currentPeriodEnd: Date?
    let cancelAtPeriodEnd: Bool
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case status
        case stripeCustomerId = "stripe_customer_id"
        case stripeSubscriptionId = "stripe_subscription_id"
        case currentPeriodStart = "current_period_start"
        case currentPeriodEnd = "current_period_end"
        case cancelAtPeriodEnd = "cancel_at_period_end"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var isPremium: Bool {
        status == .premium || status == .trial
    }
    
    var isExpired: Bool {
        guard let endDate = currentPeriodEnd else { return false }
        return endDate < Date()
    }
}

struct SubscriptionInfo: Codable {
    let status: String
    let isPremium: Bool
    let periodEnd: Date?
    let deviceCount: Int
    let maxDevices: Int
    
    enum CodingKeys: String, CodingKey {
        case status
        case isPremium = "is_premium"
        case periodEnd = "period_end"
        case deviceCount = "device_count"
        case maxDevices = "max_devices"
    }
}

// MARK: - Subscription Service

@MainActor
final class SubscriptionService: ObservableObject {
    
    static let shared = SubscriptionService()
    
    // MARK: - Published Properties
    
    @Published private(set) var subscription: Subscription?
    @Published private(set) var isPremium = false
    @Published private(set) var currentTier: SubscriptionTier = .mercy
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    /// Maximum number of pastor profiles allowed for the current subscription tier
    var pastorProfileLimit: Int {
        return currentTier.pastorProfileLimit
    }
    
    // MARK: - Private Properties
    
    private var checkTimer: Timer?
    private let userDefaults = UserDefaults.standard
    private let lastCheckKey = "lastSubscriptionCheck"
    private let cachedStatusKey = "cachedSubscriptionStatus"
    private let cachedTierKey = "cachedSubscriptionTier"
    
    // MARK: - Initialization
    
    private init() {
        loadCachedStatus()
    }
    
    // MARK: - Public Methods
    
    /// Fetch current subscription status from Supabase
    func fetchSubscription() async {
        guard let accessToken = AuthService.shared.accessToken else {
            isPremium = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            // Use the RPC function to get subscription with device count
            let url = SupabaseConfig.restURL.appendingPathComponent("rpc/get_my_subscription")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.allHTTPHeaderFields = SupabaseConfig.authHeaders(accessToken: accessToken)
            request.httpBody = "{}".data(using: .utf8)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                throw SubscriptionError.fetchFailed
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // Response is an array with one item
            if let infoArray = try? decoder.decode([SubscriptionInfo].self, from: data),
               let info = infoArray.first {
                self.isPremium = info.isPremium
                // Parse tier from status string
                let tier = parseTierFromStatus(info.status)
                self.currentTier = tier
                cacheStatus(info.isPremium, tier: tier)
                print("✅ Subscription status: \(info.status) (tier: \(tier.displayName), premium: \(info.isPremium))")
            } else {
                // Fallback: Try direct query
                try await fetchSubscriptionDirect()
            }
            
        } catch {
            print("❌ Failed to fetch subscription: \(error)")
            // Use cached status if available
            loadCachedStatus()
        }
    }
    
    /// Start periodic subscription checks
    func startPeriodicChecks() {
        stopPeriodicChecks()
        
        // Check immediately
        Task {
            await fetchSubscription()
        }
        
        // Then check periodically
        checkTimer = Timer.scheduledTimer(withTimeInterval: SupabaseConfig.subscriptionCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchSubscription()
            }
        }
    }
    
    /// Stop periodic checks
    func stopPeriodicChecks() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
    
    /// Check if user can use premium features (with offline grace period)
    var canUsePremiumFeatures: Bool {
        if isPremium {
            return true
        }
        
        // Check offline grace period
        if let lastCheck = userDefaults.object(forKey: lastCheckKey) as? Date,
           let cachedPremium = userDefaults.object(forKey: cachedStatusKey) as? Bool,
           cachedPremium {
            let gracePeriod = TimeInterval(SupabaseConfig.offlineGracePeriodDays * 24 * 60 * 60)
            if Date().timeIntervalSince(lastCheck) < gracePeriod {
                return true
            }
        }
        
        return false
    }
    
    /// Get Stripe checkout URL for subscription
    /// - Parameters:
    ///   - tier: Subscription tier (Grace or Love)
    ///   - billingPeriod: Monthly or Yearly billing period
    /// - Returns: Stripe checkout URL with prefilled email if available
    func getCheckoutURL(tier: SubscriptionTier, billingPeriod: BillingPeriod) -> URL? {
        // Get the base checkout URL for the tier and billing period
        let baseURL: String
        switch (tier, billingPeriod) {
        case (.grace, .monthly):
            baseURL = "https://buy.stripe.com/8x228raJOceGbI50hn5AQ00"
        case (.grace, .yearly):
            baseURL = "https://buy.stripe.com/bJe00jf04emO7rPfch5AQ03"
        case (.love, .monthly):
            baseURL = "https://buy.stripe.com/7sYbJ14lqemO6nL7JP5AQ01"
        case (.love, .yearly):
            baseURL = "https://buy.stripe.com/dRmdR98BG2E6eUh4xD5AQ02"
        case (.mercy, _):
            return nil // Free tier doesn't have checkout
        }
        
        // Add prefilled email if available
        guard let email = AuthService.shared.currentUser?.email,
              let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return URL(string: baseURL)
        }
        
        // Stripe Payment Links support prefilled_email parameter
        return URL(string: "\(baseURL)?prefilled_email=\(encodedEmail)")
    }
    
    /// Legacy method for backward compatibility - defaults to Grace monthly
    func getCheckoutURL() -> URL? {
        return getCheckoutURL(tier: .grace, billingPeriod: .monthly)
    }
    
    /// Billing period options
    enum BillingPeriod {
        case monthly
        case yearly
    }
    
    // MARK: - Private Methods
    
    private func fetchSubscriptionDirect() async throws {
        guard let accessToken = AuthService.shared.accessToken,
              let userId = AuthService.shared.currentUser?.id else {
            throw SubscriptionError.notAuthenticated
        }
        
        let url = SupabaseConfig.restURL
            .appendingPathComponent("subscriptions")
            .appending(queryItems: [URLQueryItem(name: "user_id", value: "eq.\(userId)")])
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = SupabaseConfig.authHeaders(accessToken: accessToken)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            throw SubscriptionError.fetchFailed
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let subscriptions = try? decoder.decode([Subscription].self, from: data),
           let sub = subscriptions.first {
            self.subscription = sub
            self.isPremium = sub.isPremium && !sub.isExpired
            let tier = sub.status.toTier
            self.currentTier = tier
            cacheStatus(self.isPremium, tier: tier)
            print("✅ Subscription (direct): \(sub.status) (tier: \(tier.displayName), premium: \(self.isPremium))")
        } else {
            self.isPremium = false
            self.currentTier = .mercy
            cacheStatus(false, tier: .mercy)
        }
    }
    
    /// Parse tier from status string returned by API
    private func parseTierFromStatus(_ status: String) -> SubscriptionTier {
        let lowercased = status.lowercased()
        if lowercased.contains("love") || lowercased.contains("pro") {
            return .love
        } else if lowercased.contains("grace") || lowercased.contains("premium") {
            return .grace
        } else {
            return .mercy
        }
    }
    
    private func cacheStatus(_ isPremium: Bool, tier: SubscriptionTier) {
        userDefaults.set(isPremium, forKey: cachedStatusKey)
        userDefaults.set(tier.rawValue, forKey: cachedTierKey)
        userDefaults.set(Date(), forKey: lastCheckKey)
    }
    
    private func loadCachedStatus() {
        if let cached = userDefaults.object(forKey: cachedStatusKey) as? Bool {
            self.isPremium = cached
        }
        if let cachedTierRaw = userDefaults.string(forKey: cachedTierKey),
           let tier = SubscriptionTier(rawValue: cachedTierRaw) {
            self.currentTier = tier
        }
    }
}

// MARK: - Subscription Errors

enum SubscriptionError: LocalizedError {
    case notAuthenticated
    case fetchFailed
    case upgradeFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to manage your subscription."
        case .fetchFailed:
            return "Could not load subscription status. Please try again."
        case .upgradeFailed:
            return "Upgrade failed. Please try again or contact support."
        }
    }
}
