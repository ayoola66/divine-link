# Story 8.1: Modern UI Redesign (YouVersion-Inspired)

**Story ID:** 8.1
**Epic:** 8 - UX/UI Modernization & Platform Expansion
**Priority:** P0 (Critical - Must-Have)
**Complexity:** Large
**Estimated Effort:** 20-30 hours
**Phase:** Phase 1 (Week 1)
**Target Version:** v2.0.0

---

## Story Description

Transform Divine Link's main window with a modern, card-based UI that combines YouVersion's clean, familiar aesthetic with QuickVerse's contemporary polish, while maintaining Divine Link's unique gold accent identity.

---

## User Story

**As a** church media operator
**I want** a modern, professional-looking interface that's easy to understand
**So that** I can confidently use Divine Link during live services and feel the app is high-quality

---

## Business Value

- **User Satisfaction:** Modern UI reduces learning curve, increases perceived quality
- **Competitive Positioning:** Matches QuickVerse's modern aesthetic while maintaining unique identity
- **Market Expectation:** 2026 users expect YouVersion-level polish
- **Conversion:** Premium-feeling UI justifies £9.97/month pricing
- **Retention:** Professional appearance reduces churn

**Impact Score:** 5/5 (Critical foundation for all other Epic 8 features)

---

## Acceptance Criteria

### Main Window Layout
- [ ] Window supports resizing (minimum 1024×768, preferred 1440×900)
- [ ] Header bar displays Divine Link circular gold logo (48×48px)
- [ ] Status indicator shows "Listening" with animated blue pulse dot
- [ ] Settings gear icon positioned top-right

### Audio Control Bar
- [ ] Audio bar spans full width with 5 elements (Audio, Speech, Bible Version, Detect, Meter)
- [ ] Audio/Speech/Detect buttons are 36px height with proper icons
- [ ] Bible version dropdown shows "KJV ▼" with functional dropdown
- [ ] Audio level meter displays 8 LED-style bars with real-time animation
- [ ] All buttons have proper hover states and are keyboard accessible

