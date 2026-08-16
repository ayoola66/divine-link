import Foundation
import Combine
import AVFoundation
import AppKit
import os

// MARK: - Panic Button State

enum PanicButtonState: Equatable {
    case idle
    case clearing
    case cleared
    case error(String)
    
    var isClearing: Bool {
        if case .clearing = self { return true }
        return false
    }
}

// MARK: - Panic Button Service

/// Service that handles the "clear" button functionality to instantly clear scripture from ProPresenter.
///
/// **Important:** This clears the audience-facing displays only (ProPresenter and DivineView) —
/// Divine Link's verse history is preserved. The detected verses remain visible in the operator
/// window so users can re-send them if needed.
///
/// **Keyboard Shortcuts:**
/// - F12: Primary clear button
/// - Cmd+Escape: Alternative clear shortcut
///
/// **Clear Actions:**
/// 1. Clear the DivineView presentation window (local, immediate)
/// 2. Clear ProPresenter Stage Display (via HTTP DELETE)
/// 3. Clear ProPresenter Audience Display (via keyboard automation ⌘B toggle or Messages API)
///
/// **NOT Cleared:**
/// - Local Divine Link verse history (remains visible for re-use)
@MainActor
class PanicButtonService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var state: PanicButtonState = .idle
    @Published var lastClearTime: Date?
    @Published var playAudioFeedback: Bool = true
    @Published var showVisualFeedback: Bool = true
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.divinelink", category: "PanicButton")
    private var audioPlayer: AVAudioPlayer?
    private var feedbackTimer: Timer?
    
    // MARK: - Dependencies
    
    private weak var ppClient: ProPresenterClient?
    private weak var buffer: BufferManager?
    private var useHybridManager: Bool = true
    
    // MARK: - Singleton
    
    static let shared = PanicButtonService()
    
    // MARK: - Initialisation
    
    private init() {
        loadSettings()
    }
    
    // MARK: - Configuration
    
    /// Configure the service with required dependencies
    func configure(ppClient: ProPresenterClient, buffer: BufferManager, useHybridManager: Bool = true) {
        self.ppClient = ppClient
        self.buffer = buffer
        self.useHybridManager = useHybridManager
        logger.info("PanicButtonService configured (hybrid: \(useHybridManager))")
    }
    
    // MARK: - Main Clear Action
    
    /// Trigger the panic button — clears DivineView and the ProPresenter displays immediately.
    /// Note: this does NOT clear the local Divine Link verse history, so verses can be re-sent.
    /// Returns true if the clear was successful, false otherwise.
    @discardableResult
    func triggerClear() async -> Bool {
        guard state != .clearing else {
            logger.warning("Clear already in progress, ignoring duplicate request")
            return false
        }
        
        logger.info("🚨 CLEAR BUTTON TRIGGERED - Clearing ProPresenter and DivineView")
        state = .clearing
        DivineViewController.shared.clear()
        
        // Play audio feedback (if enabled)
        if playAudioFeedback {
            playClearSound()
        }
        
        var allSuccessful = true
        
        // NOTE: We intentionally do NOT clear the pending buffer or verse history.
        // Only the audience-facing surfaces are cleared: DivineView (above) and ProPresenter (below).
        
        if useHybridManager {
            // Use the new HybridIntegrationManager for multi-path clearing
            allSuccessful = await HybridIntegrationManager.shared.clearAllDisplays()
            logger.info("Hybrid manager clear result: \(allSuccessful)")
        } else {
            // Legacy path using direct client calls
            // 1. Clear ProPresenter Stage Display (HTTP DELETE)
            let stageCleared = await clearStageDisplay()
            if !stageCleared {
                allSuccessful = false
            }
            
            // 2. Clear ProPresenter Audience Display (keyboard automation)
            let audienceCleared = await clearAudienceDisplay()
            if !audienceCleared {
                allSuccessful = false
            }
        }
        
        // Update state
        lastClearTime = Date()
        
        if allSuccessful {
            state = .cleared
            logger.info("✅ All displays cleared successfully")
        } else {
            state = .error("Some displays may not have cleared")
            logger.warning("⚠️ Some displays may not have cleared")
        }
        
        // Reset state after brief delay
        scheduleStateReset()
        
        return allSuccessful
    }
    
    // MARK: - Individual Clear Actions
    
    /// Clear the local Divine Link display (pending buffer)
    func clearLocalDisplay() {
        logger.info("Clearing local display")
        buffer?.clearAll()
    }
    
    /// Clear ProPresenter Stage Display via HTTP DELETE
    func clearStageDisplay() async -> Bool {
        guard let client = ppClient else {
            logger.warning("ProPresenter client not configured")
            return false
        }
        
        do {
            try await client.clearStageMessage()
            logger.info("Stage display cleared")
            return true
        } catch {
            logger.error("Failed to clear stage display: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Clear ProPresenter Audience Display via keyboard automation
    func clearAudienceDisplay() async -> Bool {
        guard let client = ppClient else {
            logger.warning("ProPresenter client not configured")
            return false
        }
        
        let success = await client.clearAudienceDisplay()
        if success {
            logger.info("Audience display cleared")
        } else {
            logger.warning("Failed to clear audience display")
        }
        return success
    }
    
    // MARK: - Audio Feedback
    
    /// Play the clear confirmation sound
    private func playClearSound() {
        // Try to load a system sound or bundled sound
        // Using a subtle "click" or "pop" sound
        
        // First try bundled sound
        if let url = Bundle.main.url(forResource: "clear", withExtension: "wav") {
            playSound(from: url)
            return
        }
        
        // Fallback to system sound
        NSSound.beep()
    }
    
    private func playSound(from url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 0.3 // Subtle volume
            audioPlayer?.play()
        } catch {
            logger.warning("Failed to play clear sound: \(error.localizedDescription)")
        }
    }
    
    // MARK: - State Management
    
    /// Schedule state reset after feedback duration
    private func scheduleStateReset() {
        feedbackTimer?.invalidate()
        feedbackTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.state = .idle
            }
        }
    }
    
    // MARK: - Settings
    
    private func loadSettings() {
        playAudioFeedback = UserDefaults.standard.bool(forKey: "panicButton.playAudio")
        showVisualFeedback = UserDefaults.standard.bool(forKey: "panicButton.showVisual")
        
        // Default to true if not set
        if !UserDefaults.standard.contains(key: "panicButton.playAudio") {
            playAudioFeedback = true
        }
        if !UserDefaults.standard.contains(key: "panicButton.showVisual") {
            showVisualFeedback = true
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(playAudioFeedback, forKey: "panicButton.playAudio")
        UserDefaults.standard.set(showVisualFeedback, forKey: "panicButton.showVisual")
    }
}

// MARK: - UserDefaults Extension

private extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
