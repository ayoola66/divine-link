import Foundation
import Security
import Combine

// MARK: - Auth Models

struct AuthUser: Codable {
    let id: String
    let email: String
    let createdAt: String?  // Keep as String to avoid date parsing issues
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
    }
}

struct AuthSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let expiresAt: Int?  // Unix timestamp as Int
    let user: AuthUser
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
        case user
    }
    
    var expiresAtDate: Date? {
        guard let expiresAt = expiresAt else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(expiresAt))
    }
}

struct OTPResponse: Codable {
    let messageId: String?
    
    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidEmail
    case networkError(Error)
    case invalidOTP
    case sessionExpired
    case deviceLimitReached
    case serverError(String)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidOTP:
            return "Invalid code. Please check and try again."
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .deviceLimitReached:
            return "You've reached the maximum of 2 devices. Please remove a device to continue."
        case .serverError(let message):
            return message
        case .unknown:
            return "An unexpected error occurred. Please try again."
        }
    }
}

// MARK: - Auth Service

@MainActor
final class AuthService: ObservableObject {
    
    static let shared = AuthService()
    
    // MARK: - Published Properties
    
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: AuthUser?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private var session: AuthSession?
    private let keychainService = "com.divinelink.auth"
    
    // MARK: - Initialization
    
    private init() {
        loadStoredSession()
    }
    
    // MARK: - Public Methods
    
    /// Request OTP code to be sent to email
    func requestOTP(email: String) async throws {
        guard isValidEmail(email) else {
            throw AuthError.invalidEmail
        }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        let url = SupabaseConfig.authURL.appendingPathComponent("otp")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = SupabaseConfig.publicHeaders
        
        let body: [String: Any] = [
            "email": email,
            "create_user": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.unknown
            }
            
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                print("✅ OTP sent successfully to \(email)")
            } else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ OTP request failed (\(httpResponse.statusCode)): \(errorBody)")
                // Surface the ACTUAL cause instead of a generic message.
                let errorCode = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error_code"] as? String
                let message: String
                if httpResponse.statusCode == 429 || errorCode == "over_email_send_rate_limit" {
                    message = "Too many code requests right now. Please wait a few minutes and try again."
                } else if errorCode == "signup_disabled" {
                    message = "New sign-ups are temporarily unavailable. Please try again later."
                } else if let serverMsg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["msg"] as? String, !serverMsg.isEmpty {
                    message = serverMsg
                } else {
                    message = "Couldn't send the verification code. Please check your connection and try again."
                }
                throw AuthError.serverError(message)
            }
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkError(error)
        }
    }
    
    /// Verify OTP code and sign in
    func verifyOTP(email: String, code: String) async throws {
        guard code.count == 6 else {
            throw AuthError.invalidOTP
        }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        let url = SupabaseConfig.authURL.appendingPathComponent("verify")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = SupabaseConfig.publicHeaders
        
        let body: [String: Any] = [
            "email": email,
            "token": code,
            "type": "email"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.unknown
            }
            
            // Debug: Print raw response
            let responseString = String(data: data, encoding: .utf8) ?? "No data"
            print("🔍 OTP Verify Response (\(httpResponse.statusCode)): \(responseString)")
            
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                do {
                    let decoder = JSONDecoder()
                    let session = try decoder.decode(AuthSession.self, from: data)
                    self.session = session
                    self.currentUser = session.user
                    self.isAuthenticated = true
                    
                    // Store session securely
                    saveSession(session)
                    
                    print("✅ User authenticated: \(session.user.email)")
                } catch {
                    print("❌ Failed to decode session: \(error)")
                    print("📄 Raw response: \(responseString)")
                    throw AuthError.serverError("Login succeeded but session couldn't be saved. Please try again.")
                }
            } else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ OTP verification failed: \(errorBody)")
                
                if errorBody.contains("Invalid") || errorBody.contains("expired") {
                    throw AuthError.invalidOTP
                } else {
                    throw AuthError.serverError("Verification failed. Please try again.")
                }
            }
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkError(error)
        }
    }
    
    /// Sign out current user
    func signOut() async {
        isLoading = true
        
        defer {
            isLoading = false
            session = nil
            currentUser = nil
            isAuthenticated = false
            clearStoredSession()
            SubscriptionService.shared.resetForSignOut()
        }
        
        guard let accessToken = session?.accessToken else { return }
        
        let url = SupabaseConfig.authURL.appendingPathComponent("logout")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = SupabaseConfig.authHeaders(accessToken: accessToken)
        
        do {
            let _ = try await URLSession.shared.data(for: request)
            print("✅ User signed out")
        } catch {
            print("⚠️ Sign out request failed (user logged out locally): \(error)")
        }
    }
    
    /// Get current access token for API calls
    var accessToken: String? {
        session?.accessToken
    }
    
    /// Refresh session if needed
    func refreshSessionIfNeeded() async throws {
        guard let session = session else {
            throw AuthError.sessionExpired
        }
        
        // Check if token is expired or about to expire (within 5 minutes)
        if let expiresAt = session.expiresAtDate, expiresAt.timeIntervalSinceNow < 300 {
            try await refreshSession()
        }
    }
    
    // MARK: - Private Methods
    
    private func refreshSession() async throws {
        guard let refreshToken = session?.refreshToken else {
            throw AuthError.sessionExpired
        }
        
        let url = SupabaseConfig.authURL.appendingPathComponent("token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = SupabaseConfig.publicHeaders
        request.addValue("refresh_token", forHTTPHeaderField: "grant_type")
        
        let body: [String: Any] = [
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            self.session = nil
            self.currentUser = nil
            self.isAuthenticated = false
            clearStoredSession()
            throw AuthError.sessionExpired
        }
        
        let decoder = JSONDecoder()
        let newSession = try decoder.decode(AuthSession.self, from: data)
        self.session = newSession
        self.currentUser = newSession.user
        saveSession(newSession)
        
        print("✅ Session refreshed")
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    // MARK: - Keychain Storage
    
    private func saveSession(_ session: AuthSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "session",
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func loadStoredSession() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "session",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let session = try? JSONDecoder().decode(AuthSession.self, from: data) else {
            return
        }
        
        self.session = session
        self.currentUser = session.user
        self.isAuthenticated = true
        
        print("✅ Session restored for \(session.user.email)")
        
        // Refresh session in background if needed
        Task {
            try? await refreshSessionIfNeeded()
        }
    }
    
    private func clearStoredSession() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "session"
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
