import AppKit
import SwiftUI

/// App delegate for managing application lifecycle and optional menu bar quick access
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    
    private var statusItem: NSStatusItem?
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup optional menu bar quick access icon
        setupMenuBarIcon()
        
        // Check for old sessions on launch
        Task { @MainActor in
            ArchiveCleanupService.shared.checkOnLaunch()
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running when window is closed (can reopen from menu bar)
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Reopen main window when clicking Dock icon
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }
    
    // MARK: - Menu Bar Quick Access (Optional)
    
    private func setupMenuBarIcon() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "book.fill", accessibilityDescription: "Divine Link")
            button.action = #selector(handleMenuBarClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    // MARK: - Event Handling
    
    @objc private func handleMenuBarClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            // Left click - bring main window to front
            bringMainWindowToFront()
        }
    }
    
    private func bringMainWindowToFront() {
        NSApp.activate(ignoringOtherApps: true)
        
        // Find and focus the main window
        for window in NSApp.windows {
            if window.title == "Divine Link" || window.isMainWindow {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
        
        // If no window found, open a new one
        if let firstWindow = NSApp.windows.first {
            firstWindow.makeKeyAndOrderFront(nil)
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        // Show main window
        let showItem = NSMenuItem(
            title: "Show Divine Link",
            action: #selector(showMainWindow),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Divine Link",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
    
    // MARK: - Actions
    
    @objc private func showMainWindow() {
        bringMainWindowToFront()
    }
    
    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
