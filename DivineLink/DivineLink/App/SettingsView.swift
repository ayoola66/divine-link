import SwiftUI
import AVFoundation
import AppKit

// MARK: - Settings Window Resize Enabler (macOS Settings scene is not resizable by default)

private final class ResizeEnablerView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.styleMask.insert(.resizable)
    }
}

private struct SettingsWindowResizeEnabler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ResizeEnablerView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// Explicit selection for Settings tabs to ensure reliable switching on macOS
private enum SettingsTab: Hashable {
    case account
    case audio
    case detection
    case propresenter
    case pastors
    case display
    case bibleVersions
    case premium
    case updates
    case history
    case about
}

// MARK: - Resizable divider for sidebar (Audio MIDI Setup–style)

private let kSidebarWidthMin: CGFloat = 160
private let kSidebarWidthMax: CGFloat = 400
private let kSidebarWidthDefault: CGFloat = 220
private let kSidebarCollapsedWidth: CGFloat = 44

private struct ResizableDivider: View {
    @Binding var width: CGFloat
    var minWidth: CGFloat = kSidebarWidthMin
    var maxWidth: CGFloat = kSidebarWidthMax
    var isCollapsed: Bool
    var onDragExpand: () -> Void

    @State private var isDragging = false
    @State private var widthAtDragStart: CGFloat = 0
    @State private var expandedThisDrag = false

    var body: some View {
        Rectangle()
            .fill(isDragging ? Color.accentColor.opacity(0.3) : Color.clear)
            .frame(width: 6)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { NSCursor.resizeLeftRight.push() }
                else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        if isCollapsed {
                            if value.translation.width > 20, !expandedThisDrag {
                                expandedThisDrag = true
                                onDragExpand()
                                widthAtDragStart = kSidebarCollapsedWidth
                                width = min(maxWidth, max(minWidth, kSidebarCollapsedWidth + value.translation.width))
                            }
                            return
                        }
                        if !isDragging {
                            isDragging = true
                            widthAtDragStart = expandedThisDrag ? kSidebarCollapsedWidth : width
                        }
                        let newWidth = widthAtDragStart + value.translation.width
                        width = min(maxWidth, max(minWidth, newWidth))
                    }
                    .onEnded { _ in
                        isDragging = false
                        expandedThisDrag = false
                    }
            )
    }
}

/// Main settings view with sidebar navigation (Epic 7.1). Sidebar is resizable via drag and can be collapsed to icons-only.
struct SettingsView: View {
    @State private var selection: SettingsTab = .account
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @ObservedObject private var authService = AuthService.shared
    @AppStorage("settingsSidebarCollapsed") private var sidebarCollapsed = false
    @AppStorage("settingsSidebarWidth") private var sidebarWidth: Double = Double(kSidebarWidthDefault)

