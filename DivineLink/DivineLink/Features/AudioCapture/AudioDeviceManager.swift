import AVFoundation
import Combine

/// Manages audio input device enumeration and selection
@MainActor
class AudioDeviceManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var availableDevices: [AVCaptureDevice] = []
    @Published var selectedDevice: AVCaptureDevice?
    @Published var isRefreshing: Bool = false
    private var hasInitialDiscoveryCompleted = false
    
    // MARK: - Constants
    
    private static let selectedDeviceUIDKey = "selectedAudioDeviceUID"
    static let blackHoleURL = URL(string: "https://existential.audio/blackhole/")!
    
    // MARK: - Initialisation
    
    init() {
        Task { @MainActor in
            await refreshDevices()
            await loadSavedDevice()
        }
    }
    
    // MARK: - Device Enumeration
    
    /// Refreshes the list of available audio input devices
    func refreshDevices() async {
        isRefreshing = true
        // Run discovery on high-priority background thread to avoid UI hang and QoS inversion
        let devices: [AVCaptureDevice] = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let discoverySession = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.microphone, .external],
                    mediaType: .audio,
                    position: .unspecified
                )
                continuation.resume(returning: discoverySession.devices)
            }
        }
        // Update on main actor
        self.availableDevices = devices
        // Validate current selection still exists
        if let selected = self.selectedDevice,
           !devices.contains(where: { $0.uniqueID == selected.uniqueID }) {
            await selectDefaultDevice()
        }
        self.isRefreshing = false
        self.hasInitialDiscoveryCompleted = true
    }
    
    // MARK: - Device Selection
    
    /// Selects an audio input device and persists the choice
    func selectDevice(_ device: AVCaptureDevice) async {
        selectedDevice = device
        await persistSelectedDevice(device)
    }
    
    /// Selects the system default audio input device
    func selectDefaultDevice() async {
        // Compute default device off-main to avoid any hidden blocking
        let defaultOrFirst: AVCaptureDevice? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                if let defaultDevice = AVCaptureDevice.default(for: .audio) {
                    continuation.resume(returning: defaultDevice)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
        if let device = defaultOrFirst ?? self.availableDevices.first {
            self.selectedDevice = device
            await persistSelectedDevice(device)
        } else {
            self.selectedDevice = nil
        }
    }
    
    // MARK: - Persistence
    
    private func persistSelectedDevice(_ device: AVCaptureDevice) async {
        let uid = device.uniqueID
        let key = Self.selectedDeviceUIDKey
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                UserDefaults.standard.set(uid, forKey: key)
                continuation.resume()
            }
        }
    }
    
    private func loadSavedDevice() async {
        // Ensure we have an up-to-date device list
        if !hasInitialDiscoveryCompleted {
            await refreshDevices()
        }
        let savedUID: String? = UserDefaults.standard.string(forKey: Self.selectedDeviceUIDKey)
        guard let savedUID else {
            await selectDefaultDevice()
            return
        }
        if let device = availableDevices.first(where: { $0.uniqueID == savedUID }) {
            self.selectedDevice = device
        } else {
            await selectDefaultDevice()
        }
    }
    
    // MARK: - BlackHole Detection
    
    /// Checks if BlackHole virtual audio driver is installed
    var isBlackHoleInstalled: Bool {
        availableDevices.contains { device in
            device.localizedName.lowercased().contains("blackhole")
        }
    }
    
    /// Returns BlackHole devices if installed
    var blackHoleDevices: [AVCaptureDevice] {
        availableDevices.filter { device in
            device.localizedName.lowercased().contains("blackhole")
        }
    }
    
}

// MARK: - Friendly Device Names

extension AVCaptureDevice {
    /// Returns a user-friendly name for the audio device
    var friendlyName: String {
        // The localizedName is already user-friendly in most cases
        // but we can add custom mappings if needed
        return localizedName
    }
}
