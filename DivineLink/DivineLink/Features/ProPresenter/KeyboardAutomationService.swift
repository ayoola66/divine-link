import Foundation
import Cocoa
import Combine
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
    @discardableResult
    func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        hasAccessibilityPermission = trusted
        print("🔐 Accessibility permission check: \(trusted ? "GRANTED" : "DENIED")")
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
    /// Workflow: ⌘B → clear text → type reference → Enter
    func pushToProPresenterBible(reference: String) async -> Bool {
        // Check permission but don't block - Xcode may have permission when debugging
        let hasPermission = checkAccessibilityPermission()
        if !hasPermission {
            print("⚠️ Accessibility permission not confirmed - attempting anyway (Xcode may have permission)")
            // Don't return false - try anyway for development
        }
        
        print("🎹 Keyboard automation: Pushing '\(reference)' to ProPresenter Bible")
        
        // Ensure ProPresenter is frontmost
        guard activateProPresenter() else {
            lastError = "Could not activate ProPresenter"
            print("❌ Could not bring ProPresenter to front")
            return false
        }
        
        // Longer delay to ensure PP is fully ready
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        // Step 1: Press Escape to clear any existing dialogs/selections
        simulateKeyPress(keyCode: 53, modifiers: []) // Escape key
        print("   → Pressed Escape to clear any existing state")
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Step 2: Click the "Bible" button in the toolbar to switch to Bible view
        // This ensures we're in the Bible section regardless of current view
        if clickBibleToolbarButton() {
            print("   → Clicked Bible toolbar button")
        } else {
            // Fallback: Try ⌘B shortcut if clicking failed
            print("   ⚠️ Could not click Bible button, trying ⌘B shortcut")
            simulateKeyPress(keyCode: 11, modifiers: .maskCommand) // 'B' key
            print("   → Pressed ⌘B as fallback")
        }
        
        // Wait for Bible panel to open
        try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        // Step 3: Click into the Scripture Lookup search bar (main/left search box)
        // This is more reliable than Tab navigation
        if clickScriptureLookupField() {
            print("   → Clicked into Scripture Lookup search bar")
        } else {
            print("   ⚠️ Could not click search bar, attempting to type anyway")
        }
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds for click to register
        
        // Step 4: Clear any existing text
        // Select all (⌘A) then delete
        simulateKeyPress(keyCode: 0, modifiers: .maskCommand) // 'A' key
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        simulateKeyPress(keyCode: 51, modifiers: []) // Delete key
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Press Delete a few more times for reliability
        for _ in 0..<5 {
            simulateKeyPress(keyCode: 51, modifiers: []) // Delete key
            try? await Task.sleep(nanoseconds: 30_000_000) // 0.03 seconds
        }
        print("   → Cleared existing text")
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Step 5: Type the scripture reference slowly
        typeTextSlowly(reference)
        print("   → Typed '\(reference)'")
        
        // Wait for PP to process the reference
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Step 6: Press Enter to display the verses
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
    
    // MARK: - Bible Toolbar Button Clicking
    
    /// Click the "Bible" button in ProPresenter's toolbar
    /// This switches to the Bible view regardless of current view
    private func clickBibleToolbarButton() -> Bool {
        // Get ProPresenter application
        let runningApps = NSWorkspace.shared.runningApplications
        let ppApp = runningApps.first { app in
            let bundleId = app.bundleIdentifier?.lowercased() ?? ""
            let name = app.localizedName?.lowercased() ?? ""
            return bundleId.contains("propresenter") || name.contains("propresenter")
        }
        
        guard let app = ppApp else {
            print("   ❌ Could not find ProPresenter process for Bible button click")
            return false
        }
        
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        
        // Try to find the Bible button in the toolbar
        if let bibleButton = findToolbarButton(in: appElement, withTitle: "Bible") {
            // Get the button's position and size
            var position: CFTypeRef?
            var size: CFTypeRef?
            var buttonPos = CGPoint.zero
            var buttonSize = CGSize(width: 60, height: 40)
            
            if AXUIElementCopyAttributeValue(bibleButton, kAXPositionAttribute as CFString, &position) == .success,
               CFGetTypeID(position!) == AXValueGetTypeID() {
                let posValue = position as! AXValue
                var pos = CGPoint.zero
                if AXValueGetValue(posValue, .cgPoint, &pos) {
                    buttonPos = pos
                }
            }
            
            if AXUIElementCopyAttributeValue(bibleButton, kAXSizeAttribute as CFString, &size) == .success,
               CFGetTypeID(size!) == AXValueGetTypeID() {
                let sizeValue = size as! AXValue
                var sz = CGSize.zero
                if AXValueGetValue(sizeValue, .cgSize, &sz) {
                    buttonSize = sz
                }
            }
            
            // Click the center of the button
            let clickPoint = CGPoint(
                x: buttonPos.x + buttonSize.width / 2,
                y: buttonPos.y + buttonSize.height / 2
            )
            
            clickAtPoint(clickPoint)
            print("   → Found and clicked Bible button at (\(Int(clickPoint.x)), \(Int(clickPoint.y)))")
            return true
        }
        
        // Fallback: Try clicking at estimated toolbar position for "Bible" button
        // Based on ProPresenter layout, Bible is typically in the top toolbar
        print("   ⚠️ Could not find Bible button via Accessibility, trying fallback")
        return clickBibleButtonFallback(appElement: appElement)
    }
    
    /// Find a toolbar button by its title/label
    private func findToolbarButton(in element: AXUIElement, withTitle title: String) -> AXUIElement? {
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
              CFGetTypeID(children!) == CFArrayGetTypeID() else {
            return nil
        }
        
        let childrenArray = children as! CFArray
        let count = CFArrayGetCount(childrenArray)
        
        for i in 0..<count {
            let child = unsafeBitCast(CFArrayGetValueAtIndex(childrenArray, i), to: AXUIElement.self)
            
            // Check if this element has a title or description matching "Bible"
            var titleAttr: CFTypeRef?
            var descAttr: CFTypeRef?
            var roleAttr: CFTypeRef?
            
            // Get role
            if AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleAttr) == .success,
               let role = roleAttr as? String {
                
                // Check title
                if AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleAttr) == .success,
                   let titleStr = titleAttr as? String,
                   titleStr.lowercased().contains(title.lowercased()) {
                    // Found it - check if it's a button or clickable element
                    if role == (kAXButtonRole as String) || role == "AXToolbarButton" || 
                       role == "AXRadioButton" || role == "AXCheckBox" {
                        return child
                    }
                }
                
                // Check description
                if AXUIElementCopyAttributeValue(child, kAXDescriptionAttribute as CFString, &descAttr) == .success,
                   let descStr = descAttr as? String,
                   descStr.lowercased().contains(title.lowercased()) {
                    if role == (kAXButtonRole as String) || role == "AXToolbarButton" || 
                       role == "AXRadioButton" || role == "AXCheckBox" {
                        return child
                    }
                }
            }
            
            // Recursively search children
            if let found = findToolbarButton(in: child, withTitle: title) {
                return found
            }
        }
        
        return nil
    }
    
    /// Fallback: Click at estimated position for Bible button in toolbar
    private func clickBibleButtonFallback(appElement: AXUIElement) -> Bool {
        // Get the main window
        var focusedWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) != .success {
            var windows: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows) == .success,
               CFGetTypeID(windows!) == CFArrayGetTypeID() {
                let windowsArray = windows as! CFArray
                if CFArrayGetCount(windowsArray) > 0 {
                    focusedWindow = unsafeBitCast(CFArrayGetValueAtIndex(windowsArray, 0), to: AXUIElement.self)
                }
            }
        }
        
        guard focusedWindow != nil else { return false }
        let window = focusedWindow as! AXUIElement
        
        // Get window position
        var position: CFTypeRef?
        var windowPos = CGPoint.zero
        
        if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &position) == .success,
           CFGetTypeID(position!) == AXValueGetTypeID() {
            let posValue = position as! AXValue
            var pos = CGPoint.zero
            if AXValueGetValue(posValue, .cgPoint, &pos) {
                windowPos = pos
            }
        }
        
        // Bible button is typically in the top toolbar, around 490px from left edge
        // Based on ProPresenter 7 layout: Search | Text | Theme | [gap] | Show | Edit | Reflow | Bible | More
        // Bible button is roughly at x = window.x + 490, y = window.y + 65
        let estimatedBibleX = windowPos.x + 490
        let estimatedBibleY = windowPos.y + 65
        
        let clickPoint = CGPoint(x: estimatedBibleX, y: estimatedBibleY)
        print("   → Fallback: clicking estimated Bible button at (\(Int(clickPoint.x)), \(Int(clickPoint.y)))")
        clickAtPoint(clickPoint)
        return true
    }
    
    // MARK: - Scripture Lookup Field Clicking
    
    /// Click directly into the Scripture Lookup search bar in ProPresenter
    /// Uses Accessibility APIs to find and click the search input field
    private func clickScriptureLookupField() -> Bool {
        // Get ProPresenter application
        let runningApps = NSWorkspace.shared.runningApplications
        let ppApp = runningApps.first { app in
            let bundleId = app.bundleIdentifier?.lowercased() ?? ""
            let name = app.localizedName?.lowercased() ?? ""
            return bundleId.contains("propresenter") || name.contains("propresenter")
        }
        
        guard let app = ppApp else {
            print("   ❌ Could not find ProPresenter process")
            return false
        }
        
        let pid = app.processIdentifier
        
        // Get the ProPresenter application element
        let appElement = AXUIElementCreateApplication(pid)
        
        // Try to find the search field by searching for text fields
        // Look for fields with "Scripture Lookup" or search-related attributes
        if let searchField = findSearchField(in: appElement) {
            var point = CGPoint.zero
            
            // Get the position of the search field
            var position: CFTypeRef?
            if AXUIElementCopyAttributeValue(searchField, kAXPositionAttribute as CFString, &position) == .success,
               CFGetTypeID(position!) == AXValueGetTypeID() {
                let posValue = position as! AXValue
                var pos = CGPoint.zero
                if AXValueGetValue(posValue, .cgPoint, &pos) {
                    point = pos
                }
            }
            
            // Get the size to click the center
            var size: CFTypeRef?
            var fieldSize = CGSize(width: 200, height: 30) // Default size
            if AXUIElementCopyAttributeValue(searchField, kAXSizeAttribute as CFString, &size) == .success,
               CFGetTypeID(size!) == AXValueGetTypeID() {
                let sizeValue = size as! AXValue
                var sz = CGSize.zero
                if AXValueGetValue(sizeValue, .cgSize, &sz) {
                    fieldSize = sz
                }
            }
            
            // Calculate center point of the search field
            let clickPoint = CGPoint(
                x: point.x + fieldSize.width / 2,
                y: point.y + fieldSize.height / 2
            )
            
            // Perform the click
            clickAtPoint(clickPoint)
            return true
        }
        
        // Fallback: Try clicking at a common location for the search bar
        // This is a best-guess approach if Accessibility APIs don't work
        print("   ⚠️ Could not find search field via Accessibility, using fallback click")
        return clickSearchFieldFallback()
    }
    
    /// Find the Scripture Lookup search field using Accessibility APIs
    private func findSearchField(in element: AXUIElement) -> AXUIElement? {
        // Try to find text fields or search fields
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
              CFGetTypeID(children!) == CFArrayGetTypeID() else {
            return nil
        }
        
        let childrenArray = children as! CFArray
        let count = CFArrayGetCount(childrenArray)
        
        for i in 0..<count {
            let child = unsafeBitCast(CFArrayGetValueAtIndex(childrenArray, i), to: AXUIElement.self)
            
            // Check if this is a text field
            var role: CFTypeRef?
            if AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role) == .success,
               let roleString = role as? String {
                
                // Look for text fields, search fields, or text areas
                // Using string literals as kAXSearchFieldRole is not available
                if roleString == (kAXTextFieldRole as String) || 
                   roleString == "AXSearchField" ||
                   roleString == (kAXTextAreaRole as String) {
                    
                    // Check if it's enabled (search fields usually are)
                    var enabled: CFTypeRef?
                    if AXUIElementCopyAttributeValue(child, kAXEnabledAttribute as CFString, &enabled) == .success {
                        return child
                    }
                }
            }
            
            // Recursively search children
            if let found = findSearchField(in: child) {
                return found
            }
        }
        
        return nil
    }
    
    /// Fallback method: Click at a common location for ProPresenter's search bar
    /// This uses screen coordinates as a last resort
    /// Based on typical ProPresenter layout: search bar is near top-center after ⌘B
    private func clickSearchFieldFallback() -> Bool {
        // Get ProPresenter application
        let runningApps = NSWorkspace.shared.runningApplications
        let ppApp = runningApps.first { app in
            let bundleId = app.bundleIdentifier?.lowercased() ?? ""
            let name = app.localizedName?.lowercased() ?? ""
            return bundleId.contains("propresenter") || name.contains("propresenter")
        }
        
        guard let app = ppApp else { return false }
        
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        
        // Get the focused window or main window
        var focusedWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) != .success {
            // Try to get main window
            var windows: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows) == .success,
               CFGetTypeID(windows!) == CFArrayGetTypeID() {
                let windowsArray = windows as! CFArray
                if CFArrayGetCount(windowsArray) > 0 {
                    focusedWindow = unsafeBitCast(CFArrayGetValueAtIndex(windowsArray, 0), to: AXUIElement.self)
                }
            }
        }
        
        guard focusedWindow != nil else { return false }
        let window = focusedWindow as! AXUIElement
        
        // Get window position and size
        var position: CFTypeRef?
        var size: CFTypeRef?
        var windowPos = CGPoint.zero
        var windowSize = CGSize(width: 1200, height: 800) // Default window size
        
        if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &position) == .success,
           CFGetTypeID(position!) == AXValueGetTypeID() {
            let posValue = position as! AXValue
            var pos = CGPoint.zero
            if AXValueGetValue(posValue, .cgPoint, &pos) {
                windowPos = pos
            }
        }
        
        if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &size) == .success,
           CFGetTypeID(size!) == AXValueGetTypeID() {
            let sizeValue = size as! AXValue
            var sz = CGSize.zero
            if AXValueGetValue(sizeValue, .cgSize, &sz) {
                windowSize = sz
            }
        }
        
        // Estimate search bar location: typically near top-center of window
        // After ⌘B, the search bar appears roughly 150-200px from top, centered horizontally
        let estimatedSearchX = windowPos.x + windowSize.width * 0.6 // Right side of window (where search bar typically is)
        let estimatedSearchY = windowPos.y + windowSize.height - 200 // Near top of window
        
        let clickPoint = CGPoint(x: estimatedSearchX, y: estimatedSearchY)
        clickAtPoint(clickPoint)
        return true
    }
    
    /// Perform a mouse click at the specified point
    private func clickAtPoint(_ point: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Move mouse to point
        if let moveEvent = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) {
            moveEvent.post(tap: .cghidEventTap)
        }
        
        usleep(50000) // 50ms delay
        
        // Click down
        if let downEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left) {
            downEvent.post(tap: .cghidEventTap)
        }
        
        usleep(10000) // 10ms delay
        
        // Click up
        if let upEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) {
            upEvent.post(tap: .cghidEventTap)
        }
        
        usleep(50000) // 50ms delay after click
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
    
    /// Type text more slowly to avoid ProPresenter auto-complete interference
    /// Uses longer delays between characters to prevent misinterpretation
    private func typeTextSlowly(_ text: String) {
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
            
            // Longer delay between characters to avoid auto-complete issues
            // Especially important for book names like "1 Timothy" vs "2 Timothy"
            usleep(30000) // 30ms per character (doubled from 15ms)
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
