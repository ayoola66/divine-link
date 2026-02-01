import SwiftUI
import Combine
#if canImport(Sparkle)
import Sparkle
#endif

// MARK: - Sparkle Updater Controller

/// Manages automatic updates via Sparkle framework
/// 
/// Usage:
/// 1. Add Sparkle package: File → Add Packages → https://github.com/sparkle-project/Sparkle
/// 2. The app will automatically check for updates on launch
/// 3. Users can manually check via "Divine Link" menu → "Check for Updates"
///
final class SparkleUpdaterController: ObservableObject {
    
    #if canImport(Sparkle)
    private let updaterController: SPUStandardUpdaterController
    #endif
    
    @Published var canCheckForUpdates = false
    @Published var lastUpdateCheck: Date?
    @Published var isCheckingForUpdates = false
    
    static let shared = SparkleUpdaterController()
    
    private init() {
        #if canImport(Sparkle)
        // Create the updater controller
        // - startingUpdater: true = automatically start checking for updates
        // - updaterDelegate: nil = use default behavior
        // - userDriverDelegate: nil = use default UI
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        // Observe when we can check for updates
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        
        // Observe last update check date
        updaterController.updater.publisher(for: \.lastUpdateCheckDate)
            .assign(to: &$lastUpdateCheck)
        
        print("✅ Sparkle updater initialized")
        print("   Feed URL: \(updaterController.updater.feedURL?.absoluteString ?? "Not set")")
        print("   Auto check: \(updaterController.updater.automaticallyChecksForUpdates)")
        #else
        print("⚠️ Sparkle not available - add the package to enable auto-updates")
        #endif
    }
    
    // MARK: - Public Methods
    
    /// Manually check for updates
    /// Called when user clicks "Check for Updates" in the menu
    func checkForUpdates() {
        #if canImport(Sparkle)
        guard canCheckForUpdates else {
            print("⚠️ Cannot check for updates right now")
            return
        }
        
        isCheckingForUpdates = true
        updaterController.checkForUpdates(nil)
        
        // Reset checking state after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.isCheckingForUpdates = false
        }
        #else
        print("⚠️ Sparkle not available")
        #endif
    }
    
    /// Check for updates silently in background
    func checkForUpdatesInBackground() {
        #if canImport(Sparkle)
        updaterController.updater.checkForUpdatesInBackground()
        #endif
    }
    
    // MARK: - Updater Settings
    
    /// Whether to automatically check for updates
    var automaticallyChecksForUpdates: Bool {
        get {
            #if canImport(Sparkle)
            return updaterController.updater.automaticallyChecksForUpdates
            #else
            return false
            #endif
        }
        set {
            #if canImport(Sparkle)
            updaterController.updater.automaticallyChecksForUpdates = newValue
            #endif
        }
    }
    
    /// How often to check for updates (in seconds)
    var updateCheckInterval: TimeInterval {
        get {
            #if canImport(Sparkle)
            return updaterController.updater.updateCheckInterval
            #else
            return 86400 // 24 hours
            #endif
        }
        set {
            #if canImport(Sparkle)
            updaterController.updater.updateCheckInterval = newValue
            #endif
        }
    }
    
    /// Whether to automatically download updates
    var automaticallyDownloadsUpdates: Bool {
        get {
            #if canImport(Sparkle)
            return updaterController.updater.automaticallyDownloadsUpdates
            #else
            return false
            #endif
        }
        set {
            #if canImport(Sparkle)
            updaterController.updater.automaticallyDownloadsUpdates = newValue
            #endif
        }
    }
}

// MARK: - SwiftUI View for Menu

/// "Check for Updates" button for use in SwiftUI views
struct CheckForUpdatesView: View {
    @ObservedObject private var updater = SparkleUpdaterController.shared
    
    var body: some View {
        Button("Check for Updates...") {
            updater.checkForUpdates()
        }
        .disabled(!updater.canCheckForUpdates || updater.isCheckingForUpdates)
    }
}

// MARK: - Settings Section

/// Update settings for the Settings view
struct UpdateSettingsView: View {
    @ObservedObject private var updater = SparkleUpdaterController.shared
    @State private var autoCheck = true
    @State private var autoDownload = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Automatically check for updates", isOn: $autoCheck)
                    .onChange(of: autoCheck) { _, newValue in
                        updater.automaticallyChecksForUpdates = newValue
                    }
                
                Toggle("Automatically download updates", isOn: $autoDownload)
                    .onChange(of: autoDownload) { _, newValue in
                        updater.automaticallyDownloadsUpdates = newValue
                    }
                    .disabled(!autoCheck)
                
                HStack {
                    Text("Last checked:")
                    Spacer()
                    if let lastCheck = updater.lastUpdateCheck {
                        Text(lastCheck, style: .relative)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Never")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Button {
                    updater.checkForUpdates()
                } label: {
                    HStack {
                        if updater.isCheckingForUpdates {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text(updater.isCheckingForUpdates ? "Checking..." : "Check for Updates Now")
                    }
                }
                .disabled(!updater.canCheckForUpdates || updater.isCheckingForUpdates)
            } header: {
                Text("Software Updates")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            autoCheck = updater.automaticallyChecksForUpdates
            autoDownload = updater.automaticallyDownloadsUpdates
        }
    }
}
