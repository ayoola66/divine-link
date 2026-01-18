//
//  MainView.swift
//  DivineLink
//
//  Created by Ayo Ogunrekun on 17/01/2026.
//

import SwiftUI

struct MainView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.fill")
                .imageScale(.large)
                .foregroundStyle(.blue)
            
            Text("Divine Link")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Menu bar app shell")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(width: 300, height: 200)
    }
}

#Preview {
    MainView()
}
