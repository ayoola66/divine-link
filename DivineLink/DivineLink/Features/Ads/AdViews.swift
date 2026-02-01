import SwiftUI
import AVKit
import AVFoundation
import WebKit

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
            
            // Bottom banner - always show if banner ad is available
            // This ensures banner ads are displayed when available, regardless of subscription status
            if adManager.bottomBannerHeight > 0 {
                AdBannerView(slot: .bottomBanner)
                    .frame(height: adManager.bottomBannerHeight)
            }
        }
    }
}

// MARK: - Ad Sidebar View

/// Right sidebar containing stacked ad slots - dynamically adapts based on available ads and window size
/// Layout rules:
/// - Default: 3 squares OR 1 square + 1 portrait (2 ads total)
/// - If window stretched and space allows: 2 squares + 1 portrait (3 ads total)
/// - Portrait ad always prioritised when available
/// - Enforced ads always show in their designated slots
struct AdSidebarView: View {
    @ObservedObject private var adManager = AdManager.shared
    @ObservedObject private var adService = DynamicAdService.shared
    
    /// Get unique square ads (no duplicates)
    private var squareAds: [DynamicAd] {
        adService.ads(for: .square)
    }
    
    /// Get portrait ad if available
    private var portraitAd: DynamicAd? {
        adService.portraitAd
    }
    
    /// Determine the layout based on available ads and available space
    private func layout(availableHeight: CGFloat) -> SidebarLayout {
        let squares = squareAds.count
        let hasPortrait = portraitAd != nil
        
        // Estimate heights: square ~133px, portrait ~200px, spacing ~8px each, button ~50px
        let squareHeight: CGFloat = 133
        let portraitHeight: CGFloat = 200
        let spacing: CGFloat = 8
        let buttonHeight: CGFloat = 50
        let padding: CGFloat = 20 // Top and bottom padding
        
        // Calculate if we have space for 2 squares + 1 portrait
        let heightForThreeAds = (squareHeight * 2) + portraitHeight + (spacing * 3) + buttonHeight + padding
        let canFitThreeAds = availableHeight >= heightForThreeAds
        
        // Priority 1: If portrait available and we have space, show 2 squares + 1 portrait
        if hasPortrait && canFitThreeAds && squares >= 2 {
            return .twoSquaresOnePortrait
        }
        
        // Priority 2: Default - 3 squares if available
        if squares >= 3 {
            return .threeSquares
        }
        
        // Priority 3: If portrait available, show 1 square + 1 portrait (default)
        if hasPortrait && squares >= 1 {
            return .oneSquareOnePortrait
        }
        
        // Priority 4: If portrait available but no squares, show portrait + placeholder
        if hasPortrait {
            return .portraitOnly
        }
        
        // Priority 5: Show squares + portrait placeholder
        if squares >= 3 {
            return .threeSquares
        } else if squares >= 1 {
            return .squaresWithPortraitPlaceholder(squareCount: squares)
        } else {
            return .squaresWithPortraitPlaceholder(squareCount: 1)
        }
    }
    
