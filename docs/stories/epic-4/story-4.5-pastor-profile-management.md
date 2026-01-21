# Story 4.5: Pastor Profile Management

**Epic:** 4 - Service Sessions & Pastor Profiles  
**Story ID:** 4.5  
**Status:** Not Started  
**Complexity:** Medium  

---

## User Story

**As an** operator,  
**I want** to create and manage pastor profiles,  
**so that** the app can learn each pastor's speaking patterns over time.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Settings includes "Pastor Profiles" section | Section visible |
| 2 | Add new pastor with name | Create works |
| 3 | Edit existing pastor name | Edit works |
| 4 | Delete pastor (with confirmation) | Delete works |
| 5 | Pastor profiles persist across app restarts | Data survives |
| 6 | Pastor selectable when starting new service | Dropdown shows pastors |
| 7 | Active session shows which pastor is selected | Header indicator |
| 8 | Pastor profile shows learned corrections count | Stats visible |

---

## Technical Notes

### Pastor Profile Model

```swift
struct PastorProfile: Identifiable, Codable {
    let id: UUID
    var name: String
    var createdAt: Date
    var speechCorrections: [SpeechCorrection]
    var servicesCount: Int
    
    struct SpeechCorrection: Codable {
        let heard: String       // "Some"
        let corrected: String   // "Psalms"
        var occurrences: Int    // How many times this correction was made
        var lastUsed: Date
    }
}
```

### Pastor Profile Manager

```swift
class PastorProfileManager: ObservableObject {
    @Published var profiles: [PastorProfile] = []
    
    func create(name: String) -> PastorProfile {
        let profile = PastorProfile(
            id: UUID(),
            name: name,
            createdAt: Date(),
            speechCorrections: [],
            servicesCount: 0
        )
        profiles.append(profile)
        save()
        return profile
    }
    
    func delete(_ profile: PastorProfile) {
        profiles.removeAll { $0.id == profile.id }
        save()
    }
    
    func addCorrection(to pastorId: UUID, heard: String, corrected: String) {
        // Find profile and add/update correction
    }
}
```

### Settings UI

```swift
struct PastorProfilesSettingsTab: View {
    @StateObject private var manager = PastorProfileManager.shared
    @State private var showAddSheet = false
    
    var body: some View {
        Form {
            Section {
                ForEach(manager.profiles) { pastor in
                    HStack {
                        Text(pastor.name)
                        Spacer()
                        Text("\(pastor.speechCorrections.count) corrections")
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { /* delete */ }
                
                Button("Add Pastor") { showAddSheet = true }
            } header: {
                Text("Pastor Profiles")
            }
        }
    }
}
```

---

## Dependencies

- Story 4.1 (Service Session Creation)

---

## Definition of Done

- [ ] CRUD operations for pastor profiles
- [ ] Profiles persist
- [ ] Selectable in new service flow
- [ ] Corrections count displayed
- [ ] Committed to Git
