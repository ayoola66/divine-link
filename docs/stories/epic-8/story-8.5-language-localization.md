# Story 8.5: Language Localization (UK/US English)

**Story ID:** 8.5
**Epic:** 8 - UX/UI Modernization & Platform Expansion
**Priority:** P1 (Should-Have)
**Complexity:** Small
**Estimated Effort:** 4-8 hours
**Phase:** Phase 1 (Week 1)
**Target Version:** v2.0.0

---

## Story Description

Add UK/US English localization toggle, supporting regional spelling variants (e.g., "colour" vs. "color") and date formats (DD/MM/YYYY vs. MM/DD/YYYY), setting foundation for future internationalization.

---

## User Story

**As a** UK-based church operator
**I want** to see UK English spelling and date formats
**So that** the app feels native to my region

---

## Business Value

- **Market Expansion:** Opens UK market (currently 95% US-focused)
- **Infrastructure Investment:** Sets foundation for future translations (Spanish, French, etc.)
- **Competitive Parity:** QuickVerse has localization; good for feature parity
- **Low Effort:** Quick win, future-proofs the app

**Impact Score:** 2/5 (Strategic investment, not urgent)

---

## Acceptance Criteria

### Settings UI
- [ ] New "Language" tab in Settings window
- [ ] Tab displays "Language & Region" title (24pt, bold)
- [ ] Segmented control with 2 options: "UK English" | "US English"
- [ ] Selected option: Gold background (#D4AF37), white text
- [ ] Unselected: Light gray background, dark text

### Regional Format Preview
- [ ] Below selector, show preview card
- [ ] Label: "Date Format Preview"
- [ ] UK example: "17 February 2026"
- [ ] US example: "February 17, 2026"
- [ ] Preview updates immediately on selection change

### Spelling Variants (Text Changes)
**UK English:**
- "Colour" (vs. US "Color")
- "Organised" (vs. "Organized")
- "Centre" (vs. "Center")
- "Licence" (vs. "License")

**US English:**
- Default (current spelling)

**Note:** Only affect UI text, not scripture verse content

### Date Format Changes
**UK Format:**
- Short: DD/MM/YYYY (e.g., "18/02/2026")
- Long: DD Month YYYY (e.g., "18 February 2026")

**US Format:**
- Short: MM/DD/YYYY (e.g., "02/18/2026")
- Long: Month DD, YYYY (e.g., "February 18, 2026")

### Persistence
- [ ] Selection saves to UserDefaults
- [ ] Persists across app restarts
- [ ] Defaults to system locale on first launch

---

## Technical Specifications

### Localization Manager
```swift
class LocalizationManager: ObservableObject {
    @Published var locale: AppLocale = .system

    enum AppLocale: String, Codable {
        case system = "system"
        case enUS = "en_US"
        case enGB = "en_GB"

        var dateFormat: String {
            switch self {
            case .enUS: return "MM/dd/yyyy"
            case .enGB: return "dd/MM/yyyy"
            case .system: return Locale.current.identifier.contains("GB") ? "dd/MM/yyyy" : "MM/dd/yyyy"
            }
        }

        var longDateFormat: String {
            switch self {
            case .enUS: return "MMMM dd, yyyy"
            case .enGB: return "dd MMMM yyyy"
            case .system: return Locale.current.identifier.contains("GB") ? "dd MMMM yyyy" : "MMMM dd, yyyy"
            }
        }
    }

    func setLocale(_ locale: AppLocale) {
        self.locale = locale
        UserDefaults.standard.set(locale.rawValue, forKey: "AppLocale")
    }

    func loadLocale() {
        guard let saved = UserDefaults.standard.string(forKey: "AppLocale"),
              let locale = AppLocale(rawValue: saved) else {
            self.locale = .system
            return
        }
        self.locale = locale
    }
}
```

### Localizable.strings Structure
```
// en-US.lproj/Localizable.strings
"color" = "color";
"organized" = "organized";
"center" = "center";
"license" = "license";

// en-GB.lproj/Localizable.strings
"color" = "colour";
"organized" = "organised";
"center" = "centre";
"license" = "licence";
```

### SwiftUI Integration
```swift
Text(NSLocalizedString("color", comment: ""))
    .environment(\.locale, .init(identifier: localizationManager.locale.rawValue))
```

---

## Dependencies

### Before This Story
- Story 8.1: Modern UI Redesign (provides Settings window framework)

### After This Story
- Future epics: Spanish, French, German translations (Epic 9+)

### External Dependencies
- SwiftUI Localization APIs
- UserDefaults for persistence

---

## Testing Requirements

### Functional Testing
- [ ] Toggle switches between UK/US English correctly
- [ ] Date previews update immediately
- [ ] Spelling variants apply throughout app
- [ ] Selection persists after app restart
- [ ] System locale detection works on first launch

### Localization Testing
- [ ] All UI text uses localized strings (no hardcoded text)
- [ ] Date formats apply to all date displays (session history, export, etc.)
- [ ] No missing translations (fallback to English if missing)

### Edge Cases
- [ ] Switching locale mid-session (UI updates without restart)
- [ ] Export functionality uses correct date format
- [ ] Session history dates display in selected format

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] UK/US English toggle functional in Settings
- [ ] Date formats apply throughout app
- [ ] Spelling variants implemented for common words
- [ ] Selection persists across restarts
- [ ] Code review completed
- [ ] Testing passed
- [ ] Merged to main

---

## Implementation Notes

### Strings to Localize (Initial Set)
**High Priority (Visible in UI):**
- "Color" → "Colour"
- "Organized" → "Organised"
- "Center" → "Centre"
- All date displays (session history, exports)

**Low Priority:**
- Error messages
- Tooltips
- Help text

**Not Localized:**
- Scripture verse content (stays in original translation)
- Bible book names (use English names universally)

### Future Expansion
This story sets infrastructure for:
- Spanish (es-ES, es-MX)
- French (fr-FR, fr-CA)
- German (de-DE)
- Portuguese (pt-BR, pt-PT)

---

## UI Mockup Reference

**Settings > Language Tab:**
```
┌─────────────────────────────────────────────────────────┐
│ Language & Region                                        │
│                                                          │
│ ┌────────────────────────────────────────────────────┐  │
│ │ Interface Language                                  │  │
│ │                                                     │  │
│ │ ┌──────────────┬──────────────┐                    │  │
│ │ │  UK English  │  US English  │ (Segmented Control)│  │
│ │ └──────────────┴──────────────┘                    │  │
│ └────────────────────────────────────────────────────┘  │
│                                                          │
│ ┌────────────────────────────────────────────────────┐  │
│ │ Regional Format                                     │  │
│ │                                                     │  │
│ │ Date Format Preview:                                │  │
│ │ • UK: 17 February 2026                              │  │
│ │ • US: February 17, 2026                             │  │
│ └────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## Related Documents

- [Epic 8 README](./README.md)
- [Story 8.1 - Modern UI Redesign](./story-8.1-modern-ui-redesign.md)
- [Settings Window Design Prompt](../../wireframes/epic-8-settings-window-prompt.md)
- [Technical Specification](../../epic-8-technical-specification.md)

---

**Story Owner:** coachAOG
**Created:** February 18, 2026
**Status:** 📋 Ready for Implementation
**Blocked By:** Story 8.1
**Blocks:** None
