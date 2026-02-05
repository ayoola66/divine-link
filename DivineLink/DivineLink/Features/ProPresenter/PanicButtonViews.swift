import SwiftUI

// MARK: - Panic Button UI Component

/// A prominent "Clear/Panic" button for the main interface
struct PanicButton: View {
    @ObservedObject var service: PanicButtonService
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: buttonIcon)
                    .font(.system(size: 12, weight: .bold))
                Text(buttonText)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(buttonBackground)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .help("Clear ProPresenter display (F12 or ⌘+Esc) - verse history stays in Divine Link")
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    private var buttonIcon: String {
        switch service.state {
        case .idle:
            return "xmark.circle.fill"
        case .clearing:
            return "hourglass"
        case .cleared:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var buttonText: String {
        switch service.state {
        case .idle:
            return "Clear"
        case .clearing:
            return "Clearing..."
        case .cleared:
            return "Cleared"
        case .error:
            return "Error"
        }
    }
    
    private var buttonBackground: Color {
        switch service.state {
        case .idle:
            return Color.red.opacity(0.85)
        case .clearing:
            return Color.orange
        case .cleared:
            return Color.green
        case .error:
            return Color.red
        }
    }
}

// MARK: - Visual Feedback Overlay

/// Full-screen overlay that flashes briefly when panic button is triggered
struct ClearFeedbackOverlay: View {
    @ObservedObject var service: PanicButtonService
    
    var body: some View {
        Group {
            if service.showVisualFeedback && shouldShowOverlay {
                ZStack {
                    overlayColour
                        .ignoresSafeArea()
                    
                    VStack(spacing: 12) {
                        Image(systemName: overlayIcon)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text(overlayText)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: service.state)
    }
    
    private var shouldShowOverlay: Bool {
        switch service.state {
        case .clearing, .cleared, .error:
            return true
        case .idle:
            return false
        }
    }
    
    private var overlayColour: Color {
        switch service.state {
        case .clearing:
            return Color.orange.opacity(0.4)
        case .cleared:
            return Color.green.opacity(0.3)
        case .error:
            return Color.red.opacity(0.4)
        case .idle:
            return Color.clear
        }
    }
    
    private var overlayIcon: String {
        switch service.state {
        case .clearing:
            return "hourglass"
        case .cleared:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .idle:
            return ""
        }
    }
    
    private var overlayText: String {
        switch service.state {
        case .clearing:
            return "CLEARING..."
        case .cleared:
            return "CLEARED"
        case .error(let message):
            return message.uppercased()
        case .idle:
            return ""
        }
    }
}

// MARK: - Compact Status Indicator

/// Small status indicator for the header area
struct ClearStatusIndicator: View {
    @ObservedObject var service: PanicButtonService
    
    var body: some View {
        if service.state != .idle {
            HStack(spacing: 4) {
                Image(systemName: statusIcon)
                    .font(.caption2)
                Text(statusText)
                    .font(.caption2)
            }
            .foregroundStyle(statusColour)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColour.opacity(0.15))
            .clipShape(Capsule())
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    private var statusIcon: String {
        switch service.state {
        case .idle:
            return ""
        case .clearing:
            return "hourglass"
        case .cleared:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var statusText: String {
        switch service.state {
        case .idle:
            return ""
        case .clearing:
            return "Clearing..."
        case .cleared:
            return "Cleared"
        case .error:
            return "Error"
        }
    }
    
    private var statusColour: Color {
        switch service.state {
        case .idle:
            return .clear
        case .clearing:
            return .orange
        case .cleared:
            return .green
        case .error:
            return .red
        }
    }
}

// MARK: - Settings Section for Panic Button

struct PanicButtonSettingsSection: View {
    @ObservedObject var service: PanicButtonService
    
    var body: some View {
        GroupBox("Safety Controls") {
            VStack(alignment: .leading, spacing: 12) {
                // Shortcut info
                HStack {
                    Text("Panic Button Shortcuts:")
                        .font(.subheadline)
                    Spacer()
                    Text("F12 or ⌘+Esc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                
                Divider()
                
                // Audio feedback toggle
                Toggle(isOn: $service.playAudioFeedback) {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(.secondary)
                        Text("Play audio cue on clear")
                    }
                }
                .onChange(of: service.playAudioFeedback) {
                    service.saveSettings()
                }
                
                // Visual feedback toggle
                Toggle(isOn: $service.showVisualFeedback) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.secondary)
                        Text("Show visual feedback")
                    }
                }
                .onChange(of: service.showVisualFeedback) {
                    service.saveSettings()
                }
                
                // Last clear time
                if let lastClear = service.lastClearTime {
                    Divider()
                    HStack {
                        Text("Last cleared:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(lastClear, style: .time)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Previews

#Preview("Panic Button - Idle") {
    let service = PanicButtonService.shared
    return PanicButton(service: service) { }
        .padding()
}

#Preview("Panic Button - All States") {
    VStack(spacing: 20) {
        let service = PanicButtonService.shared
        PanicButton(service: service) { }
    }
    .padding()
}

#Preview("Settings Section") {
    PanicButtonSettingsSection(service: PanicButtonService.shared)
        .padding()
        .frame(width: 400)
}
