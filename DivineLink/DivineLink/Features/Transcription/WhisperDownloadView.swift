import SwiftUI

/// First-launch sheet (Apple Silicon only) offering the one-time enhanced-recognition model
/// download, with live progress driven by real download bytes. Choosing "Use standard
/// recognition" dismisses it and the app keeps working on Apple's Speech recognizer — the
/// model can be fetched later. Intel Macs never see this sheet.
struct WhisperDownloadView: View {
    @ObservedObject var manager: WhisperModelManager
    /// User explicitly chose to stay on standard recognition (declined enhanced).
    let onUseStandard: () -> Void
    /// Close the sheet without declining (e.g. "Done" after a successful install).
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 44))
                .foregroundStyle(.blue)

            Text("Enhanced Recognition")
                .font(.title2).bold()

            Text("Divine Link can use an on-device AI speech model for more accurate, punctuated transcription — fully offline once installed. It downloads once (about 464 MB) and is kept for next time.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            content
        }
        .padding(30)
        .frame(width: 420)
    }

    @ViewBuilder
    private var content: some View {
        switch manager.state {
        case .notInstalled:
            actionButtons(downloadTitle: "Download (~464 MB)")

        case let .downloading(fraction, received, total):
            VStack(spacing: 8) {
                ProgressView(value: max(0, min(fraction, 1)))
                    .progressViewStyle(.linear)
                Text(progressLabel(fraction: fraction, received: received, total: total))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Button("Continue with standard recognition", action: onUseStandard)
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)

        case .installed:
            Label("Enhanced recognition is ready.", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("It will be used the next time you start listening.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Done", action: onClose)
                .buttonStyle(.borderedProminent)

        case let .failed(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            actionButtons(downloadTitle: "Try again")
        }
    }

    @ViewBuilder
    private func actionButtons(downloadTitle: String) -> some View {
        VStack(spacing: 10) {
            Button(downloadTitle) {
                Task { await manager.download() }
            }
            .buttonStyle(.borderedProminent)

            Button("Use standard recognition", action: onUseStandard)
                .buttonStyle(.plain)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func progressLabel(fraction: Double, received: Int64, total: Int64) -> String {
        let pct = Int((max(0, min(fraction, 1)) * 100).rounded())
        if total > 0 {
            let f = ByteCountFormatter.string(fromByteCount: received, countStyle: .file)
            let t = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
            return "\(pct)%  ·  \(f) of \(t)"
        }
        return "\(pct)%  ·  preparing…"
    }
}