### Live Transcription Card
- [ ] Card has light gray background (#F9FAFB) with subtle shadow
- [ ] Border radius is 12px
- [ ] "Live Transcription" header in medium weight
- [ ] Transcript text in SF Mono, 13pt, auto-scrolls to bottom
- [ ] Maximum height ~200px (25% of content area)

### Pending Scripture Card (PRIMARY FOCUS)
- [ ] Card has white background with 3px gold border (#D4AF37)
- [ ] Gold glow shadow: `0px 4px 20px rgba(212, 175, 55, 0.2)`
- [ ] Border radius is 16px (featured card)
- [ ] "Detected Scripture" badge with gold background, white text
- [ ] Confidence indicator badge (green background for high confidence)
- [ ] Scripture reference in 36pt Bold (e.g., "Romans 8:28")
- [ ] Verse text in Georgia serif, 18pt, line height 1.7
- [ ] Translation label in 12pt gray (e.g., "Berean Standard Bible")
- [ ] Edit and copy icons in bottom-right corner

### Action Buttons
- [ ] "Push to ProPresenter" button: Gold gradient, 280px × 56px, right arrow icon
- [ ] "Ignore" button: Light gray background, 160px × 56px, X mark icon
- [ ] "Pause Listening" button: White with border, 200px × 56px, pause icon
- [ ] 16px gap between all buttons
- [ ] All buttons have hover states (scale 1.02 for primary, background change for others)

### Floating Action Button (Manual Search)
- [ ] Blue circular button (64×64px) bottom-right corner
- [ ] Magnifying glass icon, white color
- [ ] Shadow: `0px 8px 24px rgba(59, 130, 246, 0.4)`
- [ ] Hover: Scale 1.08
- [ ] Click opens manual search modal (Story 8.2 dependency)

### Ad Space (Free Tier)
- [ ] Right sidebar: 200px width, light gray background (#F5F5F5)
- [ ] 3 ad unit placeholders (168×168, 168×168, 168×280)
- [ ] "Remove Ads" button at bottom (blue, full width)
- [ ] Bottom banner: 60px height, 728×60 standard size
- [ ] Ad spaces hidden in premium tier

### Responsive Behavior
- [ ] Window resizes smoothly without jank
- [ ] Content reflows properly at different widths
- [ ] Audio bar buttons reduce to icons only at < 1200px width
- [ ] Minimum window size enforced (1024×768)

---

## Technical Specifications

### Color Palette
```swift
// Primary Colors
static let divineLinkGold = Color(hex: "#D4AF37")
static let goldDark = Color(hex: "#C19A2E")
static let blue = Color(hex: "#3B82F6")
static let blueDark = Color(hex: "#2563EB")

// Neutrals
static let nearBlack = Color(hex: "#1F2937")
static let darkGray = Color(hex: "#374151")
static let mediumGray = Color(hex: "#6B7280")
static let lightGray = Color(hex: "#E5E7EB")
static let offWhite = Color(hex: "#F9FAFB")

// Status
static let successGreen = Color(hex: "#10B981")
static let warningAmber = Color(hex: "#F59E0B")
static let errorRed = Color(hex: "#EF4444")
```

### Typography
```swift
// Scripture Reference
.font(.system(size: 36, weight: .bold, design: .default))
.foregroundColor(Color(hex: "#1F2937"))

// Scripture Verse (Serif)
.font(.custom("Georgia", size: 18))
.foregroundColor(Color(hex: "#374151"))
.lineSpacing(1.7)

// Button Text
.font(.system(size: 16, weight: .semibold))

// Labels
.font(.system(size: 12, weight: .medium))
.foregroundColor(Color(hex: "#6B7280"))
```

### Shadows
```swift
// Card Shadow
.shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)

// Featured Card (Scripture)
.shadow(color: Color(hex: "#D4AF37").opacity(0.2), radius: 10, x: 0, y: 4)

// Gold Button
.shadow(color: Color(hex: "#D4AF37").opacity(0.35), radius: 6, x: 0, y: 4)

// FAB
.shadow(color: Color(hex: "#3B82F6").opacity(0.4), radius: 12, x: 0, y: 8)
```

### Component Structure
```
MainWindowView (v2.0)
├── HeaderBarView
│   ├── LogoView (circular gold, 48px)
│   ├── StatusIndicatorView (pulsing blue dot)
│   └── SettingsButtonView (gear icon)
├── AudioControlBarView
│   ├── AudioButton
│   ├── SpeechButton (active state blue)
│   ├── BibleVersionPicker
│   ├── DetectButton
│   └── AudioLevelMeterView (8 LED bars)
├── ScrollView {
│   ├── LiveTranscriptionCardView
│   ├── PendingScriptureCardView
│   │   ├── ConfidenceBadge
│   │   ├── ScriptureReference
│   │   ├── ScriptureVerseText
│   │   ├── TranslationLabel
│   │   └── ActionIcons (edit, copy)
│   └── ActionButtonBarView
│       ├── PushToProPresenterButton (gold gradient)
│       ├── IgnoreButton (secondary)
│       └── PauseListeningButton (tertiary)
}
├── ManualSearchFAB (overlay, bottom-right)
└── AdSidebarView (conditional, free tier only)
    ├── AdUnit1, AdUnit2, AdUnit3
    ├── Spacer
    └── RemoveAdsButton
```

---

## Implementation Notes

### Assets Required
- Divine Link circular gold logo (SVG or PNG @1x/2x/3x)
- SF Symbols icons: gear, mic.fill, message.fill, magnifyingglass, arrow.right, xmark, pause.fill, doc.on.doc, pencil

### Animation Specifications
```swift
// Listening Pulse (Blue Dot)
Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: false)
    .opacity(from: 0.3, to: 1.0)

// Button Hover
.scaleEffect(isHovered ? 1.02 : 1.0)
.animation(.easeOut(duration: 0.2), value: isHovered)

// FAB Hover
.scaleEffect(isHovered ? 1.08 : 1.0)
.shadow(color: ..., radius: isHovered ? 12 : 8)
.animation(.spring(response: 0.3), value: isHovered)
```

### State Management
```swift
@StateObject var uiState = UIStateManager()

enum UIState {
    case listening
    case paused
    case scriptureDetected
    case noScripture
}
```

---

## Dependencies

### Before This Story
- None (this is the foundation story)

### After This Story (Builds On This)
- Story 8.2: Manual Scripture Search (uses FAB)
- Story 8.3: Service Session Management (uses card layout)
- Story 8.4: Export Functionality (uses scripture card)

### External Dependencies
- SwiftUI (macOS 12+)
- SF Symbols (macOS native)
- Existing services: AudioCaptureService, ScriptureDetectorService

---

## Testing Requirements

### Visual Testing
- [ ] Compare mockup vs. implementation (pixel-perfect matching)
- [ ] Test on macOS 12 (Big Sur), 13 (Ventura), 14 (Sonoma)
- [ ] Test at multiple window sizes (1024×768, 1280×800, 1440×900, 1920×1080)
- [ ] Test dark mode compatibility (if applicable)

### Functional Testing
- [ ] Audio meter animates correctly with real audio input
- [ ] Blue pulse dot animates smoothly (1.5s cycle)
- [ ] All buttons respond to clicks with proper feedback
- [ ] Hover states work correctly on all interactive elements
- [ ] Keyboard navigation follows logical tab order
- [ ] Window resize is smooth (60 FPS)

### Accessibility Testing
- [ ] All buttons meet 44×44pt minimum touch target (exceeds - 56px)
- [ ] Color contrast ratios meet WCAG AA (4.5:1)
- [ ] Keyboard focus indicators visible (2px blue outline)
- [ ] VoiceOver reads all elements correctly

### Performance Testing
- [ ] UI renders at 60 FPS
- [ ] Window resize has no jank
- [ ] Memory usage < 150MB idle, < 300MB active
- [ ] Audio meter updates at 60Hz

---

## Definition of Done

- [x] All acceptance criteria met
- [x] Code review completed
- [x] Unit tests written and passing (if applicable)
- [x] Visual regression testing passed
- [x] Accessibility testing passed
- [x] Performance benchmarks met
- [x] Documentation updated
- [x] Mockup comparison approved
- [x] Merged to main branch

---

## Rollout Plan

### Phase 1: Development
1. Create new UI component structure
2. Implement header bar with logo and status
3. Implement audio control bar
4. Implement card layouts (transcript + scripture)
5. Implement action buttons
6. Implement FAB
7. Implement ad sidebar (conditional)

### Phase 2: Testing
1. Visual testing against mockups
2. Functional testing (all interactions)
3. Accessibility testing
4. Performance testing
5. Bug fixes

### Phase 3: Integration
1. Wire up existing services (audio, detection)
2. Integrate with ad system (free/premium tiers)
3. Final polish and refinement

### Phase 4: Release
1. Merge to main
2. Tag as v2.0.0-alpha
3. Beta test with 3-5 users
4. Collect feedback and iterate

---

## Risks & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| SwiftUI layout issues | Medium | High | Prototype early, test on multiple macOS versions |
| Performance regression | Low | Medium | Profile early, optimize animations |
| Mockup-to-code mismatch | Medium | Low | Pixel-perfect comparison, iterative refinement |
| Breaking existing features | Low | High | Comprehensive regression testing |

---

## Related Documents

- [Epic 8 README](./README.md)
- [Epic 8 Index](./INDEX.md)
- [Technical Specification](../../epic-8-technical-specification.md)
- [Main Window Mockups](../../wireframes/) - Gemini and Figma versions

---

## Notes

- This is the **foundation story** - all other Epic 8 stories build on this
- YouVersion inspiration: Clean, uncluttered, content-focused
- QuickVerse inspiration: Modern cards, gradients, depth
- Divine Link identity: Gold accent (#D4AF37) is non-negotiable
- Local-first: All rendering must be performant offline

---

**Story Owner:** coachAOG
**Created:** February 18, 2026
**Status:** 📋 Ready for Implementation
**Blocked By:** None
**Blocks:** Stories 8.2, 8.3, 8.4, 8.5, 8.6
