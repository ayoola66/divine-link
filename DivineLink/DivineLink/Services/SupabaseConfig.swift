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
    
    /// Stripe Product ID for Divine Link Premium
    static let stripeProductID = "prod_TtV8U5mVO1cecV"
    
    /// Stripe Price ID for monthly subscription (£9.97/month)
    static let stripePriceID = "price_1Svi8dDyhT7xGc8kvz7qIrk6"
    
    /// Stripe Payment Link URL for Premium subscription
    static let stripePaymentLink = URL(string: "https://buy.stripe.com/8x228raJOceGbI50hn5AQ00")!
    
    // MARK: - App Configuration
    
    /// Maximum devices allowed per subscription
    static let maxDevicesPerAccount = 2
    
    /// Grace period for offline usage (in days)
    static let offlineGracePeriodDays = 7
    
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
