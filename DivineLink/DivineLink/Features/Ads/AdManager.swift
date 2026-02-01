import SwiftUI
import Combine

// MARK: - Ad Configuration

/// Configuration for dynamic ad system
struct AdSystemConfig {
    /// Refresh interval for ads (in seconds)
    static let refreshInterval: TimeInterval = 3600  // 1 hour
    
    /// Maximum offline days before app locks
    static let maxOfflineDays: Int = 7
}

// MARK: - Subscription Status

/// User subscription status
enum SubscriptionStatus: Equatable {
    case free           // Shows ads
    case premium        // No ads, full features
    case trial(daysLeft: Int) // Trial period
    
    var showsAds: Bool {
        switch self {
        case .free: return true
        case .premium: return false
        case .trial: return false
        }
    }
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        case .trial(let days): return "Trial (\(days) days left)"
        }
    }
    
    var isPaid: Bool {
        switch self {
        case .free: return false
        case .premium, .trial: return true
        }
    }
}

// MARK: - Ad Slot Types

/// Different ad slot positions in the app
enum AdSlot: String, CaseIterable {
    case sidebarTop     // Right sidebar, top position (1:1 square)
    case sidebarMiddle  // Right sidebar, middle position (1:1 square or start of portrait)
    case sidebarBottom  // Right sidebar, bottom position (1:1 square or end of portrait)
    case bottomBanner   // Bottom of app, full width
    
    var aspectRatio: CGFloat {
        switch self {
        case .sidebarTop, .sidebarMiddle, .sidebarBottom:
            return 300.0 / 250.0 // AdMob Medium Rectangle ratio (1.2:1)
        case .bottomBanner:
            return 320.0 / 50.0 // Standard banner ratio (6.4:1)
        }
    }
    
    var preferredSize: CGSize {
        switch self {
        case .sidebarTop, .sidebarMiddle, .sidebarBottom:
            // AdMob Medium Rectangle: 300x250, scaled down to fit sidebar
            return CGSize(width: 160, height: 133) // Maintains 300:250 ratio
        case .bottomBanner:
            return CGSize(width: 468, height: 60) // Standard banner size
        }
    }
}

// MARK: - Ad Content

/// Represents an advertisement
struct AdContent: Identifiable {
    let id = UUID()
    let slot: AdSlot
    let imageURL: URL?
    let placeholderColor: Color
    let clickURL: URL?
    let advertiserName: String
    let isPlaceholder: Bool
    
    /// Create a placeholder ad for testing/development
    static func placeholder(for slot: AdSlot) -> AdContent {
        AdContent(
            slot: slot,
            imageURL: nil,
            placeholderColor: Color.gray.opacity(0.3),
            clickURL: nil,
            advertiserName: "Ad Space Available",
            isPlaceholder: true
        )
    }
}

// MARK: - Ad Manager

/// Manages advertisements and subscription status
class AdManager: ObservableObject {
    static let shared = AdManager()
    
    // MARK: - Published Properties
    
    @Published var subscriptionStatus: SubscriptionStatus = .free
    @Published var currentAds: [AdSlot: AdContent] = [:]
    @Published var isLoading = false
    
    // MARK: - Private Properties
    
    private var subscriptionCancellable: AnyCancellable?
    
    // MARK: - Computed Properties
    
    /// Whether to show ads in the UI
    var shouldShowAds: Bool {
        // Use SubscriptionService as source of truth when authenticated
        if AuthService.shared.isAuthenticated {
            return !SubscriptionService.shared.canUsePremiumFeatures
        }
        return subscriptionStatus.showsAds
    }
    
    /// Sidebar width when ads are shown
    var sidebarWidth: CGFloat {
        shouldShowAds ? 180 : 0 // Wider to fit 160px ads + padding
    }
    
    /// Bottom banner height when ads are shown
    var bottomBannerHeight: CGFloat {
        shouldShowAds ? 70 : 0
    }
    
    // MARK: - Initialisation
    
    private init() {
        // Load cached subscription status from UserDefaults
        let saved = UserDefaults.standard.string(forKey: "subscriptionStatus") ?? "free"
        
        if saved == "premium" {
            self.subscriptionStatus = .premium
        } else if saved.hasPrefix("trial:"), let days = Int(saved.dropFirst(6)) {
            self.subscriptionStatus = .trial(daysLeft: days)
        } else {
            self.subscriptionStatus = .free
        }
        
        // Observe SubscriptionService for real-time updates
        subscriptionCancellable = SubscriptionService.shared.$isPremium
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPremium in
                if isPremium {
                    self?.subscriptionStatus = .premium
                    UserDefaults.standard.set("premium", forKey: "subscriptionStatus")
                }
            }
        
