import AppKit
import Combine
import SwiftUI

/// Owns the live DivineView verse payload. Push writes here; Panic clears here.
/// Opening the SwiftUI `Window` is requested via `windowOpenTick` so views can call `openWindow`.
@MainActor
final class DivineViewController: ObservableObject {
    static let shared = DivineViewController()
    static let windowID = "divine-view"

    @Published private(set) var reference: String = ""
    @Published private(set) var verseText: String = ""
    @Published private(set) var translation: String = ""
    @Published private(set) var isShowingVerse: Bool = false

    /// Incremented whenever a caller wants the DivineView window shown.
    @Published private(set) var windowOpenTick: Int = 0

    private init() {}

    /// Why the DivineView window is being shown.
    enum OpenReason {
        /// The operator explicitly asked for the window (toolbar button, menu, Settings).
        case userRequested
        /// A verse was pushed and `openOnPush` is enabled.
        case versePushed
    }

    func present(reference: String, text: String, translation: String) {
        self.reference = reference
        self.verseText = text
        self.translation = translation
        self.isShowingVerse = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if DivineViewSettings.shared.openOnPush {
            requestOpenWindow(reason: .versePushed)
        }
    }

    func presentAll(from verse: PendingVerse) {
        present(
            reference: verse.displayReference,
            text: verse.fullText,
            translation: verse.translation
        )
    }

    func presentOne(from verse: PendingVerse) {
        guard let current = verse.currentVerse else { return }
        let singleRef = "\(verse.reference.book) \(verse.reference.chapter):\(current.verseNumber)"
        present(
            reference: singleRef,
            text: current.text,
            translation: verse.translation
        )
    }

    func clear() {
        reference = ""
        verseText = ""
        translation = ""
        isShowingVerse = false
    }

    func requestOpenWindow(reason: OpenReason = .userRequested) {
        if let existing = existingWindow() {
            if existing.isMiniaturized {
                existing.deminiaturize(nil)
            }

            switch reason {
            case .userRequested:
                existing.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            case .versePushed:
                // Show the projector window without activating Divine Link. Taking key status
                // here would break the operator window's Space/Enter/Delete shortcuts and could
                // interrupt ProPresenter's keyboard automation mid-service.
                existing.orderFrontRegardless()
            }
            return
        }
        windowOpenTick += 1
    }

    private func existingWindow() -> NSWindow? {
        NSApp.windows.first { window in
            window.identifier?.rawValue == Self.windowID || window.title == "DivineView"
        }
    }
}

/// Invisible helper so AppKit/services can open the SwiftUI Window scene.
struct DivineViewWindowOpener: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var controller = DivineViewController.shared

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onChange(of: controller.windowOpenTick) { _, tick in
                guard tick > 0 else { return }
                openWindow(id: DivineViewController.windowID)
            }
    }
}
