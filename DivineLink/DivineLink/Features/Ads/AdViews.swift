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
            
            // Bottom banner - only show for free users
            if adManager.shouldShowAds && adManager.bottomBannerHeight > 0 {
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

            // Transparent click layer ON TOP of the media so the whole ad is clickable and
            // the tap ALWAYS opens the advertiser's landing page — even over a WKWebView
            // (YouTube/GIF) or AVPlayer, which would otherwise swallow the tap (and, for a
            // YouTube embed, navigate inside the video instead of opening the click URL —
            // the "clicking shows the hyperlink instead of playing" symptom).
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    if let url = ad.clickURL {
                        NSWorkspace.shared.open(url)
                        adService.recordClick(adId: ad.id)
                    }
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
        player?.automaticallyWaitsToMinimizeStalling = false // start ASAP for a short looping ad
        
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
        
        // Use the YouTube IFrame Player API rather than a bare autoplay iframe. The API's
        // onReady callback lets us explicitly mute() + playVideo(), which starts playback
        // reliably on WebKit versions (notably older Intel macOS) where the `autoplay=1`
        // attribute alone is silently blocked — the reason the ad autoplayed on Apple
        // Silicon but not on Intel. Muted playback satisfies WebKit's autoplay policy.
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body { width: 100%; height: 100%; overflow: hidden; background: #000; }
                #player { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
            </style>
        </head>
        <body>
            <div id="player"></div>
            <script src="https://www.youtube.com/iframe_api"></script>
            <script>
                var ytPlayer;
                function onYouTubeIframeAPIReady() {
                    ytPlayer = new YT.Player('player', {
                        videoId: '\(videoID)',
                        host: 'https://www.youtube-nocookie.com',
                        playerVars: {
                            autoplay: 1, mute: 1, controls: 0, loop: 1, playlist: '\(videoID)',
                            modestbranding: 1, playsinline: 1, rel: 0, fs: 0,
                            disablekb: 1, iv_load_policy: 3, cc_load_policy: 0
                        },
                        events: {
                            onReady: function (e) { e.target.mute(); e.target.playVideo(); },
                            onStateChange: function (e) {
                                if (e.data === YT.PlayerState.ENDED) { ytPlayer.seekTo(0); ytPlayer.playVideo(); }
                                // If autoplay was throttled, nudge it again once the API is live.
                                if (e.data === YT.PlayerState.CUED) { ytPlayer.mute(); ytPlayer.playVideo(); }
                            }
                        }
                    });
                }
            </script>
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
            
            // Show banner ad if available (container already checks shouldShowAds)
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

/// Full paywall shown when user wants to upgrade - Modern redesign with tier benefits
struct PaywallView: View {
    @ObservedObject private var adManager = AdManager.shared
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringSubscribe = false
    @State private var selectedTier: SubscriptionTier = .grace
    @State private var selectedPlan: PremiumPlan = .monthly
    
    /// Show debug options for DEBUG builds or admin users
    private var showDebugOptions: Bool {
        #if DEBUG
        return true
        #else
        return subscriptionService.isAdmin
        #endif
    }
    
    enum PremiumPlan: String, CaseIterable {
        case monthly = "Monthly"
        case yearly = "Yearly"
        
        func price(for tier: SubscriptionTier) -> String {
            switch (tier, self) {
            case (.grace, .monthly): return "£9.99"
            case (.grace, .yearly): return "£79.99"
            case (.love, .monthly): return "£19.99"
            case (.love, .yearly): return "£149.99"
            case (.mercy, _): return "£0"
            }
        }
        
        var period: String {
            switch self {
            case .monthly: return "/month"
            case .yearly: return "/year"
            }
        }
        
        func savings(for tier: SubscriptionTier) -> String? {
            switch (tier, self) {
            case (.grace, .yearly): return "Save 33%"
            case (.love, .yearly): return "Save 37%"
            default: return nil
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient background
            VStack(spacing: 12) {
                // App icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange, Color.orange.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                }
                .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 4)
                
                VStack(spacing: 4) {
                    Text("Upgrade to Premium")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose Grace or Love tier")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.orange.opacity(0.1), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Benefits grid
            ScrollView {
                VStack(spacing: 16) {
                    // What you'll get section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What you'll get")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 10) {
                            PremiumBenefitCard(
                                icon: "xmark.circle.fill",
                                title: "Ad-Free",
                                description: "No distractions",
                                color: .green
                            )
                            
                            PremiumBenefitCard(
                                icon: "text.book.closed.fill",
                                title: "All Translations",
                                description: "KJV, ASV, WEB & more",
                                color: .blue
                            )
                            
                            PremiumBenefitCard(
                                icon: "infinity",
                                title: "Unlimited Sessions",
                                description: "No monthly limits",
                                color: .purple
                            )
                            
                            PremiumBenefitCard(
                                icon: "waveform.badge.mic",
                                title: "Smart Detection",
                                description: "Context-aware verses",
                                color: .orange
                            )
                            
                            PremiumBenefitCard(
                                icon: "tv.and.mediabox",
                                title: "Audience Output",
                                description: "Messages API support",
                                color: .teal
                            )
                            
                            PremiumBenefitCard(
                                icon: "person.2.fill",
                                title: "Pastor Profiles",
                                description: "Grace: 2 / Love: 5",
                                color: .pink
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Tier selection
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Choose Tier")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        HStack(spacing: 12) {
                            // Grace tier - selectable
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .foregroundStyle(.orange)
                                    Text("Grace")
                                        .fontWeight(.semibold)
                                }
                                .font(.callout)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    tierFeatureRow("2 Pastor profiles")
                                    tierFeatureRow("2 Devices")
                                    tierFeatureRow("All premium features")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(selectedTier == .grace ? Color.orange.opacity(0.2) : Color.orange.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedTier == .grace ? Color.orange : Color.clear, lineWidth: 2)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTier = .grace
                                }
                            }
                            
                            // Love tier - selectable
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "heart.circle.fill")
                                        .foregroundStyle(.pink)
                                    Text("Love")
                                        .fontWeight(.semibold)
                                }
                                .font(.callout)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    tierFeatureRow("5 Pastor profiles")
                                    tierFeatureRow("5 Devices")
                                    tierFeatureRow("Priority support")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(selectedTier == .love ? Color.pink.opacity(0.2) : Color.pink.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedTier == .love ? Color.pink : Color.clear, lineWidth: 2)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTier = .love
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Plan selector
                    VStack(spacing: 12) {
                        Text("Choose billing")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            ForEach(PremiumPlan.allCases, id: \.self) { plan in
                                PlanSelectionCard(
                                    plan: plan,
                                    tier: selectedTier,
                                    isSelected: selectedPlan == plan
                                )
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedPlan = plan
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(.vertical, 16)
            }
            
            // Bottom action area
            VStack(spacing: 12) {
                Divider()
                
                // Price display
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(selectedPlan.price(for: selectedTier))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(selectedPlan.period)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let savings = selectedPlan.savings(for: selectedTier) {
                        Text(savings)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 4)
                
                // Subscribe button
                Button {
                    let billingPeriod: SubscriptionService.BillingPeriod = selectedPlan == .monthly ? .monthly : .yearly
                    adManager.purchasePremium(tier: selectedTier, billingPeriod: billingPeriod)
                } label: {
                    HStack(spacing: 8) {
                        if adManager.isPurchasing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "crown.fill")
                        }
                        Text(adManager.isPurchasing ? "Opening Checkout..." : "Subscribe Now")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: selectedTier == .love 
                                ? [Color.pink, Color.pink.opacity(0.85)]
                                : [Color.orange, Color.orange.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(
                        color: selectedTier == .love 
                            ? Color.pink.opacity(0.3)
                            : Color.orange.opacity(0.3),
                        radius: 6, x: 0, y: 3
                    )
                }
                .buttonStyle(.plain)
                .scaleEffect(isHoveringSubscribe ? 1.02 : 1.0)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHoveringSubscribe = hovering
                    }
                }
                .disabled(adManager.isPurchasing)
                
                // Restore and close buttons
                HStack(spacing: 16) {
                    Button("Restore Purchase") {
                        adManager.restorePurchases()
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .disabled(adManager.isPurchasing)
                    
                    Text("•")
                        .foregroundStyle(.secondary.opacity(0.5))
                    
                    Button("Not Now") {
                        dismiss()
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                // Error message
                if let error = adManager.purchaseError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Security note
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                        .font(.caption2)
                    Text("Secure payment via Stripe")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary.opacity(0.7))
                
                // Debug section (DEBUG builds or admin users)
                if showDebugOptions {
                    VStack(spacing: 6) {
                        Divider()
                            .padding(.top, 4)
                        
                        Text("Debug Options")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            Toggle("Debug Mode", isOn: $adManager.debugModeEnabled)
                                .font(.caption2)
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                            
                            if adManager.debugModeEnabled {
                                Button("Instant Upgrade") {
                                    adManager.debugUpgrade()
                                }
                                .font(.caption2)
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .tint(.purple)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(.regularMaterial)
        }
        .frame(width: 420, height: 640)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func tierFeatureRow(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption2)
            Text(text)
        }
    }
}

// MARK: - Premium Benefit Card

private struct PremiumBenefitCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            Text(title)
                .font(.callout)
                .fontWeight(.semibold)
            
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Plan Selection Card

private struct PlanSelectionCard: View {
    let plan: PaywallView.PremiumPlan
    let tier: SubscriptionTier
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            if let savings = plan.savings(for: tier) {
                Text(savings)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green)
                    .clipShape(Capsule())
            } else {
                // Spacer for alignment
                Text(" ")
                    .font(.caption2)
                    .padding(.vertical, 3)
            }
            
            Text(plan.rawValue)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(plan.price(for: tier))
                    .font(.title3)
                    .fontWeight(.bold)
                Text(plan.period)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.orange.opacity(0.15) : Color.gray.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
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
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    
    /// Show debug options for DEBUG builds or admin users
    private var showDebugOptions: Bool {
        #if DEBUG
        return true
        #else
        return subscriptionService.isAdmin
        #endif
    }
    
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
            
            if showDebugOptions {
                Section {
                    Toggle("Debug Mode", isOn: $adManager.debugModeEnabled)
                    
                    if adManager.debugModeEnabled {
                        Button("Debug: Set Premium") {
                            SubscriptionService.shared.debugSimulateFreeMode = false
                            adManager.debugUpgrade()
                        }
                        .foregroundStyle(.purple)
                        
                        Button("Debug: Reset to Free") {
                            SubscriptionService.shared.debugSimulateFreeMode = true
                            adManager.resetToFree()
                        }
                        .foregroundStyle(.red)
                    }
                } header: {
                    Text("Developer Options")
                }
            }
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
