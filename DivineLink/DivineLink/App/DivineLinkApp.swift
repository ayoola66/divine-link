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
        Settings {
            SettingsView()
        }
    }
}
