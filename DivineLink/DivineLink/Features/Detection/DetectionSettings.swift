import Foundation
import Combine
import SwiftUI

/// Manages user settings for scripture detection behaviour
final class DetectionSettings: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = DetectionSettings()
    
    // MARK: - Published Properties
    
    /// Whether to auto-hold low confidence detections for manual review
    @Published var autoHoldLowConfidence: Bool {
        didSet {
            UserDefaults.standard.set(autoHoldLowConfidence, forKey: Keys.autoHoldLowConfidence)
        }
    }
    
    /// Threshold below which a detection is considered "low confidence" (0.0-1.0)
    @Published var lowConfidenceThreshold: Double {
        didSet {
            UserDefaults.standard.set(lowConfidenceThreshold, forKey: Keys.lowConfidenceThreshold)
        }
    }
    
    /// Whether to show detailed confidence breakdown in the UI
    @Published var showConfidenceBreakdown: Bool {
        didSet {
            UserDefaults.standard.set(showConfidenceBreakdown, forKey: Keys.showConfidenceBreakdown)
        }
    }
    
    /// Whether to show confidence indicators on detected verses
    @Published var showConfidenceIndicators: Bool {
        didSet {
            UserDefaults.standard.set(showConfidenceIndicators, forKey: Keys.showConfidenceIndicators)
        }
    }
    
    /// Whether to play a sound for low confidence detections
    @Published var soundOnLowConfidence: Bool {
        didSet {
            UserDefaults.standard.set(soundOnLowConfidence, forKey: Keys.soundOnLowConfidence)
        }
    }
    
    // MARK: - UserDefaults Keys
    
    private enum Keys {
        static let autoHoldLowConfidence = "detection.autoHoldLowConfidence"
        static let lowConfidenceThreshold = "detection.lowConfidenceThreshold"
        static let showConfidenceBreakdown = "detection.showConfidenceBreakdown"
        static let showConfidenceIndicators = "detection.showConfidenceIndicators"
        static let soundOnLowConfidence = "detection.soundOnLowConfidence"
    }
    
    // MARK: - Initialisation
    
    private init() {
        // Load saved values or use defaults
        self.autoHoldLowConfidence = UserDefaults.standard.object(forKey: Keys.autoHoldLowConfidence) as? Bool ?? true
        self.lowConfidenceThreshold = UserDefaults.standard.object(forKey: Keys.lowConfidenceThreshold) as? Double ?? 0.70
        self.showConfidenceBreakdown = UserDefaults.standard.object(forKey: Keys.showConfidenceBreakdown) as? Bool ?? false
        self.showConfidenceIndicators = UserDefaults.standard.object(forKey: Keys.showConfidenceIndicators) as? Bool ?? true
        self.soundOnLowConfidence = UserDefaults.standard.object(forKey: Keys.soundOnLowConfidence) as? Bool ?? true
    }
    
    // MARK: - Methods
    
    /// Reset all settings to default values
    func resetToDefaults() {
        autoHoldLowConfidence = true
        lowConfidenceThreshold = 0.70
        showConfidenceBreakdown = false
        showConfidenceIndicators = true
        soundOnLowConfidence = true
    }
    
    /// Check if a confidence value is considered low based on current threshold
    func isLowConfidence(_ confidence: Double) -> Bool {
        return confidence < lowConfidenceThreshold
    }
    
    /// Check if a DetectionConfidence is low based on current threshold
    func isLowConfidence(_ confidence: DetectionConfidence) -> Bool {
        return confidence.overall < lowConfidenceThreshold
    }
}
