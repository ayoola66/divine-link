import SwiftUI
import Combine

/// Persisted appearance and behaviour for the DivineView presentation window.
@MainActor
final class DivineViewSettings: ObservableObject {
    static let shared = DivineViewSettings()

    private enum Keys {
        static let background = "divineView.background"
        static let openOnPush = "divineView.openOnPush"
    }

    enum Background: String, CaseIterable, Identifiable {
        case black
        case white

        var id: String { rawValue }

        var title: String {
            switch self {
            case .black: return "Black"
            case .white: return "White"
            }
        }

        var fill: Color {
            switch self {
            case .black: return .black
            case .white: return .white
            }
        }

        var text: Color {
            switch self {
            case .black: return .white
            case .white: return .black
            }
        }
    }

    @Published var background: Background {
        didSet { UserDefaults.standard.set(background.rawValue, forKey: Keys.background) }
    }

    /// When true, pushing a verse brings DivineView to the front (and opens it if needed).
    @Published var openOnPush: Bool {
        didSet { UserDefaults.standard.set(openOnPush, forKey: Keys.openOnPush) }
    }

    private init() {
        if let stored = UserDefaults.standard.string(forKey: Keys.background),
           let parsed = Background(rawValue: stored) {
            background = parsed
        } else {
            background = .black
        }

        if UserDefaults.standard.object(forKey: Keys.openOnPush) == nil {
            openOnPush = true
        } else {
            openOnPush = UserDefaults.standard.bool(forKey: Keys.openOnPush)
        }
    }
}
