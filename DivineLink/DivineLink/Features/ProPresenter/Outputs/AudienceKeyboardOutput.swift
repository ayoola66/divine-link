import Foundation
import AppKit
import os

/// Output implementation for ProPresenter Audience Display via Keyboard Automation
class AudienceKeyboardOutput: ProPresenterOutput {
    
    // MARK: - Properties
    
    let outputType: ProPresenterOutputType = .audienceKeyboard
    
    private(set) var connectionStatus: ConnectionStatus = .unknown
    
    var isAvailable: Bool {
        // Keyboard automation requires accessibility permissions
        checkAccessibilityPermission()
    }
    
    // MARK: - Private Properties
    
    private var settings: ProPresenterSettings?
    private let logger = Logger(subsystem: "com.divinelink", category: "AudienceKeyboardOutput")
    
    // MARK: - Initialisation
    
    init() {
        // Check initial accessibility status
        _ = checkAccessibilityPermission()
    }
    
    // MARK: - ProPresenterOutput Protocol
    
    func configure(with settings: ProPresenterSettings) {
        self.settings = settings
    }
    
    func display(_ scripture: ScriptureDisplayData) async -> ProPresenterOutputResult {
        guard isAvailable else {
            return .unavailable(reason: "Accessibility permission not granted")
        }
        
        // Parse the reference to get book, chapter, verse
        guard let parsedRef = parseReference(scripture.reference) else {
            return .failure(ProPresenterError.invalidReference)
        }
        
        // Simulate keyboard input to ProPresenter
        let success = await simulateProPresenterBibleLookup(
            book: parsedRef.book,
            chapter: parsedRef.chapter,
            verse: parsedRef.verse,
            translation: scripture.translation ?? "KJV"
        )
        
        if success {
            logger.info("Keyboard automation sent: \(scripture.reference)")
            return .success
        } else {
            return .failure(ProPresenterError.keyboardAutomationFailed)
        }
    }
    
    func clear() async -> ProPresenterOutputResult {
        guard isAvailable else {
            return .unavailable(reason: "Accessibility permission not granted")
        }
        
        // Send Escape key to clear/close any open dialog
        let success = await simulateEscapeKey()
        
        if success {
            logger.info("Keyboard clear sent (Escape)")
            return .success
        } else {
            return .failure(ProPresenterError.keyboardAutomationFailed)
        }
    }
    
    func testConnection() async -> Bool {
        connectionStatus = .testing
        
        let hasPermission = checkAccessibilityPermission()
        connectionStatus = hasPermission ? .connected : .error("Accessibility permission required")
        
        return hasPermission
    }
    
    // MARK: - Accessibility
    
    private func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    /// Request accessibility permission (shows system prompt)
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    // MARK: - Reference Parsing
    
    private struct ParsedReference {
        let book: String
        let chapter: Int
        let verse: Int
    }
    
    private func parseReference(_ reference: String) -> ParsedReference? {
        // Parse reference like "John 3:16" or "1 John 2:3"
        let pattern = #"(.+?)\s+(\d+):(\d+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: reference, range: NSRange(reference.startIndex..., in: reference)) else {
            return nil
        }
        
        guard let bookRange = Range(match.range(at: 1), in: reference),
              let chapterRange = Range(match.range(at: 2), in: reference),
              let verseRange = Range(match.range(at: 3), in: reference) else {
            return nil
        }
        
        let book = String(reference[bookRange])
        guard let chapter = Int(reference[chapterRange]),
              let verse = Int(reference[verseRange]) else {
            return nil
        }
        
        return ParsedReference(book: book, chapter: chapter, verse: verse)
    }
    
    // MARK: - Keyboard Simulation
    
    private func simulateProPresenterBibleLookup(book: String, 
                                                   chapter: Int, 
                                                   verse: Int, 
                                                   translation: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                // First, bring ProPresenter to front
                guard self.activateProPresenter() else {
                    continuation.resume(returning: false)
                    return
                }
                
                // Wait a moment for ProPresenter to be ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    // Press Cmd+B to open Bible dialog
                    self.sendKeyPress(keyCode: 11, modifiers: .maskCommand)  // 'B' key
                    
                    // Wait for dialog
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        // Type the reference
                        let searchText = "\(book) \(chapter):\(verse)"
                        self.typeText(searchText)
                        
                        // Wait a moment then press Enter
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.sendKeyPress(keyCode: 36, modifiers: [])  // Enter key
                            
                            continuation.resume(returning: true)
                        }
                    }
                }
            }
        }
    }
    
    private func simulateEscapeKey() async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                guard self.activateProPresenter() else {
                    continuation.resume(returning: false)
                    return
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.sendKeyPress(keyCode: 53, modifiers: [])  // Escape key
                    continuation.resume(returning: true)
                }
            }
        }
    }
    
    private func activateProPresenter() -> Bool {
        // Find and activate ProPresenter
        let runningApps = NSWorkspace.shared.runningApplications
        
        let proPresenterApp = runningApps.first { app in
            app.bundleIdentifier?.contains("propresenter") == true ||
            app.localizedName?.lowercased().contains("propresenter") == true
        }
        
        guard let app = proPresenterApp else {
            logger.warning("ProPresenter not found running")
            return false
        }
        
        // Note: activateIgnoringOtherApps deprecated in macOS 14, but activate() alone may not focus
        // Using activate() which works on macOS 14+
        return app.activate()
    }
    
    private func sendKeyPress(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        
        let keyDown = CGEvent(keyboardEventSource: source, 
                               virtualKey: keyCode, 
                               keyDown: true)
        keyDown?.flags = modifiers
        keyDown?.post(tap: .cghidEventTap)
        
        let keyUp = CGEvent(keyboardEventSource: source, 
                             virtualKey: keyCode, 
                             keyDown: false)
        keyUp?.flags = modifiers
        keyUp?.post(tap: .cghidEventTap)
    }
    
    private func typeText(_ text: String) {
        let source = CGEventSource(stateID: .hidSystemState)
        
        for char in text {
            if let event = CGEvent(keyboardEventSource: source, 
                                    virtualKey: 0, 
                                    keyDown: true) {
                var unicodeChar = UniChar(char.asciiValue ?? 0)
                event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unicodeChar)
                event.post(tap: .cghidEventTap)
            }
            
            if let event = CGEvent(keyboardEventSource: source, 
                                    virtualKey: 0, 
                                    keyDown: false) {
                event.post(tap: .cghidEventTap)
            }
            
            // Small delay between characters
            Thread.sleep(forTimeInterval: 0.01)
        }
    }
}
