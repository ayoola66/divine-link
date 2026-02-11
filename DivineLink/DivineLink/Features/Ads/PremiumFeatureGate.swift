import SwiftUI

// MARK: - Premium Feature Gate

/// A view modifier that gates premium features behind a subscription.
/// When the user is not premium, the content is greyed out and disabled,
/// with an overlay prompting them to upgrade.
struct PremiumFeatureGate: ViewModifier {
    @ObservedObject private var adManager = AdManager.shared
    let featureName: String
    
    /// Whether the user has premium access.
    /// CRITICAL: If not authenticated, this ALWAYS returns false.
    /// No cached AdManager status can grant premium access without a live session.
    private var isPremium: Bool {
        guard AuthService.shared.isAuthenticated else {
            return false
        }
        return SubscriptionService.shared.canUsePremiumFeatures
    }
    
    func body(content: Content) -> some View {
        if isPremium {
            // Premium user - show content normally
            content
        } else {
            // Free user - show greyed out content with upgrade overlay
            content
                .disabled(true)
                .opacity(0.4)
                .overlay(
                    PremiumGateOverlay(featureName: featureName)
                )
        }
    }
}

// MARK: - Premium Gate Overlay

/// The overlay shown when a feature is gated
private struct PremiumGateOverlay: View {
    @ObservedObject private var adManager = AdManager.shared
    let featureName: String
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Lock icon
            Image(systemName: "lock.fill")
                .font(.title)
                .foregroundStyle(.orange)
            
            // Feature name
            Text(featureName)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            // Description
            Text("Premium Feature")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Upgrade button
            Button {
                adManager.requestUpgrade()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                    Text("Upgrade to Premium")
                        .font(.callout)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.orange, Color.orange.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .orange.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .scaleEffect(isHovering ? 1.05 : 1.0)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .sheet(isPresented: $adManager.showPaywall) {
            PaywallView()
        }
    }
}

// MARK: - View Extension

extension View {
    /// Apply premium feature gating to this view.
    /// When the user is not premium, the content will be greyed out
    /// with an overlay prompting them to upgrade.
    ///
    /// - Parameter featureName: The name of the feature being gated (shown in the overlay)
    /// - Returns: A view with premium gating applied
    func premiumGated(featureName: String) -> some View {
        modifier(PremiumFeatureGate(featureName: featureName))
    }
}

// MARK: - Preview

#Preview("Premium Gate - Locked") {
    VStack(spacing: 20) {
        Text("Detection Settings")
            .font(.title2)
        
        // Simulated settings section
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enable Context Buffer", isOn: .constant(true))
            
            VStack(alignment: .leading) {
                Text("Context Timeout")
                    .font(.subheadline)
                Slider(value: .constant(5.0), in: 1...15)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .premiumGated(featureName: "Smart Context Detection")
    }
    .padding()
    .frame(width: 400, height: 400)
}
