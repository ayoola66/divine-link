//
//  AppDelegate.swift
//  DivineLink
//
//  Created by Ayo Ogunrekun on 17/01/2026.
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Use SF Symbol as placeholder icon
            button.image = NSImage(systemSymbolName: "book.fill", accessibilityDescription: "Divine Link")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Create popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 400, height: 300)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MainView())
    }
    
    @objc func togglePopover() {
        guard let button = statusItem?.button,
              let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup if needed
    }
}
