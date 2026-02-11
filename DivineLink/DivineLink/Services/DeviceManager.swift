import Foundation
import Combine
import IOKit

// MARK: - Device Model

struct RegisteredDevice: Codable, Identifiable {
    let id: String
    let userId: String
    let deviceId: String
    let deviceName: String?
    let deviceModel: String?
    let osVersion: String?
    let appVersion: String?
    let lastActiveAt: Date
    let createdAt: Date
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case deviceId = "device_id"
        case deviceName = "device_name"
        case deviceModel = "device_model"
        case osVersion = "os_version"
        case appVersion = "app_version"
        case lastActiveAt = "last_active_at"
        case createdAt = "created_at"
        case isActive = "is_active"
    }
}

// MARK: - Device Manager

@MainActor
final class DeviceManager: ObservableObject {
    
    static let shared = DeviceManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var devices: [RegisteredDevice] = []
    @Published private(set) var currentDeviceRegistered = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Device Info
    
    /// Unique device identifier (hardware UUID)
    var deviceId: String {
        getHardwareUUID() ?? UUID().uuidString
    }
    
    /// Current device name
    var deviceName: String {
        Host.current().localizedName ?? "Mac"
    }
    
    /// Device model
    var deviceModel: String {
        getDeviceModel() ?? "Mac"
    }
    
    /// macOS version
    var osVersion: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }
    
    /// App version
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Register this device for the current user
    func registerCurrentDevice() async throws {
        guard let accessToken = AuthService.shared.accessToken,
              let userId = AuthService.shared.currentUser?.id else {
            throw DeviceError.notAuthenticated
        }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        // First check if device limit reached
        let canRegister = try await checkCanRegisterDevice()
        
        if !canRegister && !isDeviceAlreadyRegistered() {
            throw DeviceError.deviceLimitReached
        }
        
        // Upsert device (insert or update if exists)
        let url = SupabaseConfig.restURL.appendingPathComponent("devices")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = SupabaseConfig.authHeaders(accessToken: accessToken)
        request.addValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let body: [String: Any] = [
            "user_id": userId,
            "device_id": deviceId,
            "device_name": deviceName,
            "device_model": deviceModel,
            "os_version": osVersion,
            "app_version": appVersion,
            "last_active_at": ISO8601DateFormatter().string(from: Date()),
            "is_active": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            throw DeviceError.registrationFailed
        }
        
        currentDeviceRegistered = true
        print("✅ Device registered: \(deviceName)")
        
        // Refresh device list
        await fetchDevices()
    }
    
    /// Update last active timestamp
    func updateLastActive() async {
        guard let accessToken = AuthService.shared.accessToken,
              let userId = AuthService.shared.currentUser?.id else {
            return
        }
        
        let url = SupabaseConfig.restURL
            .appendingPathComponent("devices")
            .appending(queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(userId)"),
                URLQueryItem(name: "device_id", value: "eq.\(deviceId)")
            ])
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.allHTTPHeaderFields = SupabaseConfig.authHeaders(accessToken: accessToken)
        
        let body: [String: Any] = [
            "last_active_at": ISO8601DateFormatter().string(from: Date()),
            "app_version": appVersion
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let _ = try await URLSession.shared.data(for: request)
        } catch {
            print("⚠️ Failed to update last active: \(error)")
        }
    }
    
    /// Fetch all registered devices for current user
    func fetchDevices() async {
        guard let accessToken = AuthService.shared.accessToken,
              let userId = AuthService.shared.currentUser?.id else {
            return
        }
        
        isLoading = true
        
        defer { isLoading = false }
        
        let url = SupabaseConfig.restURL
            .appendingPathComponent("devices")
            .appending(queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(userId)"),
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "order", value: "last_active_at.desc")
            ])
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = SupabaseConfig.authHeaders(accessToken: accessToken)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                return
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            devices = try decoder.decode([RegisteredDevice].self, from: data)
            currentDeviceRegistered = devices.contains { $0.deviceId == deviceId }
            
            print("✅ Fetched \(devices.count) devices")
        } catch {
            print("❌ Failed to fetch devices: \(error)")
        }
    }
    
    /// Remove a device
    func removeDevice(_ device: RegisteredDevice) async throws {
        guard let accessToken = AuthService.shared.accessToken else {
            throw DeviceError.notAuthenticated
        }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        let url = SupabaseConfig.restURL
            .appendingPathComponent("devices")
            .appending(queryItems: [URLQueryItem(name: "id", value: "eq.\(device.id)")])
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = SupabaseConfig.authHeaders(accessToken: accessToken)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            throw DeviceError.removalFailed
        }
        
        print("✅ Device removed: \(device.deviceName ?? device.deviceId)")
        
        // Refresh list
        await fetchDevices()
    }
    
    /// Deactivate current device (soft delete)
    func deactivateCurrentDevice() async throws {
        guard let accessToken = AuthService.shared.accessToken,
              let userId = AuthService.shared.currentUser?.id else {
            throw DeviceError.notAuthenticated
        }
        
        let url = SupabaseConfig.restURL
            .appendingPathComponent("devices")
            .appending(queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(userId)"),
                URLQueryItem(name: "device_id", value: "eq.\(deviceId)")
            ])
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.allHTTPHeaderFields = SupabaseConfig.authHeaders(accessToken: accessToken)
        
        let body: [String: Any] = ["is_active": false]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            throw DeviceError.removalFailed
        }
        
        currentDeviceRegistered = false
        print("✅ Current device deactivated")
    }
    
    // MARK: - Private Methods
    
    private func checkCanRegisterDevice() async throws -> Bool {
        guard let accessToken = AuthService.shared.accessToken,
              let userId = AuthService.shared.currentUser?.id else {
            return false
        }
        
        // Use RPC function
        let url = SupabaseConfig.restURL.appendingPathComponent("rpc/can_register_device")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = SupabaseConfig.authHeaders(accessToken: accessToken)
        
        let body: [String: Any] = ["p_user_id": userId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            // If RPC fails, count devices manually
            return await countDevices() < SubscriptionService.shared.currentTier.deviceLimit
        }
        
        if let result = try? JSONDecoder().decode(Bool.self, from: data) {
            return result
        }
        
        return false
    }
    
    private func countDevices() async -> Int {
        await fetchDevices()
        return devices.count
    }
    
    private func isDeviceAlreadyRegistered() -> Bool {
        devices.contains { $0.deviceId == deviceId }
    }
    
    private func getHardwareUUID() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }
        
        guard service != 0 else { return nil }
        
        if let uuid = IORegistryEntryCreateCFProperty(service, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
            return uuid
        }
        
        return nil
    }
    
    private func getDeviceModel() -> String? {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
}

// MARK: - Device Errors

enum DeviceError: LocalizedError {
    case notAuthenticated
    case deviceLimitReached
    case registrationFailed
    case removalFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to manage devices."
        case .deviceLimitReached:
            return "You've reached the maximum of 2 devices. Please remove a device to add a new one."
        case .registrationFailed:
            return "Failed to register this device. Please try again."
        case .removalFailed:
            return "Failed to remove device. Please try again."
        }
    }
}
