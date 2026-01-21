# Story 4.7: Archive Auto-Cleanup (90 Days)

**Epic:** 4 - Service Sessions & Pastor Profiles  
**Story ID:** 4.7  
**Status:** Not Started  
**Complexity:** Small  

---

## User Story

**As an** operator,  
**I want** old services to be automatically deleted after 90 days,  
**so that** storage doesn't grow indefinitely.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Cleanup runs on app launch | Triggered at startup |
| 2 | Services older than 90 days are identified | Query correct |
| 3 | User notified before deletion if any found | Alert shown |
| 4 | Option to export before delete | Export button in alert |
| 5 | Deletion proceeds after user acknowledgement | Data removed |
| 6 | Cleanup also runs on Settings > Storage page | Manual trigger available |
| 7 | Storage usage displayed in Settings | Size shown |

---

## Technical Notes

### Cleanup Flow

```swift
class ArchiveCleanupService {
    private let retentionDays = 90
    
    func checkForExpiredSessions() -> [ServiceSession] {
        let cutoffDate = Calendar.current.date(
            byAdding: .day, 
            value: -retentionDays, 
            to: Date()
        )!
        
        return ServiceArchive.shared.sessions.filter { 
            $0.date < cutoffDate 
        }
    }
    
    func deleteExpiredSessions() {
        let expired = checkForExpiredSessions()
        for session in expired {
            ServiceArchive.shared.delete(session)
        }
    }
}
```

### Startup Check

```swift
// In App init or AppDelegate
func applicationDidFinishLaunching() {
    let cleanup = ArchiveCleanupService()
    let expired = cleanup.checkForExpiredSessions()
    
    if !expired.isEmpty {
        // Show alert
        showCleanupAlert(sessions: expired)
    }
}

func showCleanupAlert(sessions: [ServiceSession]) {
    let alert = NSAlert()
    alert.messageText = "Old Services Found"
    alert.informativeText = "\(sessions.count) services older than 90 days will be deleted. Export them first?"
    alert.addButton(withTitle: "Export All")
    alert.addButton(withTitle: "Delete Now")
    alert.addButton(withTitle: "Remind Later")
    
    // Handle response...
}
```

### Storage Settings

```swift
struct StorageSettingsSection: View {
    @StateObject private var archive = ServiceArchive.shared
    
    var body: some View {
        Section("Storage") {
            LabeledContent("Services Stored", value: "\(archive.sessions.count)")
            LabeledContent("Storage Used", value: archive.formattedStorageSize)
            
            Button("Clean Up Old Services") {
                // Run cleanup
            }
        }
    }
}
```

---

## Dependencies

- Story 4.3 (Service History Archive)

---

## Definition of Done

- [ ] Auto-cleanup runs on launch
- [ ] User notification works
- [ ] Export option available
- [ ] Manual cleanup in Settings
- [ ] Committed to Git
