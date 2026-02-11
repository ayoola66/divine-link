import Foundation

// MARK: - Supabase Configuration

/// Configuration for Supabase backend services
enum SupabaseConfig {
    
    // MARK: - API Configuration
    
    /// Supabase project URL
    static let projectURL = URL(string: "https://qzjhjgkvvcamcqpdrgkf.supabase.co")!
    
    /// Supabase anonymous key (public - safe to include in app)
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6amhqZ2t2dmNhbWNxcGRyZ2tmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk4ODM0NzMsImV4cCI6MjA4NTQ1OTQ3M30.IQYO9V99IO7hubM87nVL14l6qaxvjNTKllDz2sXk6aU"
    
    // MARK: - Legacy Aliases (for compatibility)
    
    /// Alias for projectURL
    static var supabaseURL: String { projectURL.absoluteString }
    
    /// Alias for anonKey
    static var supabaseAnonKey: String { anonKey }
    
    // MARK: - API Endpoints
    
    /// Base URL for REST API
    static var restURL: URL {
        projectURL.appendingPathComponent("rest/v1")
    }
    
    /// Auth API URL
    static var authURL: URL {
        projectURL.appendingPathComponent("auth/v1")
    }
    
    /// Edge Functions URL
    static var functionsURL: URL {
        projectURL.appendingPathComponent("functions/v1")
    }
    
    // MARK: - Stripe Configuration
    
    /// Stripe Product ID for Grace tier
    static let graceProductID = "prod_TtV8U5mVO1cecV"
    
    /// Stripe Product ID for Love tier
    /// NOTE: Update this with the actual Love product ID from your Stripe dashboard
    static let loveProductID = "prod_TvU0LGh7zBgIH3"
    
    /// Legacy alias for backward compatibility
    static let stripeProductID = graceProductID
    
    /// Stripe Price ID for monthly subscription (£9.99/month)
    static let stripePriceID = "price_1Svi8dDyhT7xGc8kvz7qIrk6"
    
    /// Legacy Stripe Payment Link URL (defaults to Grace monthly)
    static let stripePaymentLink = URL(string: "https://buy.stripe.com/8x228raJOceGbI50hn5AQ00")!
    
    // MARK: - Admin Configuration
    
    /// Admin emails that get full Love-tier access and debug options
    static let adminEmails: Set<String> = [
        "ogunrekun66@hotmail.com"
    ]
    
    // MARK: - App Configuration
    
    /// Maximum devices allowed per subscription (legacy - use SubscriptionTier.deviceLimit instead)
    @available(*, deprecated, message: "Use SubscriptionTier.deviceLimit for tier-specific limits")
    static let maxDevicesPerAccount = 2
    
    /// Grace period for subscription verification (in days)
    /// After Stripe retries exhaust (1+3+9 = 13 days), the app gives an additional day
    /// for a total of 14 days before reverting to Free tier
    static let offlineGracePeriodDays = 14
    
    /// Subscription check interval (in seconds)
    static let subscriptionCheckInterval: TimeInterval = 3600 // 1 hour
}

// MARK: - API Headers

extension SupabaseConfig {
    
    /// Headers for unauthenticated requests
    static var publicHeaders: [String: String] {
        [
            "apikey": anonKey,
            "Content-Type": "application/json"
        ]
    }
    
    /// Headers for authenticated requests
    static func authHeaders(accessToken: String) -> [String: String] {
        [
            "apikey": anonKey,
            "Authorization": "Bearer \(accessToken)",
            "Content-Type": "application/json"
        ]
    }
}
