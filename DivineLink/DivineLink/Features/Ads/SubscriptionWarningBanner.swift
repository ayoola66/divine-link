import SwiftUI

/// A red warning banner displayed at the top of the main view when subscription
/// status requires user attention (grace period countdown or expired premium)
struct SubscriptionWarningBanner: View {
    @ObservedObject var subscriptionService = SubscriptionService.shared
    
    var body: some View {
        if subscriptionService.showSubscriptionWarning {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                
                // Show countdown badge if days remaining
                if let days = subscriptionService.gracePeriodDaysRemaining, days > 0 {
                    Text("\(days)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.3))
                        .clipShape(Capsule())
                    
                    Text(days == 1
                         ? "day left — please reconnect or update payment"
                         : "days left — please reconnect or update payment")
                        .font(.caption)
                        .lineLimit(1)
                } else {
                    // Expired completely
                    Text(subscriptionService.subscriptionWarningMessage)
                        .font(.caption)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Link to subscription settings
                SettingsLink {
                    Text("Manage")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.25))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button {
                    subscriptionService.showSubscriptionWarning = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.red)
            .foregroundColor(.white)
        }
    }
}

#Preview("Warning Banner - Countdown") {
    VStack {
        SubscriptionWarningBanner()
        Spacer()
    }
}
