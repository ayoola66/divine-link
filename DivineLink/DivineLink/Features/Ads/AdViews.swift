import SwiftUI

// MARK: - Ad Container View

/// Container that wraps content with optional ad sidebar and bottom banner
struct AdContainerView<Content: View>: View {
    @ObservedObject private var adManager = AdManager.shared
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area with optional sidebar
            HStack(spacing: 0) {
                // Main content
                content
                
                // Right sidebar with ads (if showing ads)
                if adManager.shouldShowAds {
                    AdSidebarView()
                        .frame(width: adManager.sidebarWidth)
                }
            }
            
            // Bottom banner (if showing ads)
            if adManager.shouldShowAds {
                AdBannerView(slot: .bottomBanner)
                    .frame(height: adManager.bottomBannerHeight)
            }
        }
    }
}

// MARK: - Ad Sidebar View

/// Right sidebar containing stacked ad slots
struct AdSidebarView: View {
    @ObservedObject private var adManager = AdManager.shared
    @State private var sidebarLayout: SidebarAdLayout = .twoRectangles
    
    enum SidebarAdLayout {
        case twoRectangles          // 2 x Medium Rectangle (300x250 ratio)
        case threeSmall             // 3 x smaller ads
        case oneRectangleOneBanner  // 1 rectangle + 1 banner
    }
    
    var body: some View {
        VStack(spacing: 10) {
            switch sidebarLayout {
            case .twoRectangles:
                // Two medium rectangle ads (recommended for AdMob)
                AdSlotView(slot: .sidebarTop)
                AdSlotView(slot: .sidebarMiddle)
                
            case .threeSmall:
                // Three smaller ads stacked
                AdSlotView(slot: .sidebarTop)
                AdSlotView(slot: .sidebarMiddle)
                AdSlotView(slot: .sidebarBottom)
                
            case .oneRectangleOneBanner:
                // One rectangle + one portrait
                AdSlotView(slot: .sidebarTop)
                PortraitAdSlotView()
            }
            
            Spacer()
            
            // Upgrade button
            UpgradeButton()
        }
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1),
            alignment: .leading
        )
    }
}

// MARK: - Individual Ad Slot View

/// Single ad slot display
struct AdSlotView: View {
    let slot: AdSlot
    @ObservedObject private var adManager = AdManager.shared
    @State private var isHovering = false
    
    var body: some View {
        let ad = adManager.ad(for: slot)
        
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 8)
                .fill(ad.placeholderColor)
            
