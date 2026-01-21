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
    
    var body: some Scene {
        // Main application window
        WindowGroup {
            MainView()
        }
        .windowStyle(.automatic)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 400, height: 500)
        .commands {
            // Add standard commands
            CommandGroup(replacing: .appInfo) {
                Button("About Divine Link") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
        }
        
        // Settings window
        Settings {
            SettingsView()
        }
    }
}