        // Load ads (dynamic or placeholder)
        loadAds()
    }
    
    // MARK: - Ad Loading
    
    /// Load ads - tries dynamic first, falls back to placeholders
    private func loadAds() {
        // Check connectivity and load dynamic ads
        Task {
            await DynamicAdService.shared.fetchAds()
            await MainActor.run {
                self.syncAdsFromDynamicService()
            }
        }
    }
    
    /// Sync ads from DynamicAdService
    private func syncAdsFromDynamicService() {
        for slot in AdSlot.allCases {
            let displayContent = DynamicAdService.shared.ad(for: slot)
            currentAds[slot] = AdContent(
                slot: slot,
                imageURL: displayContent.imageURL,
                placeholderColor: Color.gray.opacity(0.3),
                clickURL: displayContent.clickURL,
                advertiserName: displayContent.altText,
                isPlaceholder: displayContent.isDefault
            )
        }
    }
    
    /// Refresh ads from server
    func refreshAds() {
        isLoading = true
        
        Task {
            await DynamicAdService.shared.fetchAds()
            await MainActor.run {
                self.syncAdsFromDynamicService()
                self.isLoading = false
            }
        }
    }
    
    /// Get ad content for a specific slot
    func ad(for slot: AdSlot) -> AdContent {
        currentAds[slot] ?? AdContent.placeholder(for: slot)
    }
    
    /// Check if app should be locked due to offline
    var isAppLocked: Bool {
        DynamicAdService.shared.connectivityStatus == .offlineExpired
    }
    
    // MARK: - Published Properties for Paywall
    
    @Published var showPaywall = false
    @Published var isPurchasing = false
    @Published var purchaseError: String?
    
    /// Debug mode - allows instant upgrade for testing (disable in production!)
    #if DEBUG
    @Published var debugModeEnabled = false
    #endif
    
    // MARK: - Subscription Management
    
    /// Request upgrade to premium - shows paywall
    func requestUpgrade() {
        print("💰 Upgrade to Premium requested - showing paywall")
        showPaywall = true
    }
    
    /// Actually upgrade to premium (called after successful payment)
    func upgradeToPremium() {
        print("✅ Premium upgrade successful")
        subscriptionStatus = .premium
        showPaywall = false
    }
    
    /// Upgrade to premium via debug mode (testing only)
    #if DEBUG
    func debugUpgrade() {
        if debugModeEnabled {
            print("🔧 DEBUG: Instant upgrade activated")
            upgradeToPremium()
        }
    }
    #endif
    
    /// Start a trial period
    func startTrial(days: Int = 7) {
        subscriptionStatus = .trial(daysLeft: days)
        showPaywall = false
    }
    
    /// Restore purchases - checks Supabase for existing subscription
    func restorePurchases() {
        print("🔄 Restore purchases requested")
        isPurchasing = true
        purchaseError = nil
        
        Task { @MainActor in
            // Check if user is signed in
            guard AuthService.shared.isAuthenticated else {
                isPurchasing = false
                purchaseError = "Please sign in to restore purchases"
                return
            }
            
            // Fetch subscription from Supabase
            await SubscriptionService.shared.fetchSubscription()
            
            isPurchasing = false
            
            if SubscriptionService.shared.isPremium {
                subscriptionStatus = .premium
                showPaywall = false
                print("✅ Subscription restored!")
            } else {
                purchaseError = "No active subscription found"
            }
        }
    }
    
    /// Purchase premium subscription - opens Stripe checkout
    func purchasePremium() {
        print("🛒 Purchase initiated")
        purchaseError = nil
        
        // Must be signed in to purchase
        guard AuthService.shared.isAuthenticated else {
            purchaseError = "Please sign in first to subscribe"
            return
        }
        
        // Open Stripe checkout in browser
        if let checkoutURL = SubscriptionService.shared.getCheckoutURL() {
            NSWorkspace.shared.open(checkoutURL)
            showPaywall = false
            
            // After they return from checkout, prompt to refresh
            // The webhook will update Supabase, then we fetch status
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                Task { @MainActor in
                    await SubscriptionService.shared.fetchSubscription()
                    if SubscriptionService.shared.isPremium {
                        self?.subscriptionStatus = .premium
                    }
                }
            }
        } else {
            purchaseError = "Could not open checkout. Please try again."
        }
    }
    
    /// Check if trial has expired
    func checkTrialStatus() {
        if case .trial(let days) = subscriptionStatus {
            if days <= 0 {
                subscriptionStatus = .free
            }
        }
    }
    
    /// Reset to free (for testing)
    func resetToFree() {
        subscriptionStatus = .free
    }
    
    // MARK: - Ad Interaction
    
    /// Record an ad click
    func recordAdClick(_ ad: AdContent) {
        print("📢 Ad clicked: \(ad.advertiserName)")
        
        if let url = ad.clickURL {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Record an ad impression
    func recordAdImpression(_ ad: AdContent) {
        // TODO: Implement impression tracking
        print("👁️ Ad impression: \(ad.advertiserName)")
    }
}
