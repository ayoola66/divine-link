import Foundation
import Cocoa
import ApplicationServices

// MARK: - Keyboard Automation Service

/// Service for simulating keyboard input to control ProPresenter
/// Used to trigger PP's native Bible feature via ⌘B shortcut
@MainActor
class KeyboardAutomationService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var hasAccessibilityPermission = false
    @Published var lastError: String?
    
    // MARK: - Singleton
    
    static let shared = KeyboardAutomationService()
    
    // MARK: - Initialisation
    
    init() {
        checkAccessibilityPermission()
    }
    
    // MARK: - Permission Handling
    
    /// Check if we have accessibility permission
    func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        hasAccessibilityPermission = trusted
        return trusted
    }
    
    /// Request accessibility permission (shows system prompt)
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        hasAccessibilityPermission = trusted
        
        if !trusted {
            print("⚠️ Accessibility permission required for keyboard automation")
            print("   Please grant access in System Preferences → Privacy & Security → Accessibility")
        } else {
            print("✅ Accessibility permission granted")
        }
    }
    
    // MARK: - ProPresenter Bible Automation
    
    /// Push a scripture reference to ProPresenter's Audience screen via native Bible feature
    /// Workflow: ⌘B → type reference → Enter
    func pushToProPresenterBible(reference: String) async -> Bool {
        guard checkAccessibilityPermission() else {
            lastError = "Accessibility permission required"
            print("❌ Cannot automate: Accessibility permission not granted")
            requestAccessibilityPermission()
            return false
        }
        
        print("🎹 Keyboard automation: Pushing '\(reference)' to ProPresenter Bible")
        
        // Ensure ProPresenter is frontmost
        guard activateProPresenter() else {
            lastError = "Could not activate ProPresenter"
            print("❌ Could not bring ProPresenter to front")
            return false
        }
        
        // Small delay to ensure PP is ready
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Step 1: Press ⌘B to open Bible search
        simulateKeyPress(keyCode: 11, modifiers: .maskCommand) // 'B' key
        print("   → Pressed ⌘B")
        
        // Wait for Bible dialog to open
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Step 2: Clear any existing text and type the reference
        // First select all (⌘A) to replace any existing text
        simulateKeyPress(keyCode: 0, modifiers: .maskCommand) // 'A' key
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        // Type the scripture reference
        typeText(reference)
        print("   → Typed '\(reference)'")
        
        // Wait for PP to process the reference
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Step 3: Press Enter to display
        simulateKeyPress(keyCode: 36, modifiers: []) // Enter key
        print("   → Pressed Enter")
        
        print("✅ Keyboard automation complete")
        lastError = nil
        return true
    }
    
    /// Clear the current Bible display in ProPresenter
    func clearProPresenterBible() async -> Bool {
        guard checkAccessibilityPermission() else {
            lastError = "Accessibility permission required"
            return false
        }
        
        guard activateProPresenter() else {
            lastError = "Could not activate ProPresenter"
            return false
        }
        
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Press Escape to clear/close
        simulateKeyPress(keyCode: 53, modifiers: []) // Escape key
        print("🎹 Pressed Escape to clear")
        
        return true
    }
    
    // MARK: - App Activation
    
    /// Bring ProPresenter to the front
    private func activateProPresenter() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        
        // Look for ProPresenter by bundle identifier or name
        let ppApp = runningApps.first { app in
            let bundleId = app.bundleIdentifier?.lowercased() ?? ""
            let name = app.localizedName?.lowercased() ?? ""
            return bundleId.contains("propresenter") || name.contains("propresenter")
        }
        
        guard let app = ppApp else {
            print("❌ ProPresenter is not running")
            lastError = "ProPresenter is not running"
            return false
        }
        
        let activated = app.activate(options: [])
        if activated {
            print("✅ Activated ProPresenter")
        } else {
            print("⚠️ Could not activate ProPresenter (may already be active)")
        }
        
        return true // Return true even if already active
    }
    
    // MARK: - Low-Level Keyboard Simulation
    
    /// Simulate a key press with optional modifiers
    private func simulateKeyPress(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Key down
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
            keyDown.flags = modifiers
            keyDown.post(tap: .cghidEventTap)
        }
        
        // Small delay between down and up
        usleep(10000) // 10ms
        
        // Key up
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
            keyUp.flags = modifiers
            keyUp.post(tap: .cghidEventTap)
        }
        
        // Small delay after key press
        usleep(20000) // 20ms
    }
    
    /// Type a string of text character by character
    private func typeText(_ text: String) {
        let source = CGEventSource(stateID: .hidSystemState)
        
        for char in text {
            // Create a key event for the character
            if let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                var unicodeChar = Array(String(char).utf16)
                event.keyboardSetUnicodeString(stringLength: unicodeChar.count, unicodeString: &unicodeChar)
                event.post(tap: .cghidEventTap)
            }
            
            if let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                event.post(tap: .cghidEventTap)
            }
            
            // Small delay between characters
            usleep(15000) // 15ms per character
        }
    }
}

// MARK: - Key Codes Reference
/*
 Common key codes for reference:
 - A: 0, B: 11, C: 8, D: 2, E: 14, F: 3, G: 5, H: 4, I: 34, J: 38
 - K: 40, L: 37, M: 46, N: 45, O: 31, P: 35, Q: 12, R: 15, S: 1, T: 17
 - U: 32, V: 9, W: 13, X: 7, Y: 16, Z: 6
 - 0: 29, 1: 18, 2: 19, 3: 20, 4: 21, 5: 23, 6: 22, 7: 26, 8: 28, 9: 25
 - Return: 36, Tab: 48, Space: 49, Delete: 51, Escape: 53
 - Command: .maskCommand, Shift: .maskShift, Option: .maskAlternate, Control: .maskControl
 */