            if ad.isPlaceholder {
                // Default upgrade prompt ad
                VStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    
                    Text("Go Premium")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text("Remove ads")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            } else if let imageURL = ad.imageURL {
                // Dynamic ad image from server
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_):
                        // Fallback on load failure
                        defaultAdContent
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.8)
                    @unknown default:
                        defaultAdContent
                    }
                }
            } else {
                // No image URL - show default
                defaultAdContent
            }
            
            // Hover overlay
            if isHovering {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.15))
                
                if ad.isPlaceholder {
                    // Show "Click to upgrade" on hover
                    Text("Click to upgrade")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
            }
        }
        .aspectRatio(slot.aspectRatio, contentMode: .fit)
        .frame(width: slot.preferredSize.width, height: slot.preferredSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            if ad.isPlaceholder {
                // Open upgrade flow
                adManager.requestUpgrade()
            } else {
                // Open affiliate link and record click
                adManager.recordAdClick(ad)
                DynamicAdService.shared.recordClick(adId: ad.id.uuidString)
            }
        }
        .onAppear {
            adManager.recordAdImpression(ad)
            if !ad.isPlaceholder {
                DynamicAdService.shared.recordImpression(adId: ad.id.uuidString)
            }
        }
        .help(ad.isPlaceholder ? "Upgrade to Premium" : ad.advertiserName)
    }
    
    /// Default ad content for fallback
    private var defaultAdContent: some View {
        VStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            
            Text("Premium")
                .font(.caption2)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Portrait Ad Slot View (9:16)

/// Portrait-oriented ad slot for taller ads (Interstitial-style in sidebar)
struct PortraitAdSlotView: View {
    @ObservedObject private var adManager = AdManager.shared
    @State private var isHovering = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
            
            VStack(spacing: 4) {
                Image(systemName: "megaphone.fill")
                    .font(.title)
                    .foregroundStyle(.secondary)
                
                Text("Portrait Ad")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .aspectRatio(9.0/16.0, contentMode: .fit)
        .frame(width: 160, height: 284) // 9:16 ratio at 160 width
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Bottom Banner View

/// Full-width bottom banner ad
struct AdBannerView: View {
    let slot: AdSlot
    @ObservedObject private var adManager = AdManager.shared
    @State private var isHovering = false
    
    var body: some View {
        let ad = adManager.ad(for: slot)
        
        ZStack {
            // Background
            Rectangle()
                .fill(Color(nsColor: .windowBackgroundColor))
            
            if ad.isPlaceholder {
                // Default upgrade banner
                HStack(spacing: 16) {
                    Image(systemName: "star.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Upgrade to Divine Link Premium")
                            .font(.callout)
                            .fontWeight(.medium)
                        
                        Text("Remove ads and support development")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        adManager.requestUpgrade()
                    } label: {
                        Text("Go Premium")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
                }
                .padding(.horizontal, 20)
            } else if let imageURL = ad.imageURL {
                // Dynamic banner ad
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_):
                        defaultBannerContent
                    case .empty:
                        defaultBannerContent
                    @unknown default:
                        defaultBannerContent
                    }
                }
                .onTapGesture {
                    if let clickURL = ad.clickURL {
                        NSWorkspace.shared.open(clickURL)
                        DynamicAdService.shared.recordClick(adId: ad.id.uuidString)
                    }
                }
            } else {
                defaultBannerContent
            }
        }
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1),
            alignment: .top
        )
        .onAppear {
            adManager.recordAdImpression(ad)
            if !ad.isPlaceholder {
                DynamicAdService.shared.recordImpression(adId: ad.id.uuidString)
            }
        }
        .sheet(isPresented: $adManager.showPaywall) {
            PaywallView()
        }
    }
    
    /// Default banner content
    private var defaultBannerContent: some View {
        HStack(spacing: 16) {
            Image(systemName: "star.circle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            
            Text("Upgrade to Premium for an ad-free experience")
                .font(.callout)
            
            Spacer()
            
            Button("Upgrade") {
                adManager.requestUpgrade()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Upgrade Button

/// Button to upgrade to premium
struct UpgradeButton: View {
    @ObservedObject private var adManager = AdManager.shared
    
    var body: some View {
        Button {
            adManager.requestUpgrade() // Shows paywall instead of instant upgrade
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .font(.caption)
                Text("Remove Ads")
                    .font(.caption2)
            }
            .foregroundStyle(.orange)
        }
        .buttonStyle(.plain)
        .help("Upgrade to Premium to remove all ads")
        .sheet(isPresented: $adManager.showPaywall) {
            PaywallView()
        }
    }
}

// MARK: - Paywall View

/// Full paywall shown when user wants to upgrade
struct PaywallView: View {
    @ObservedObject private var adManager = AdManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)
                
                Text("Divine Link Premium")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Remove ads and support development")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            
            // Benefits
            VStack(alignment: .leading, spacing: 12) {
                BenefitRow(icon: "xmark.circle.fill", text: "No advertisements", color: .green)
                BenefitRow(icon: "bolt.fill", text: "Cleaner interface", color: .orange)
                BenefitRow(icon: "heart.fill", text: "Support ongoing development", color: .pink)
                BenefitRow(icon: "arrow.clockwise", text: "Free updates forever", color: .blue)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Pricing
            VStack(spacing: 8) {
                Text("£9.97/month")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Cancel anytime")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Purchase buttons
            VStack(spacing: 12) {
                Button {
                    adManager.purchasePremium()
                } label: {
                    HStack {
                        if adManager.isPurchasing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                        Text(adManager.isPurchasing ? "Processing..." : "Subscribe Now")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(adManager.isPurchasing)
                
                Button("Restore Purchases") {
                    adManager.restorePurchases()
                }
                .buttonStyle(.bordered)
                .disabled(adManager.isPurchasing)
                
                // Error message
                if let error = adManager.purchaseError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
            
            // Debug section (only in DEBUG builds)
            #if DEBUG
            VStack(spacing: 8) {
                Divider()
                
                Text("Debug Options")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Toggle("Enable Debug Mode", isOn: $adManager.debugModeEnabled)
                    .font(.caption)
                
                if adManager.debugModeEnabled {
                    Button("DEBUG: Instant Upgrade") {
                        adManager.debugUpgrade()
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                    .font(.caption)
                }
            }
            .padding(.horizontal)
            #endif
            
            // Close button
            Button("Not Now") {
                dismiss()
            }
            .foregroundStyle(.secondary)
            .padding(.bottom)
        }
        .padding()
        .frame(width: 380, height: 580)
    }
}

// MARK: - Benefit Row

struct BenefitRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 24)
            
            Text(text)
                .font(.callout)
        }
    }
}

// MARK: - Subscription Settings View

/// View for managing subscription in Settings
struct SubscriptionSettingsView: View {
    @ObservedObject private var adManager = AdManager.shared
    
    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Plan")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text(adManager.subscriptionStatus.displayName)
                            .font(.headline)
                            .foregroundStyle(adManager.subscriptionStatus == .premium ? .orange : .primary)
                    }
                    
                    Spacer()
                    
                    if adManager.subscriptionStatus != .premium {
                        Button("Upgrade") {
                            adManager.requestUpgrade()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                    }
                }
            } header: {
                Text("Subscription")
            }
            
            if adManager.subscriptionStatus != .premium {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(icon: "xmark.circle.fill", text: "No advertisements", color: .orange)
                        FeatureRow(icon: "bolt.fill", text: "Priority support", color: .orange)
                        FeatureRow(icon: "heart.fill", text: "Support development", color: .orange)
                    }
                } header: {
                    Text("Premium Benefits")
                }
            }
            
            Section {
                Button("Restore Purchases") {
                    adManager.restorePurchases()
                }
                .buttonStyle(.bordered)
                .disabled(adManager.isPurchasing)
                
                if adManager.subscriptionStatus == .premium {
                    Button("Reset to Free (Testing)") {
                        adManager.resetToFree()
                    }
                    .foregroundStyle(.red)
                }
            }
            
            #if DEBUG
            Section {
                Toggle("Debug Mode", isOn: $adManager.debugModeEnabled)
                
                if adManager.debugModeEnabled {
                    Button("Debug: Set Premium") {
                        adManager.debugUpgrade()
                    }
                    .foregroundStyle(.purple)
                    
                    Button("Debug: Reset to Free") {
                        adManager.resetToFree()
                    }
                    .foregroundStyle(.red)
                }
            } header: {
                Text("Developer Options")
            }
            #endif
        }
        .formStyle(.grouped)
        .sheet(isPresented: $adManager.showPaywall) {
            PaywallView()
        }
    }
}

// MARK: - Feature Row (small version for settings)

struct FeatureRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            
            Text(text)
                .font(.callout)
        }
    }
}

// MARK: - Previews

#Preview("Ad Sidebar") {
    HStack {
        Text("Main Content")
            .frame(width: 400, height: 500)
            .background(Color.blue.opacity(0.1))
        
        AdSidebarView()
            .frame(width: 180)
    }
}

#Preview("Ad Banner") {
    AdBannerView(slot: .bottomBanner)
        .frame(height: 70)
}

#Preview("Subscription Settings") {
    SubscriptionSettingsView()
        .frame(width: 400, height: 300)
}
