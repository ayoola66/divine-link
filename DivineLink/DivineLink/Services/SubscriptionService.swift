import Foundation
import Combine
import SwiftUI
import AppKit  // NSWorkspace for opening the Stripe billing portal

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

    /// Subtle background tint for main window (Epic 7.2)
    var themeTint: Color {
        switch self {
        case .mercy: return Color.gray.opacity(0.04)
        case .grace: return Color.orange.opacity(0.06)
        case .love: return Color.purple.opacity(0.06)
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
    let tier: String?
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
        case tier
        case stripeCustomerId = "stripe_customer_id"
        case stripeSubscriptionId = "stripe_subscription_id"
        case currentPeriodStart = "current_period_start"
        case currentPeriodEnd = "current_period_end"
        case cancelAtPeriodEnd = "cancel_at_period_end"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var isPremium: Bool {
        status == .premium || status == .trial || status == .grace || status == .love
    }
    
    var isExpired: Bool {
        guard let endDate = currentPeriodEnd else { return false }
        return endDate < Date()
    }
}

struct SubscriptionInfo: Codable {
    let status: String
    let tier: String?
    let isPremium: Bool
    let periodEnd: Date?
    let deviceCount: Int
    let maxDevices: Int
    
    enum CodingKeys: String, CodingKey {
        case status
        case tier
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
    
    /// Admin access - grants full Love tier and debug options
    @Published private(set) var isAdmin = false
    
    /// Subscription warning banner state
    @Published var showSubscriptionWarning = false
    @Published var subscriptionWarningMessage = ""
    @Published var gracePeriodDaysRemaining: Int?
    
    /// Whether the user has ever been a paid customer (cached)
    @Published private(set) var hasBeenPaidCustomer = false

    /// When true, UI behaves as Free tier (ads, grey tint) for testing. Admin-only debug.
    @Published var debugSimulateFreeMode = false

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
    private let hasBeenPaidKey = "hasBeenPaidCustomer"
    private var authCancellable: AnyCancellable?
    
    /// Whether the current user's email is an admin email
    var isAdminEmail: Bool {
        guard let email = AuthService.shared.currentUser?.email.lowercased() else { return false }
        return SupabaseConfig.adminEmails.contains(email)
    }
    
    // MARK: - Initialization
    
    private init() {
        loadCachedStatus()
        observeAuthState()
    }
    
    /// Observe AuthService.isAuthenticated — when it transitions to false,
    /// immediately reset all subscription/admin/premium state.
    /// This prevents stale cached state from leaking through after
    /// session expiry or Keychain restoration failure.
    private func observeAuthState() {
        authCancellable = AuthService.shared.$isAuthenticated
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                guard let self = self else { return }
                if !isAuthenticated {
                    // User is not authenticated — enforce free state immediately
                    self.resetForSignOut()
                    print("🔒 Auth state changed to false — subscription state force-reset to Free")
                }
            }
    }
    
    // MARK: - Public Methods
    
    /// Fetch current subscription status from Supabase
    func fetchSubscription() async {
        // Check admin status first
        checkAdminStatus()
        
        guard let accessToken = AuthService.shared.accessToken else {
            isPremium = isAdmin
            if !isAdmin { evaluateGracePeriod() }
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
                
                // Admin always gets Love tier — never let the API downgrade them
                if isAdmin {
                    self.isPremium = true
                    self.currentTier = .love
                    clearWarnings()
                    print("👑 Admin override — ignoring API status (\(info.status))")
                } else {
                    self.isPremium = info.isPremium
                    // Parse tier from explicit tier field first, then status fallback
                    let tier = parseTier(tierValue: info.tier, statusValue: info.status)
                    self.currentTier = tier
                    cacheStatus(info.isPremium, tier: tier)
                    
                    // Track if user has ever been paid
                    if info.isPremium {
                        markAsPaidCustomer()
                    }
                    
                    // Clear warnings on successful premium verification
                    if info.isPremium {
                        clearWarnings()
                    } else {
                        // Subscription lapsed or cancelled - start grace period evaluation
                        evaluateGracePeriod()
                    }
                }
                
                print("✅ Subscription status: \(info.status) (tier: \(currentTier.displayName), premium: \(isPremium), admin: \(isAdmin))")
            } else {
                // Fallback: Try direct query
                try await fetchSubscriptionDirect()
            }
            
        } catch {
            print("❌ Failed to fetch subscription: \(error)")
            // Use cached status if available
            loadCachedStatus()
            // Evaluate grace period when we can't reach the server
            if !isAdmin { evaluateGracePeriod() }
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
    
    /// Check if user can use premium features (with admin bypass and grace period)
    var canUsePremiumFeatures: Bool {
        // CRITICAL: If not authenticated, no premium features — period.
        guard AuthService.shared.isAuthenticated else { return false }
        
        // Debug: simulate Free so admins can test ads and grey tint
        if debugSimulateFreeMode { return false }

        // Admin always has full access
        if isAdmin { return true }

        if isPremium { return true }
        
        // Check grace period - allow premium during countdown
        if let lastCheck = userDefaults.object(forKey: lastCheckKey) as? Date,
           let cachedPremium = userDefaults.object(forKey: cachedStatusKey) as? Bool,
           cachedPremium {
            let gracePeriod = TimeInterval(SupabaseConfig.offlineGracePeriodDays * 24 * 60 * 60)
            let elapsed = Date().timeIntervalSince(lastCheck)
            if elapsed < gracePeriod {
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

    /// Open Stripe's hosted Billing Portal so a premium user can manage billing address, payment
    /// method, invoices, and cancellation. Calls the /api/stripe-portal Netlify function with the
    /// user's Supabase token + their Stripe customer id, then opens the returned URL in the browser.
    /// Returns nil on success, or an error message to show the user.
    @discardableResult
    func openBillingPortal() async -> String? {
        guard let token = AuthService.shared.accessToken else { return "Please sign in first." }
        guard let customerId = subscription?.stripeCustomerId, !customerId.isEmpty else {
            return "No billing account found. This is only available after a paid subscription."
        }
        let url = URL(string: "https://divinelink.netlify.app/api/stripe-portal")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["customerId": customerId])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return "Couldn't reach the billing service." }
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            if http.statusCode == 200, let urlString = json?["url"] as? String, let portalURL = URL(string: urlString) {
                NSWorkspace.shared.open(portalURL)
                return nil
            }
            return (json?["error"] as? String) ?? "Couldn't open the billing portal. Please try again."
        } catch {
            return "Network error opening billing portal. Please try again."
        }
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
            
            // Admin always keeps Love tier — never let the API downgrade them
            if isAdmin {
                self.isPremium = true
                self.currentTier = .love
                print("👑 Admin override (direct) — ignoring API status (\(sub.status))")
            } else {
                self.isPremium = sub.isPremium && !sub.isExpired
                let tier = parseTier(tierValue: sub.tier, statusValue: sub.status.rawValue)
                self.currentTier = tier
                cacheStatus(self.isPremium, tier: tier)
                print("✅ Subscription (direct): \(sub.status) (tier: \(tier.displayName), premium: \(self.isPremium))")
            }
        } else {
            // No subscription record found — admin still keeps full access
            if isAdmin {
                self.isPremium = true
                self.currentTier = .love
                print("👑 Admin override — no subscription record, full access granted")
            } else {
                self.isPremium = false
                self.currentTier = .mercy
                cacheStatus(false, tier: .mercy)
            }
        }
    }
    
    /// Parse tier using explicit tier value first, then status fallback for backward compatibility.
    private func parseTier(tierValue: String?, statusValue: String) -> SubscriptionTier {
        if let tierValue {
            let lowerTier = tierValue.lowercased()
            if lowerTier.contains("love") || lowerTier.contains("pro") {
                return .love
            } else if lowerTier.contains("grace") || lowerTier.contains("premium") {
                return .grace
            } else if lowerTier.contains("mercy") || lowerTier.contains("free") {
                return .mercy
            }
        }
        
        let lowercased = statusValue.lowercased()
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
        // When not signed in, always enforce free tier — no exceptions.
        // Also clear any cached subscription data so it cannot leak
        // on a subsequent launch where the session might briefly appear valid.
        guard AuthService.shared.isAuthenticated else {
            self.isAdmin = false
            self.isPremium = false
            self.currentTier = .mercy
            self.hasBeenPaidCustomer = false
            // Clear cached subscription data to prevent stale state leaking
            userDefaults.removeObject(forKey: cachedStatusKey)
            userDefaults.removeObject(forKey: cachedTierKey)
            userDefaults.removeObject(forKey: lastCheckKey)
            print("🔒 Not signed in — subscription state reset and cache cleared (tint → grey)")
            return
        }

        // Check admin status immediately on cold start
        // so premium features are unlocked before the network call
        if isAdminEmail {
            self.isAdmin = true
            self.isPremium = true
            self.currentTier = .love
            self.hasBeenPaidCustomer = true
            print("👑 Admin detected on cold start — full access granted")
            return
        }

        if let cached = userDefaults.object(forKey: cachedStatusKey) as? Bool {
            self.isPremium = cached
        }
        if let cachedTierRaw = userDefaults.string(forKey: cachedTierKey),
           let tier = SubscriptionTier(rawValue: cachedTierRaw) {
            self.currentTier = tier
        }
        self.hasBeenPaidCustomer = userDefaults.bool(forKey: hasBeenPaidKey)
    }
    
    // MARK: - Admin Methods
    
    /// Check and set admin status based on current user email
    private func checkAdminStatus() {
        let wasAdmin = isAdmin
        isAdmin = isAdminEmail
        
        // Admin gets Love tier access
        if isAdmin && !wasAdmin {
            currentTier = .love
            isPremium = true
            print("👑 Admin access granted for: \(AuthService.shared.currentUser?.email ?? "unknown")")
        }
    }
    
    // MARK: - Grace Period & Warning Methods
    
    /// Mark the user as having been a paid customer (persisted)
    private func markAsPaidCustomer() {
        hasBeenPaidCustomer = true
        userDefaults.set(true, forKey: hasBeenPaidKey)
    }
    
    /// Clear all warning banners
    private func clearWarnings() {
        showSubscriptionWarning = false
        subscriptionWarningMessage = ""
        gracePeriodDaysRemaining = nil
    }
    
    /// Evaluate grace period and show countdown warning or revert to free
    private func evaluateGracePeriod() {
        guard let lastCheck = userDefaults.object(forKey: lastCheckKey) as? Date,
              let cachedPremium = userDefaults.object(forKey: cachedStatusKey) as? Bool,
              cachedPremium else {
            // Never had premium or no cached state - nothing to grace
            return
        }
        
        let gracePeriodSeconds = TimeInterval(SupabaseConfig.offlineGracePeriodDays * 24 * 60 * 60)
        let elapsed = Date().timeIntervalSince(lastCheck)
        let remainingSeconds = gracePeriodSeconds - elapsed
        let remainingDays = Int(ceil(remainingSeconds / (24 * 60 * 60)))
        
        if remainingSeconds <= 0 {
            // Grace period expired - revert to Free
            revertToFreeTier()
        } else {
            // Still in grace period - show warning with countdown
            gracePeriodDaysRemaining = max(0, remainingDays)
            showSubscriptionWarning = true
            
            if remainingDays == 1 {
                subscriptionWarningMessage = "Your premium access expires tomorrow. Please reconnect or update your payment to keep your features."
            } else {
                subscriptionWarningMessage = "Premium access expires in \(remainingDays) days. Please reconnect or update your payment."
            }
            
            print("⚠️ Grace period: \(remainingDays) days remaining")
        }
    }
    
    /// Revert the user to Free (Mercy) tier
    private func revertToFreeTier() {
        isPremium = false
        currentTier = .mercy
        cacheStatus(false, tier: .mercy)
        gracePeriodDaysRemaining = 0
        showSubscriptionWarning = true
        subscriptionWarningMessage = "Your premium access has expired. Please subscribe to regain premium features."
        print("🔒 Reverted to Free tier - grace period expired")
    }

    /// Call when user signs out — reset to free tier and clear admin state so UI (e.g. tint and ads) updates immediately.
    /// Also clears all cached subscription data from UserDefaults to prevent stale state on next launch.
    func resetForSignOut() {
        debugSimulateFreeMode = false
        isAdmin = false
        isPremium = false
        currentTier = .mercy
        hasBeenPaidCustomer = false
        subscription = nil
        clearWarnings()
        // Clear all cached subscription data — not just overwrite with free values
        userDefaults.removeObject(forKey: cachedStatusKey)
        userDefaults.removeObject(forKey: cachedTierKey)
        userDefaults.removeObject(forKey: lastCheckKey)
        userDefaults.removeObject(forKey: hasBeenPaidKey)
        print("🔒 Subscription state reset for sign out — all cache cleared (tint → Free/grey)")
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
