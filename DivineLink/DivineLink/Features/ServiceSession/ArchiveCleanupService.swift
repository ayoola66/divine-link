import Foundation
import AppKit

// MARK: - Archive Cleanup Service

/// Manages automatic cleanup of old service sessions
@MainActor
class ArchiveCleanupService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = ArchiveCleanupService()
    
    // MARK: - Properties
    
    let retentionDays = 90
    @Published var expiredSessionCount = 0
    @Published var pendingExport: [ServiceSession] = []
    
    // MARK: - Initialisation
    
    private init() {}
    
    // MARK: - Cleanup Check
    
    /// Check for expired sessions on app launch
    func checkOnLaunch() {
        let expired = checkForExpiredSessions()
        
        if !expired.isEmpty {
            expiredSessionCount = expired.count
            pendingExport = expired
            showCleanupAlert(sessions: expired)
        } else {
            // Just run silent cleanup to remove any orphaned data
            ServiceArchive.shared.performCleanup()
        }
    }
    
    /// Check for sessions older than retention period
    func checkForExpiredSessions() -> [ServiceSession] {
        guard let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) else {
            return []
        }
        
        let allSessions = ServiceArchive.shared.loadAll()
        return allSessions.filter { $0.date < cutoffDate }
    }
    
    /// Get count of sessions that will expire soon (within 7 days)
    func sessionsExpiringSoon() -> Int {
        guard let warningDate = Calendar.current.date(byAdding: .day, value: -(retentionDays - 7), to: Date()),
              let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) else {
            return 0
        }
        
        let allSessions = ServiceArchive.shared.loadAll()
        return allSessions.filter { $0.date < warningDate && $0.date >= cutoffDate }.count
    }
    
    // MARK: - Cleanup Alert
    
    private func showCleanupAlert(sessions: [ServiceSession]) {
        let alert = NSAlert()
        alert.messageText = "Old Services Found"
        alert.informativeText = """
            \(sessions.count) service(s) older than \(retentionDays) days will be deleted.
            
            Would you like to export them first?
            """
        alert.alertStyle = .informational
        alert.icon = NSImage(systemSymbolName: "clock.badge.exclamationmark", accessibilityDescription: nil)
        
        alert.addButton(withTitle: "Export & Delete")
        alert.addButton(withTitle: "Delete Now")
        alert.addButton(withTitle: "Remind Later")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            // Export all then delete
            exportAllExpired(sessions)
            performCleanup()
            
        case .alertSecondButtonReturn:
            // Delete immediately
            performCleanup()
            
        default:
            // Remind later - do nothing
            print("[Cleanup] User deferred cleanup to later")
        }
    }
    
    // MARK: - Cleanup Actions
    
    /// Perform the actual cleanup
    func performCleanup() {
        ServiceArchive.shared.performCleanup()
        expiredSessionCount = 0
        pendingExport = []
        print("[Cleanup] Cleanup completed")
    }
    
    /// Export all expired sessions before deletion
    private func exportAllExpired(_ sessions: [ServiceSession]) {
        // Create a folder for exports
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let folderName = "DivineLink_Export_\(dateFormatter.string(from: Date()))"
        
        let exportFolder = FileManager.default.temporaryDirectory.appendingPathComponent(folderName)
        
        do {
            try FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
            
            for session in sessions {
                if let jsonURL = ServiceArchive.shared.exportToJSON(session) {
                    let destURL = exportFolder.appendingPathComponent(jsonURL.lastPathComponent)
                    try? FileManager.default.copyItem(at: jsonURL, to: destURL)
                }
            }
            
            // Open folder in Finder
            NSWorkspace.shared.activateFileViewerSelecting([exportFolder])
            
            print("[Cleanup] Exported \(sessions.count) sessions to \(exportFolder.path)")
            
        } catch {
            print("[Cleanup] Export failed: \(error)")
        }
    }
    
    // MARK: - Storage Info
    
    /// Get formatted storage usage string
    var formattedStorageSize: String {
        let info = ServiceArchive.shared.getStorageInfo()
        return ByteCountFormatter.string(fromByteCount: info.sizeBytes, countStyle: .file)
    }
    
    /// Get total session count
    var totalSessionCount: Int {
        ServiceArchive.shared.getStorageInfo().sessionCount
    }
    
    /// Get total scripture count
    var totalScriptureCount: Int {
        ServiceArchive.shared.getStorageInfo().scriptureCount
    }
}