    enum SidebarLayout {
        case threeSquares
        case twoSquaresOnePortrait  // New: 2 squares + 1 portrait (when space allows)
        case oneSquareOnePortrait   // Default: 1 square + 1 portrait
        case portraitOnly           // Portrait only (no squares available)
        case squaresWithPortrait(squareCount: Int)
        case squaresWithPortraitPlaceholder(squareCount: Int)
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 8) {
                let currentLayout = layout(availableHeight: geometry.size.height)
                
                switch currentLayout {
                case .threeSquares:
                    // Show up to 3 square ads (default when no portrait)
                    ForEach(Array(squareAds.prefix(3).enumerated()), id: \.element.id) { _, ad in
                        SingleAdView(ad: ad)
                    }
                    
                case .twoSquaresOnePortrait:
                    // Show 2 squares + 1 portrait (when window stretched and space allows)
                    ForEach(Array(squareAds.prefix(2).enumerated()), id: \.element.id) { _, ad in
                        SingleAdView(ad: ad)
                    }
                    // Show portrait ad
                    if let portrait = portraitAd {
                        SingleAdView(ad: portrait)
                    }
                    
                case .oneSquareOnePortrait:
                    // Default: 1 square + 1 portrait
                    if let firstSquare = squareAds.first {
                        SingleAdView(ad: firstSquare)
                    } else {
                        AdPlaceholderView(format: .square)
                    }
                    // Show portrait ad
                    if let portrait = portraitAd {
                        SingleAdView(ad: portrait)
                    }
                    
                case .portraitOnly:
                    // Portrait only (no squares available)
                    if let portrait = portraitAd {
                        SingleAdView(ad: portrait)
                    }
                    AdPlaceholderView(format: .square)
                    
                case .squaresWithPortrait(let squareCount):
                    // Show square ads
                    ForEach(Array(squareAds.prefix(squareCount).enumerated()), id: \.element.id) { _, ad in
                        SingleAdView(ad: ad)
                    }
                    // Show square placeholder if no squares
                    if squareCount == 0 {
                        AdPlaceholderView(format: .square)
                    }
                    // Show portrait ad
                    if let portrait = portraitAd {
                        SingleAdView(ad: portrait)
                    }
                    
                case .squaresWithPortraitPlaceholder(let squareCount):
                    // Show square ads or placeholder
                    if squareCount > 0 {
                        ForEach(Array(squareAds.prefix(squareCount).enumerated()), id: \.element.id) { _, ad in
                            SingleAdView(ad: ad)
                        }
                    } else {
                        AdPlaceholderView(format: .square)
                    }
                    // Show portrait placeholder
                    PortraitPlaceholderView()
                }
            
                Spacer(minLength: 8)
                
                // Upgrade button - blue background, white text - ALWAYS visible
                Button {
                    adManager.requestUpgrade()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                        Text("Remove Ads")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
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
}

// MARK: - Single Ad View (no duplication)

/// Displays a single ad from the database with always-visible title and video/GIF support
struct SingleAdView: View {
    let ad: DynamicAd
    @ObservedObject private var adService = DynamicAdService.shared
    @State private var isHovering = false
    @State private var player: AVPlayer?
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
            
            // Media content (video/GIF takes priority over image)
            if ad.hasVideo, let videoURL = ad.videoURL {
                // Video or GIF content (looping)
                VideoPlayerView(url: videoURL, isGIF: ad.mediaType == "gif")
            } else if let imageURL = ad.imageURL {
                // Static image
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        placeholderContent
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.7)
                    @unknown default:
                        placeholderContent
                    }
                }
            } else {
                placeholderContent
            }
            
            // Always-visible title overlay (transparent background, white text)
            VStack {
                Spacer()
                HStack {
                    Text(ad.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.black.opacity(0.7),
                                    Color.black.opacity(0.5)
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                }
            }
            
            // Hover overlay
            if isHovering {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.1))
            }
        }
        .aspectRatio(ad.adFormat.aspectRatio, contentMode: .fit)
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
            if let url = ad.clickURL {
                NSWorkspace.shared.open(url)
                adService.recordClick(adId: ad.id)
            }
        }
        .onAppear {
            adService.recordImpression(adId: ad.id)
        }
        .help(ad.altText ?? ad.name)
    }
    
    private var placeholderContent: some View {
        VStack(spacing: 4) {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
            Text("Loading...")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Video Player View

/// Displays video or GIF content with looping support
/// Supports: Direct video URLs (MP4), YouTube URLs, and animated GIFs
struct VideoPlayerView: View {
    let url: URL
    let isGIF: Bool
    @State private var player: AVPlayer?
    
    /// Check if URL is a YouTube link (including Shorts)
    private var isYouTubeURL: Bool {
        let urlString = url.absoluteString.lowercased()
        return urlString.contains("youtube.com") || urlString.contains("youtu.be")
    }
    
    /// Extract YouTube video ID from URL
    private var youtubeVideoID: String? {
        guard isYouTubeURL else { return nil }
        let urlString = url.absoluteString
        
        // Handle youtu.be short links
        if urlString.contains("youtu.be/") {
            let components = urlString.components(separatedBy: "youtu.be/")
            if components.count > 1 {
                return components[1].components(separatedBy: "?")[0].components(separatedBy: "&")[0]
            }
        }
        
        // Handle YouTube Shorts: youtube.com/shorts/VIDEO_ID
        if urlString.contains("/shorts/") {
            let components = urlString.components(separatedBy: "/shorts/")
            if components.count > 1 {
                return components[1].components(separatedBy: "?")[0].components(separatedBy: "&")[0].components(separatedBy: "#")[0]
            }
        }
        
        // Handle youtube.com/watch?v= links
        if urlString.contains("watch?v=") {
            let components = urlString.components(separatedBy: "watch?v=")
            if components.count > 1 {
                return components[1].components(separatedBy: "&")[0].components(separatedBy: "#")[0]
            }
        }
        
        // Handle youtube.com/embed/ links
        if urlString.contains("embed/") {
            let components = urlString.components(separatedBy: "embed/")
            if components.count > 1 {
                return components[1].components(separatedBy: "?")[0].components(separatedBy: "&")[0]
            }
        }
        
        return nil
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isGIF {
                    // Use WebKit for GIFs (better support for animated GIFs)
                    GIFWebView(url: url)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else if isYouTubeURL, let videoID = youtubeVideoID {
                    // Use WebKit for YouTube videos (embed format)
                    YouTubeWebView(videoID: videoID)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    // Use AVPlayer for direct video URLs (MP4, etc.)
                    if let player = player {
                        VideoPlayer(player: player)
                            .disabled(true) // Disable controls for ads
                    } else {
                        ProgressView()
                            .scaleEffect(0.7)
                            .onAppear {
                                setupVideoPlayer()
                            }
                    }
                }
            }
        }
        .onAppear {
            if !isGIF && !isYouTubeURL {
                setupVideoPlayer()
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
    
    private func setupVideoPlayer() {
        guard player == nil else { return }
        
        player = AVPlayer(url: url)
        player?.isMuted = true // Mute by default for ads
        player?.actionAtItemEnd = .none
        
        // Loop the video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }
        
        player?.play()
    }
}

// MARK: - GIF Web View

/// Displays animated GIFs using WebKit
struct GIFWebView: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> WKWebView {
        // IMPORTANT: Configuration MUST be set BEFORE creating WKWebView
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true  // Enable JS for some GIF hosts
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // Load GIF using HTML to ensure it displays and loops
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * { margin: 0; padding: 0; }
                html, body { width: 100%; height: 100%; overflow: hidden; background: transparent; }
                img { width: 100%; height: 100%; object-fit: cover; }
            </style>
        </head>
        <body>
            <img src="\(url.absoluteString)" alt="GIF" />
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: url)
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Update if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { }
    }
}

// MARK: - YouTube Web View

/// Displays YouTube videos using WebKit embed with HTML injection
/// This approach works better on macOS than loading embed URL directly
struct YouTubeWebView: NSViewRepresentable {
    let videoID: String
    
    func makeNSView(context: Context) -> WKWebView {
        // IMPORTANT: Configuration MUST be set BEFORE creating WKWebView
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // Load HTML with embedded iframe - using youtube-nocookie for privacy and better compatibility
        // Note: YouTube Shorts work with the same /embed/ URL format using the video ID
        // Parameters to minimize branding: modestbranding=1, controls=0, showinfo=0, iv_load_policy=3 (hide annotations)
        let embedURL = "https://www.youtube-nocookie.com/embed/\(videoID)?autoplay=1&loop=1&playlist=\(videoID)&mute=1&controls=0&modestbranding=1&playsinline=1&rel=0&fs=0&disablekb=1&showinfo=0&iv_load_policy=3&cc_load_policy=0&origin=https://divinelink.app"
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body { width: 100%; height: 100%; overflow: hidden; background: #000; }
                iframe { 
                    position: absolute; 
                    top: 0; left: 0; 
                    width: 100%; height: 100%; 
                    border: none;
                }
            </style>
        </head>
        <body>
            <iframe 
                id="ytplayer"
                src="\(embedURL)"
                frameborder="0"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                referrerpolicy="strict-origin-when-cross-origin"
                allowfullscreen>
            </iframe>
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: URL(string: "https://divinelink.app"))
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Update if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { }
    }
}

// MARK: - Ad Placeholder View

/// Placeholder for empty ad slots - "Ad Space Available"
struct AdPlaceholderView: View {
    var format: AdFormat = .square
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                )
            
            VStack(spacing: 6) {
                Image(systemName: "rectangle.dashed")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Ad Space")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Text("Available")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .aspectRatio(format.aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Portrait Placeholder View

/// Tall portrait placeholder for empty portrait ad slot
struct PortraitPlaceholderView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                )
            
            VStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.dashed")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Portrait Ad")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Text("Space Available")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .aspectRatio(9.0/16.0, contentMode: .fit)
        .frame(maxHeight: 200)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
    @ObservedObject private var adService = DynamicAdService.shared
    @State private var isHovering = false
    
    /// Get the banner ad if available
    private var bannerAd: DynamicAd? {
        adService.bannerAd
    }
    
    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color(nsColor: .windowBackgroundColor))
            
            // CRITICAL: Always show banner ad if available, regardless of subscription status
            // This ensures banner ads are displayed when available
            if let banner = bannerAd {
                ZStack {
                    // Media content (video/GIF takes priority)
                    if banner.hasVideo, let videoURL = banner.videoURL {
                        VideoPlayerView(url: videoURL, isGIF: banner.mediaType == "gif")
                            .frame(maxWidth: .infinity)
                    } else if let imageURL = banner.imageURL {
                        // Static image
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                            case .failure(_):
                                bannerPlaceholder
                            case .empty:
                                ProgressView()
                            @unknown default:
                                bannerPlaceholder
                            }
                        }
                    } else {
                        bannerPlaceholder
                    }
                    
                    // Always-visible title overlay for banner
                    VStack {
                        Spacer()
                        HStack {
                            Text(banner.name)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.black.opacity(0.7),
                                            Color.black.opacity(0.5)
                                        ]),
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if let clickURL = banner.clickURL {
                        NSWorkspace.shared.open(clickURL)
                        adService.recordClick(adId: banner.id)
                    }
                }
                .onAppear {
                    adService.recordImpression(adId: banner.id)
                }
                .help(banner.altText ?? banner.name)
            } else {
                // No banner ad - show placeholder only if ads should be shown
                if AdManager.shared.shouldShowAds {
                    bannerPlaceholder
                }
            }
            
            // Hover effect
            if isHovering && bannerAd != nil {
                Rectangle()
                    .fill(Color.black.opacity(0.05))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 80)
        .onHover { hovering in
            isHovering = hovering
        }
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1),
            alignment: .top
        )
    }
    
    /// Placeholder when no banner ad is available
    private var bannerPlaceholder: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.dashed")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Banner Ad Space")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Text("Available for advertising")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
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
