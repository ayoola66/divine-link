//
//  DivineLinkApp.swift
//  DivineLink
//
//  Created by Ayo Ogunrekun on 17/01/2026.
//

import SwiftUI

@main
struct DivineLinkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Sparkle updater controller
    private let sparkleUpdater = SparkleUpdaterController.shared
    
    var body: some Scene {
        // Main application window
        WindowGroup {
            MainView()
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .defaultSize(width: 450, height: 550)
        .commands {
            // Add standard commands
            CommandGroup(replacing: .appInfo) {
                Button("About Divine Link") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
            
            // Add Check for Updates command in the app menu
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView()
                    .keyboardShortcut("U", modifiers: [.command])
                
                Divider()
            }
        }
        
        // Settings window
        Settings {
            SettingsView()
        }
    }
}