    private var effectiveSidebarWidth: CGFloat {
        if sidebarCollapsed { return kSidebarCollapsedWidth }
        return min(kSidebarWidthMax, max(kSidebarWidthMin, CGFloat(sidebarWidth)))
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar (resizable width when expanded)
            sidebarList
                .frame(width: effectiveSidebarWidth)
                .frame(minHeight: 0, maxHeight: .infinity)

            // Draggable divider: resize sidebar (or expand from collapsed when dragging right)
            ResizableDivider(
                width: Binding(
                    get: { CGFloat(sidebarWidth) },
                    set: { sidebarWidth = Double($0) }
                ),
                minWidth: kSidebarWidthMin,
                maxWidth: kSidebarWidthMax,
                isCollapsed: sidebarCollapsed,
                onDragExpand: { sidebarCollapsed = false }
            )
            .frame(minHeight: 0, maxHeight: .infinity)

            // Detail
            settingsDetailView
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        }
        .frame(
            minWidth: 680, idealWidth: 880, maxWidth: 1600,
            minHeight: 540, idealHeight: 600, maxHeight: .infinity
        )
        .background(SettingsWindowResizeEnabler())
    }

    /// Sidebar: when collapsed shows icons only; when expanded shows icons + labels and can be resized.
    private var sidebarList: some View {
        VStack(spacing: 0) {
            Group {
                if sidebarCollapsed {
                    sidebarListContent
                        .labelStyle(.iconOnly)
                } else {
                    sidebarListContent
                        .labelStyle(.titleAndIcon)
                }
            }
            .frame(minWidth: sidebarCollapsed ? kSidebarCollapsedWidth : kSidebarWidthMin,
                   maxWidth: sidebarCollapsed ? kSidebarCollapsedWidth : kSidebarWidthMax)

            Spacer(minLength: 0)

            // Collapse / expand button (collapses the sidebar itself to a narrow strip, not just labels)
            Button {
                sidebarCollapsed.toggle()
            } label: {
                Image(systemName: sidebarCollapsed ? "sidebar.leading" : "sidebar.trailing")
                    .symbolVariant(.fill)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)
            .help(sidebarCollapsed ? "Expand sidebar" : "Collapse sidebar to icons")
        }
        .background(.regularMaterial)
    }

    private var sidebarListContent: some View {
        List(selection: $selection) {
            Label("Account", systemImage: "person.circle")
                .tag(SettingsTab.account)
            Label("Audio", systemImage: "waveform")
                .tag(SettingsTab.audio)
            Label("Detection", systemImage: "waveform.badge.magnifyingglass")
                .tag(SettingsTab.detection)
            Label("ProPresenter", systemImage: "tv")
                .tag(SettingsTab.propresenter)
            Label("Pastors", systemImage: "person.2")
                .tag(SettingsTab.pastors)
            Label("Display", systemImage: "textformat.size")
                .tag(SettingsTab.display)
            Label("Bible Versions", systemImage: "books.vertical")
                .tag(SettingsTab.bibleVersions)
            // Admin tab: ONLY visible when authenticated AND user is admin.
            if authService.isAuthenticated && subscriptionService.isAdmin {
                Label("Admin", systemImage: "wrench.and.screwdriver")
                    .tag(SettingsTab.premium)
            }
            Label("Updates", systemImage: "arrow.down.circle")
                .tag(SettingsTab.updates)
            Label("History", systemImage: "clock.arrow.circlepath")
                .tag(SettingsTab.history)
            Label("About", systemImage: "info.circle")
                .tag(SettingsTab.about)
        }
        .listStyle(.sidebar)
    }

    private var settingsDetailView: some View {
        Group {
            switch selection {
            case .account: AccountSettingsTab()
            case .audio: AudioSettingsTab()
            case .detection: DetectionSettingsTab()
            case .propresenter: ProPresenterSettingsTab()
            case .pastors: PastorProfilesTab()
            case .display: AccessibilitySettingsTab()
            case .bibleVersions: BibleVersionsTab()
            case .premium: SubscriptionSettingsTab()
            case .updates: UpdatesSettingsTab()
            case .history: ServiceHistoryView()
            case .about: AboutTab()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Audio Settings Tab

struct AudioSettingsTab: View {
    /// Use the shared AudioDeviceManager so device selection stays in sync
    /// with the main DetectionPipeline (previously created a separate instance).
    @ObservedObject private var audioManager = AudioDeviceManager.shared
    @StateObject private var audioTest = AudioCaptureService()
    @State private var isTesting = false
    // Enhanced-recognition (WhisperKit) on-demand model — manual entry / retry point.
    @ObservedObject private var whisperModel = WhisperModelManager.shared
    @State private var showModelDownload = false

    var body: some View {
        Form {
            // Enhanced Recognition (Apple Silicon only) — manual download / retry.
            if WhisperModelManager.isSupported {
                Section {
                    switch whisperModel.state {
                    case .installed:
                        Label("Enhanced recognition installed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case let .downloading(fraction, _, _):
                        HStack {
                            ProgressView(value: max(0, min(fraction, 1)))
                            Text("\(Int((max(0, min(fraction, 1)) * 100).rounded()))%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    default:
                        Button("Download Enhanced Recognition (~464 MB)") {
                            showModelDownload = true
                        }
                    }
                } header: {
                    Text("Enhanced Recognition")
                } footer: {
                    Text("An on-device AI speech model for more accurate, punctuated transcription. Downloads once, then works fully offline. Apple-Silicon Macs only.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Picker("Input Device", selection: $audioManager.selectedDevice) {
                    ForEach(audioManager.availableDevices, id: \.uniqueID) { device in
                        Text(device.friendlyName)
                            .tag(device as AVCaptureDevice?)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: audioManager.selectedDevice) { oldValue, newValue in
                    if let device = newValue {
                        Task {
                            await audioManager.selectDevice(device)
                            // Configure the test audio service with the selected device
                            let _ = audioTest.setInputDevice(device)
                            // Restart test if active
                            if isTesting {
                                audioTest.stop()
                                audioTest.start()
                            }
                        }
                    }
                }
                
                Button("Refresh Devices") {
                    Task {
                        await audioManager.refreshDevices()
                    }
                }
                .disabled(audioManager.isRefreshing)
            } header: {
                Text("Audio Input")
            } footer: {
                if audioManager.availableDevices.isEmpty {
                    Text("No audio input devices found.")
                        .foregroundStyle(.secondary)
                }
            }
            
            // Audio Level Test Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button(isTesting ? "Stop Test" : "Test Audio") {
                            if isTesting {
                                audioTest.stop()
                                isTesting = false
                            } else {
                                // Configure device before starting test
                                if let device = audioManager.selectedDevice {
                                    let _ = audioTest.setInputDevice(device)
                                }
                                audioTest.start()
                                // Only mark as testing if capture actually started
                                // (start() blocks if microphone permission is denied)
                                isTesting = audioTest.isCapturing
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isTesting ? .red : .blue)
                        
                        Spacer()
                        
                        if isTesting {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 8, height: 8)
                                    .opacity(audioTest.audioLevel > 0.05 ? 1.0 : 0.3)
                                Text("Listening")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if isTesting {
                        // Audio level bar
                        VStack(alignment: .leading, spacing: 4) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    // Background
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                    
                                    // Level bar
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(levelColor)
                                        .frame(width: max(4, geo.size.width * CGFloat(audioTest.audioLevel)))
                                        .animation(.easeOut(duration: 0.1), value: audioTest.audioLevel)
                                }
                            }
                            .frame(height: 20)
                            
                            Text("Speak or make noise to test the microphone")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let error = audioTest.error {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error.localizedDescription)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    
                    if let message = audioTest.fallbackToDefaultDeviceMessage {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Audio Level Test")
            }
            
            Section {
                if audioManager.isBlackHoleInstalled {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("BlackHole is installed")
                            .foregroundStyle(.secondary)
                    }
                    
                    if !audioManager.blackHoleDevices.isEmpty {
                        Text("Available: \(audioManager.blackHoleDevices.map { $0.friendlyName }.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text("BlackHole not detected")
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("Only needed if you want to capture audio from another app on this Mac (e.g., ProPresenter or a media player). A physical microphone or audio interface works without it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Link(destination: AudioDeviceManager.blackHoleURL) {
                            HStack {
                                Image(systemName: "arrow.up.right.square")
                                Text("Install BlackHole")
                            }
                        }
                        .font(.caption)
                    }
                }
            } header: {
                Text("System Audio Capture")
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showModelDownload) {
            WhisperDownloadView(
                manager: whisperModel,
                onUseStandard: { showModelDownload = false },
                onClose: { showModelDownload = false }
            )
        }
        .onDisappear {
            // Stop testing when leaving the tab
            if isTesting {
                audioTest.stop()
            }
        }
    }
    
    private var levelColor: Color {
        if audioTest.audioLevel < 0.6 {
            return .green
        } else if audioTest.audioLevel < 0.85 {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - Detection Settings Tab

struct DetectionSettingsTab: View {
    @ObservedObject private var settings = DetectionSettings.shared
    @ObservedObject private var referenceBuffer = ReferenceBuffer.shared
    @State private var contextTimeoutMinutes: Double = 5.0
    
    var body: some View {
        Form {
            // Reference Buffer Section (NEW - Epic 7.1)
            Section {
                Toggle("Enable Context Buffer", isOn: Binding(
                    get: { referenceBuffer.isEnabled },
                    set: { referenceBuffer.isEnabled = $0 }
                ))
                
                if referenceBuffer.isEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Context Timeout")
                            .font(.subheadline)
                        
                        HStack {
                            Slider(
                                value: $contextTimeoutMinutes,
                                in: 1...15,
                                step: 1
                            )
                            .onChange(of: contextTimeoutMinutes) { _, newValue in
                                referenceBuffer.contextTimeout = newValue * 60
                            }
                            
                            Text("\(Int(contextTimeoutMinutes)) min")
                                .font(.caption)
                                .monospacedDigit()
                                .frame(width: 50, alignment: .trailing)
                        }
                        
                        Text("How long context remains active after a scripture detection.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                    
                    // Current Context Status
                    if referenceBuffer.hasContext {
                        if let context = referenceBuffer.getValidContext() {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                let verseInfo = context.verseStart.map { v in
                                    context.verseEnd.map { ":\(v)-\($0)" } ?? ":\(v)"
                                } ?? ""
                                Text("Active: \(context.book) \(context.chapter)\(verseInfo)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    } else {
                        HStack {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                            Text("No active context")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
            } header: {
                Text("Smart Context Detection")
            } footer: {
                Text("When enabled, partial references like \"verse 18\" or \"the next verse\" will be resolved using the last detected scripture context (e.g., \"John 3:17\" for \"next verse\" if \"John 3:16\" was recently detected).")
            }
            
            // Confidence Indicators Section
            Section {
                Toggle("Show Confidence Indicators", isOn: $settings.showConfidenceIndicators)
                
                if settings.showConfidenceIndicators {
                    Toggle("Show Detailed Breakdown on Hover", isOn: $settings.showConfidenceBreakdown)
                }
            } header: {
                Text("Confidence Display")
            } footer: {
                Text("Confidence indicators show how certain the AI is about each scripture detection.")
            }
            
            // Low Confidence Handling Section
            Section {
                Toggle("Hold Low-Confidence Detections", isOn: $settings.autoHoldLowConfidence)
                
                if settings.autoHoldLowConfidence {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Low Confidence Threshold")
                            .font(.subheadline)
                        
                        HStack {
                            Slider(
                                value: $settings.lowConfidenceThreshold,
                                in: 0.50...0.90,
                                step: 0.05
                            )
                            
                            Text("\(Int(settings.lowConfidenceThreshold * 100))%")
                                .font(.caption)
                                .monospacedDigit()
                                .frame(width: 40, alignment: .trailing)
                        }
                        
                        Text("Detections below this threshold will require manual approval before being sent to ProPresenter.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                    
                    Toggle("Play Sound for Low Confidence", isOn: $settings.soundOnLowConfidence)
                }
            } header: {
                Text("Low Confidence Handling")
            } footer: {
                if settings.autoHoldLowConfidence {
                    Text("Low-confidence detections will be highlighted in orange and held for your review.")
                } else {
                    Text("All detections will be processed automatically regardless of confidence level.")
                }
            }
            
            // Preview Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Confidence Level Preview")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 16) {
                        ConfidencePreviewItem(level: .high, threshold: settings.lowConfidenceThreshold)
                        ConfidencePreviewItem(level: .medium, threshold: settings.lowConfidenceThreshold)
                        ConfidencePreviewItem(level: .low, threshold: settings.lowConfidenceThreshold)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Preview")
            }
            
            // Reset Section
            Section {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                    referenceBuffer.isEnabled = true
                    referenceBuffer.contextTimeout = 300
                    contextTimeoutMinutes = 5.0
                }
                .buttonStyle(.bordered)
            }
        }
        .formStyle(.grouped)
        .padding()
        .premiumGated(featureName: "Detection Settings")
        .onAppear {
            // Load current timeout in minutes
            contextTimeoutMinutes = referenceBuffer.contextTimeout / 60
        }
    }
}

/// Preview item for confidence level display
private struct ConfidencePreviewItem: View {
    let level: ConfidenceLevel
    let threshold: Double
    
    private var isLow: Bool {
        level == .low || (level == .medium && threshold > 0.75)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: level.icon)
                .font(.title2)
                .foregroundColor(level.colour)
            
            Text(level.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(level.colour)
            
            if isLow {
                Text("Held")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .clipShape(Capsule())
            } else {
                Text("Auto")
                    .font(.caption2)
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - ProPresenter Settings Tab

struct ProPresenterSettingsTab: View {
    @StateObject private var settings = ProPresenterSettings()
    @StateObject private var client = ProPresenterClient()
    @ObservedObject private var panicService = PanicButtonService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProPresenterSettingsView(settings: settings, client: client)
                
                Divider()
                
                // Panic Button Settings
                PanicButtonSettingsSection(service: panicService)
                    .padding(.horizontal)
                
                Divider()
                
                // Help section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Setup Instructions")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Open ProPresenter → Preferences → Network")
                        Text("2. Enable \"Enable Network\" toggle")
                        Text("3. Note the Port (default is 50233)")
                        Text("4. Use 127.0.0.1 if on the same Mac")
                        Text("5. Click \"Test Connection\" to verify")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
        }
    }
}

// MARK: - Bible Versions Tab

/// Manage Bible translations: shows bundled versions and lets premium users download / delete the
/// extra premium versions (YouVersion-style: progress %, green ✓, delete). Free users see the
/// premium versions locked with an upgrade hint.
struct BibleVersionsTab: View {
    @ObservedObject private var manager = BibleVersionManager.shared
    @ObservedObject private var subscription = SubscriptionService.shared
    @ObservedObject private var auth = AuthService.shared

    private var isPremium: Bool { subscription.isPremium || subscription.isAdmin }
    /// Registered = signed in with an email (unlocks BSB/LSV free), or already premium.
    private var isRegistered: Bool { auth.isAuthenticated || isPremium }

    var body: some View {
        Form {
            Section {
                ForEach(BibleVersionManager.bundledVersions) { v in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(v.name)
                            Text(v.id).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        // v.isPremium here means the REGISTERED-tier reward (BSB/LSV): free, but
                        // requires signing in with an email. KJV/WEB/ASV are always included.
                        if v.isPremium && !isRegistered {
                            Label("Sign in — free", systemImage: "person.crop.circle.badge.plus")
                                .font(.caption).foregroundStyle(.blue)
                        } else {
                            Label("Included", systemImage: "checkmark.circle.fill")
                                .font(.caption).foregroundStyle(.green)
                        }
                    }
                }
            } header: {
                Text("Included with the app")
            } footer: {
                if !isRegistered {
                    Text("Register a free account to unlock 2 more versions (Berean Standard Bible and Literal Standard Version) — no payment needed.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(manager.catalog) { v in
                    versionRow(v)
                }
                if manager.catalog.isEmpty {
                    Text("No additional versions available.").foregroundStyle(.secondary)
                }
            } header: {
                Text("Premium — downloadable")
            } footer: {
                Text("On-device once downloaded; works offline. Manage storage by deleting versions you don't use.")
                    .foregroundStyle(.secondary)
            }

            Section("Attributions") {
                ForEach(attributions, id: \.self) { credit in
                    Text(credit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .task { await manager.refreshCatalog() }
    }

    /// All required credit lines: bundled (BSB/LSV) + any downloadable version that asks for one.
    private var attributions: [String] {
        var credits = BibleVersionManager.bundledAttributions
        for v in manager.catalog where v.requiresAttribution || (v.attributionText?.isEmpty == false) {
            if let t = v.attributionText, !t.isEmpty { credits.append(t) }
        }
        return credits
    }

    @ViewBuilder
    private func versionRow(_ v: BibleVersionManager.CatalogVersion) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(v.name)
                Text("\(v.id) · \(v.year > 0 ? String(v.year) : "")").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()

            switch manager.state(for: v.id) {
            case .installed:
                Label("Installed", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.green)
                Button(role: .destructive) { manager.delete(v.id) } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete this version")

            case let .downloading(fraction):
                HStack(spacing: 6) {
                    ProgressView(value: fraction).frame(width: 80)
                    Text("\(Int(fraction * 100))%").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }

            case .failed(let msg):
                if isPremium {
                    Button("Retry") { Task { await manager.download(v.id) } }.buttonStyle(.borderless)
                }
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).help(msg)

            case .notInstalled:
                if isPremium {
                    Button("Download") { Task { await manager.download(v.id) } }
                        .buttonStyle(.borderless)
                } else {
                    Label("Premium", systemImage: "lock.fill")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
        }
    }
}

// MARK: - Subscription Settings Tab

struct SubscriptionSettingsTab: View {
    var body: some View {
        SubscriptionSettingsView()
            .padding()
    }
}

// MARK: - Updates Settings Tab

struct UpdatesSettingsTab: View {
    var body: some View {
        UpdateSettingsView()
            .padding()
    }
}

// MARK: - Account Settings Tab

struct AccountSettingsTab: View {
    @ObservedObject private var authService = AuthService.shared
    @State private var showLoginSheet = false
    
    var body: some View {
        if authService.isAuthenticated {
            AccountView()
        } else {
            VStack(spacing: 20) {
                Image(systemName: "person.circle")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                
                Text("Sign In to Divine Link")
                    .font(.title2.bold())
                
                Text("Create an account to access premium features, sync across devices, and manage your subscription.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Sign In") {
                    showLoginSheet = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding()
            .sheet(isPresented: $showLoginSheet) {
                LoginView()
            }
        }
    }
}

// MARK: - Accessibility Settings Tab

struct AccessibilitySettingsTab: View {
    @ObservedObject private var settings = AccessibilitySettings.shared
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Font Size")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        Text("A")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        
                        Slider(
                            value: Binding(
                                get: { Double(settings.fontScaleLevel) },
                                set: { settings.fontScaleLevel = Int($0) }
                            ),
                            in: 1...5,
                            step: 1
                        )
                        .frame(maxWidth: 200)
                        
                        Text("A")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Level \(settings.fontScaleLevel): \(settings.levelDescription)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Button("Reset") {
                            settings.resetToDefault()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(settings.fontScaleLevel == 2) // Medium is default
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Display Size")
            } footer: {
                Text("Adjusts the text size throughout the app. Each level increases the font size by 2 points.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section {
                // Preview section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preview")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("John 3:16")
                            .scaledTitleFont()
                        
                        Text("For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.")
                            .scaledBodyFont()
                            .lineLimit(3)
                        
                        Text("KJV • Detected 2 minutes ago")
                            .scaledCaptionFont()
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            } header: {
                Text("Preview")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - About Tab

struct AboutTab: View {
    @ObservedObject private var cleanup = ArchiveCleanupService.shared
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @State private var showCleanupConfirmation = false
    @State private var showContactForm = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // App info section
                appInfoSection
                
                Divider()
                
                // Storage section
                storageSection
                
                // Contact Us button - only for paid/previous-paid customers
                if subscriptionService.isPremium || subscriptionService.hasBeenPaidCustomer || subscriptionService.isAdmin {
                    Divider()
                    contactUsSection
                }
                
                Spacer()
                
                Text("© 2026 Divine Link. All rights reserved.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Clean Up Storage?", isPresented: $showCleanupConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Old Sessions", role: .destructive) {
                cleanup.performCleanup()
            }
        } message: {
            Text("This will delete all services older than 90 days.")
        }
        .sheet(isPresented: $showContactForm) {
            ContactUsFormView()
        }
    }
    
    private var appInfoSection: some View {
        VStack(spacing: 12) {
            // Use the app icon from the asset catalog
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
            }
            
            Text("Divine Link")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Version \(appVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("Build \(buildNumber)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
    
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.1"
    }
    
    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
    
    private var contactUsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Support")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text("As a valued customer, you can contact us directly for assistance.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Button {
                showContactForm = true
            } label: {
                HStack {
                    Image(systemName: "envelope.fill")
                    Text("Contact Us")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.regular)
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Services:")
                        .foregroundStyle(.secondary)
                    Text("\(cleanup.totalSessionCount)")
                }
                
                GridRow {
                    Text("Scriptures:")
                        .foregroundStyle(.secondary)
                    Text("\(cleanup.totalScriptureCount)")
                }
                
                GridRow {
                    Text("Storage used:")
                        .foregroundStyle(.secondary)
                    Text(cleanup.formattedStorageSize)
                }
                
                if cleanup.expiredSessionCount > 0 {
                    GridRow {
                        Text("Expired:")
                            .foregroundStyle(.orange)
                        Text("\(cleanup.expiredSessionCount) sessions")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .font(.callout)
            
            HStack {
                Text("Sessions kept for 90 days")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                Spacer()
                
                Button {
                    showCleanupConfirmation = true
                } label: {
                    Label("Clean Up", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Contact Us Form View

/// Form shown to paid/previous-paid customers to contact support
struct ContactUsFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authService = AuthService.shared
    
    @State private var title = ""
    @State private var fullName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var message = ""
    @State private var agreedToContact = false
    @State private var isSending = false
    @State private var showConfirmation = false
    @State private var sendError: String?
    
    private let titleOptions = ["Mr", "Mrs", "Ms", "Dr", "Rev", "Pastor", "Other"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Contact Us")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Form content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Picker("Title", selection: $title) {
                            Text("Select...").tag("")
                            ForEach(titleOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    // Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Full Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("Enter your full name", text: $fullName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Email
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email Address")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("Enter your email address", text: $email)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Phone (optional)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Phone Number")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("(optional)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        TextField("Enter your phone number", text: $phone)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Message
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Message")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextEditor(text: $message)
                            .frame(minHeight: 120)
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Consent checkbox
                    Toggle(isOn: $agreedToContact) {
                        Text("I agree that Divine Link may contact me regarding this enquiry")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .toggleStyle(.checkbox)
                    
                    // Error message
                    if let error = sendError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    
                    // Submit button
                    HStack {
                        Spacer()
                        Button {
                            submitForm()
                        } label: {
                            HStack {
                                if isSending {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 14, height: 14)
                                }
                                Text(isSending ? "Sending..." : "Send Message")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(!isFormValid || isSending)
                        Spacer()
                    }
                }
                .padding()
            }
        }
        .frame(width: 440, height: 560)
        .onAppear {
            // Pre-fill email from account
            if let userEmail = authService.currentUser?.email {
                email = userEmail
            }
        }
        .alert("Message Sent", isPresented: $showConfirmation) {
            Button("OK") { dismiss() }
        } message: {
            Text("Thank you for contacting us. We shall respond to your enquiry as soon as possible.")
        }
    }
    
    private var isFormValid: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        email.contains("@") &&
        !message.trimmingCharacters(in: .whitespaces).isEmpty &&
        agreedToContact
    }
    
    private func submitForm() {
        sendError = nil
        isSending = true
        
        // Send via Supabase Edge Function
        Task {
            do {
                let payload: [String: Any] = [
                    "title": title,
                    "name": fullName,
                    "email": email,
                    "phone": phone,
                    "message": message,
                    "user_id": authService.currentUser?.id ?? "unknown",
                    "app_version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                    "tier": SubscriptionService.shared.currentTier.rawValue,
                    "timestamp": ISO8601DateFormatter().string(from: Date())
                ]
                
                let url = SupabaseConfig.functionsURL.appendingPathComponent("contact-form")
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
                
                if let token = AuthService.shared.accessToken {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    showConfirmation = true
                } else {
                    // Fallback: open mailto link
                    openMailtoFallback()
                    showConfirmation = true
                }
            } catch {
                // Fallback: open mailto link
                openMailtoFallback()
                showConfirmation = true
            }
            
            isSending = false
        }
    }
    
    /// Fallback to system email client if Edge Function is unavailable
    private func openMailtoFallback() {
        let subject = "Divine Link Support Enquiry"
        let body = """
        Title: \(title)
        Name: \(fullName)
        Email: \(email)
        Phone: \(phone)
        Tier: \(SubscriptionService.shared.currentTier.displayName)
        
        Message:
        \(message)
        """
        
        if let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "mailto:support@divinelink.app?subject=\(encodedSubject)&body=\(encodedBody)") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Previews

#Preview("Settings") {
    SettingsView()
}

#Preview("Audio Tab") {
    AudioSettingsTab()
        .frame(width: 450, height: 300)
}

#Preview("Contact Form") {
    ContactUsFormView()
}

