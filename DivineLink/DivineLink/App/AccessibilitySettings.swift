import SwiftUI
import Combine

/// Accessibility settings for font scaling and display preferences
/// Levels 1-5 where each level increases base font size by 2 points
class AccessibilitySettings: ObservableObject {
    static let shared = AccessibilitySettings()
    
    /// Font scale level (1-5)
    /// Level 1: Base size (no scaling)
    /// Level 2: +2 points
    /// Level 3: +4 points
    /// Level 4: +6 points
    /// Level 5: +8 points
    @Published var fontScaleLevel: Int {
        didSet {
            UserDefaults.standard.set(fontScaleLevel, forKey: "fontScaleLevel")
        }
    }
    
    /// Additional points to add to base font sizes
    var fontSizeOffset: CGFloat {
        CGFloat((fontScaleLevel - 1) * 2)
    }
    
    /// Scale factor for fonts (relative to base)
    var scaleFactor: CGFloat {
        1.0 + (CGFloat(fontScaleLevel - 1) * 0.15) // 15% increase per level
    }
    
    private init() {
        // Check if user has ever set a preference
        let hasUserPreference = UserDefaults.standard.object(forKey: "fontScaleLevel") != nil
        
        if hasUserPreference {
            self.fontScaleLevel = UserDefaults.standard.integer(forKey: "fontScaleLevel")
            // Ensure valid range
            if self.fontScaleLevel < 1 || self.fontScaleLevel > 5 {
                self.fontScaleLevel = 2 // Default to Medium
            }
        } else {
            // Default to level 2 (Medium) for new users
            self.fontScaleLevel = 2
        }
    }
    
    /// Reset to default font size (Medium)
    func resetToDefault() {
        fontScaleLevel = 2 // Medium is now default
    }
    
    /// Description for current level
    var levelDescription: String {
        switch fontScaleLevel {
        case 1: return "Small"
        case 2: return "Medium (Default)"
        case 3: return "Large"
        case 4: return "Extra Large"
        case 5: return "Maximum"
        default: return "Medium"
        }
    }
}

// MARK: - Scaled Font Modifier

/// View modifier that applies accessibility font scaling
struct ScaledFont: ViewModifier {
    @ObservedObject private var settings = AccessibilitySettings.shared
    let baseSize: CGFloat
    let weight: Font.Weight
    
    init(baseSize: CGFloat, weight: Font.Weight = .regular) {
        self.baseSize = baseSize
        self.weight = weight
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: baseSize + settings.fontSizeOffset, weight: weight))
    }
}

// MARK: - View Extensions

extension View {
    /// Apply scaled font based on accessibility settings
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.modifier(ScaledFont(baseSize: size, weight: weight))
    }
    
    /// Apply title font with accessibility scaling
    func scaledTitleFont() -> some View {
        self.modifier(ScaledFont(baseSize: 18, weight: .bold))
    }
    
    /// Apply body font with accessibility scaling
    func scaledBodyFont() -> some View {
        self.modifier(ScaledFont(baseSize: 13, weight: .regular))
    }
    
    /// Apply caption font with accessibility scaling
    func scaledCaptionFont() -> some View {
        self.modifier(ScaledFont(baseSize: 11, weight: .regular))
    }
}

// MARK: - Environment Key

private struct AccessibilitySettingsKey: EnvironmentKey {
    static let defaultValue = AccessibilitySettings.shared
}

extension EnvironmentValues {
    var accessibilitySettings: AccessibilitySettings {
        get { self[AccessibilitySettingsKey.self] }
        set { self[AccessibilitySettingsKey.self] = newValue }
    }
}
