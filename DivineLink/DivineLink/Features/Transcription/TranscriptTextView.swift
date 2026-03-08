import AppKit
import SwiftUI

// MARK: - TranscriptTextView
//
// NSViewRepresentable that wraps NSTextView to give the Live Transcript panel
// proper macOS text-selection behaviour (click, double-click word, drag to select
// a phrase) while remaining read-only (non-editable).
//
// Selection changes are published back to SwiftUI via @Binding<String> so the
// pencil button can activate and the correction popover can know what was selected.
//
// Auto-scroll: checks the scroll position synchronously on every content update.
// If the view is already at (or near) the bottom, it scrolls to follow new content.
// The moment the user scrolls up, auto-scroll stops — no race condition possible
// because the position is read at decision time, not set by a notification flag.

struct TranscriptTextView: NSViewRepresentable {

    // MARK: - Bindings / inputs

    /// All finalised transcript lines to display.
    let lines: [TranscriptLine]
    /// The in-progress (non-final) text shown after the last finalised line.
    let currentText: String
    /// Updated with the user's selected text whenever the selection changes.
    @Binding var selectedText: String
    /// Called when the user applies a correction: (originalLineText, replacementText).
    var onCorrection: ((String, String) -> Void)?

    // MARK: - NSViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedText: $selectedText, onCorrection: onCorrection)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 2
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textColor = NSColor.secondaryLabelColor

        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.autoresizingMask = [.width, .height]
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear

        context.coordinator.scrollView = scrollView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView,
              let storage = textView.textStorage else { return }

        // Rebuild the full attributed string from all lines + current in-progress text
        let attrString = NSMutableAttributedString()
        let lineFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let lineColor = NSColor.secondaryLabelColor
        let inProgressColor = NSColor.tertiaryLabelColor

        var offsetMap: [(id: UUID, range: NSRange)] = []
        var cursor = 0

        for line in lines {
            let lineText = line.text + "\n"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: lineFont,
                .foregroundColor: lineColor
            ]
            let nsLine = NSAttributedString(string: lineText, attributes: attrs)
            offsetMap.append((id: line.id, range: NSRange(location: cursor, length: line.text.count)))
            cursor += (lineText as NSString).length
            attrString.append(nsLine)
        }

        if !currentText.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: lineFont,
                .foregroundColor: inProgressColor
            ]
            attrString.append(NSAttributedString(string: currentText, attributes: attrs))
        } else if lines.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.tertiaryLabelColor
            ]
            attrString.append(NSAttributedString(string: "Listening...", attributes: attrs))
        }

        // Only replace storage content if it actually changed (avoids selection flicker)
        if storage.string != attrString.string {
            // Check scroll position BEFORE replacing content — this is the source of truth.
            // If the view is within 10pt of the bottom, keep auto-scrolling.
            // If the user has scrolled up at all, leave their position alone.
            let contentMaxY = scrollView.documentView?.frame.maxY ?? 0
            let visibleMaxY = scrollView.documentVisibleRect.maxY
            let isAtBottom = contentMaxY <= 0 || visibleMaxY >= contentMaxY - 10

            let savedRange = textView.selectedRange()
            context.coordinator.isUpdatingContent = true
            storage.setAttributedString(attrString)
            context.coordinator.isUpdatingContent = false

            // Restore selection if it's still valid
            let newLen = storage.length
            if savedRange.location + savedRange.length <= newLen {
                textView.setSelectedRange(savedRange)
            }
            context.coordinator.lineOffsetMap = offsetMap

            // Auto-scroll only when already at the bottom
            if isAtBottom {
                DispatchQueue.main.async {
                    textView.scrollToEndOfDocument(nil)
                }
            }
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {

        @Binding var selectedText: String
        var onCorrection: ((String, String) -> Void)?
        weak var scrollView: NSScrollView?
        weak var textView: NSTextView?

        /// Maps each finalised TranscriptLine to its character range in the NSTextView.
        var lineOffsetMap: [(id: UUID, range: NSRange)] = []
        /// True while updateNSView is replacing text storage — suppresses selection
        /// callbacks that would modify SwiftUI @Binding mid-view-update.
        var isUpdatingContent = false

        init(selectedText: Binding<String>, onCorrection: ((String, String) -> Void)?) {
            _selectedText = selectedText
            self.onCorrection = onCorrection
        }

        // MARK: NSTextViewDelegate

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isUpdatingContent else { return }
            guard let textView = notification.object as? NSTextView else { return }
            let range = textView.selectedRange()
            if range.length > 0, let text = textView.string as NSString? {
                let safe = NSRange(
                    location: range.location,
                    length: min(range.length, text.length - range.location)
                )
                selectedText = text.substring(with: safe)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                selectedText = ""
            }
        }

        // MARK: - Line lookup

        /// Returns the TranscriptLine text whose char range contains `location`.
        func lineText(at location: Int) -> String? {
            for entry in lineOffsetMap {
                if NSLocationInRange(location, entry.range) {
                    return textView?.string.substring(nsRange: entry.range)
                }
            }
            return nil
        }
    }
}

// MARK: - String helper

private extension String {
    func substring(nsRange: NSRange) -> String? {
        guard let range = Range(nsRange, in: self) else { return nil }
        return String(self[range])
    }
}
