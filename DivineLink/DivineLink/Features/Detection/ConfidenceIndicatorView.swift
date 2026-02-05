import SwiftUI

// MARK: - Confidence Indicator View

/// Displays the confidence level of a scripture detection
/// Shows icon, level text, and percentage on hover
struct ConfidenceIndicatorView: View {
    let confidence: DetectionConfidence
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: confidence.level.icon)
                .foregroundColor(confidence.level.colour)
                .font(.system(size: 12))
            
            Text(confidence.level.rawValue)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(confidence.level.colour)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(confidence.level.colour.opacity(0.15))
        .clipShape(Capsule())
        .help("\(confidence.percentage)% confident\n\n\(confidence.breakdown)")
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Compact Confidence Badge

/// A more compact version showing just an icon with colour
struct CompactConfidenceBadge: View {
    let confidence: DetectionConfidence
    
    var body: some View {
        Image(systemName: confidence.level.icon)
            .foregroundColor(confidence.level.colour)
            .font(.system(size: 10))
            .help("\(confidence.percentage)% confident")
    }
}

// MARK: - Confidence Progress Ring

/// A circular progress indicator showing confidence visually
struct ConfidenceProgressRing: View {
    let confidence: DetectionConfidence
    let size: CGFloat
    
    init(confidence: DetectionConfidence, size: CGFloat = 24) {
        self.confidence = confidence
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(lineWidth: 3)
                .opacity(0.2)
                .foregroundColor(confidence.level.colour)
            
            // Progress ring
            Circle()
                .trim(from: 0.0, to: CGFloat(confidence.overall))
                .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .foregroundColor(confidence.level.colour)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: confidence.overall)
            
            // Centre icon
            Image(systemName: confidence.level.icon)
                .font(.system(size: size * 0.4))
                .foregroundColor(confidence.level.colour)
        }
        .frame(width: size, height: size)
        .help("\(confidence.percentage)% confident")
    }
}

// MARK: - Low Confidence Warning Banner

/// A warning banner displayed for low-confidence detections
struct LowConfidenceWarning: View {
    let confidence: DetectionConfidence
    
    var body: some View {
        if confidence.level == .low {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
                
                Text("Low confidence – please verify before pushing")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - Confidence Breakdown View

/// Detailed breakdown of confidence factors (for settings/debug)
struct ConfidenceBreakdownView: View {
    let confidence: DetectionConfidence
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Overall
            HStack {
                Text("Overall")
                    .fontWeight(.semibold)
                Spacer()
                Text("\(confidence.percentage)%")
                    .fontWeight(.bold)
                    .foregroundColor(confidence.level.colour)
            }
            
            Divider()
            
            // Individual factors
            ConfidenceFactorRow(
                label: "Reference Clarity",
                value: confidence.referenceClarity,
                weight: "40%"
            )
            
            ConfidenceFactorRow(
                label: "Speech Recognition",
                value: confidence.speechConfidence,
                weight: "30%"
            )
            
            ConfidenceFactorRow(
                label: "Context Match",
                value: confidence.contextMatch,
                weight: "20%"
            )
            
            ConfidenceFactorRow(
                label: "Verse Exists",
                value: confidence.verseExistence,
                weight: "10%"
            )
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Individual row for confidence factor display
private struct ConfidenceFactorRow: View {
    let label: String
    let value: Double
    let weight: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("(\(weight))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            
            Spacer()
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    
                    Rectangle()
                        .fill(colorForValue(value))
                        .frame(width: geo.size.width * CGFloat(value))
                }
            }
            .frame(width: 60, height: 6)
            .clipShape(Capsule())
            
            Text("\(Int(value * 100))%")
                .font(.caption)
                .monospacedDigit()
                .frame(width: 35, alignment: .trailing)
        }
    }
    
    private func colorForValue(_ value: Double) -> Color {
        switch value {
        case 0.8...1.0: return .green
        case 0.5..<0.8: return .yellow
        default: return .orange
        }
    }
}

// MARK: - Previews

#Preview("Confidence Indicators") {
    VStack(spacing: 20) {
        ConfidenceIndicatorView(confidence: .high())
        ConfidenceIndicatorView(confidence: .medium())
        ConfidenceIndicatorView(confidence: .low())
    }
    .padding()
}

#Preview("Compact Badges") {
    HStack(spacing: 16) {
        CompactConfidenceBadge(confidence: .high())
        CompactConfidenceBadge(confidence: .medium())
        CompactConfidenceBadge(confidence: .low())
    }
    .padding()
}

#Preview("Progress Rings") {
    HStack(spacing: 20) {
        ConfidenceProgressRing(confidence: .high(), size: 32)
        ConfidenceProgressRing(confidence: .medium(), size: 32)
        ConfidenceProgressRing(confidence: .low(), size: 32)
    }
    .padding()
}

#Preview("Low Confidence Warning") {
    VStack(spacing: 10) {
        LowConfidenceWarning(confidence: .low())
        LowConfidenceWarning(confidence: .high()) // Should be empty
    }
    .padding()
}

#Preview("Breakdown View") {
    ConfidenceBreakdownView(confidence: DetectionConfidence(
        referenceClarity: 0.9,
        speechConfidence: 0.85,
        contextMatch: 0.7,
        verseExistence: 1.0
    ))
    .frame(width: 300)
    .padding()
}
