# Story 7.3: Pastor Profiles

**Epic:** 7 - Advanced Detection & Personalisation  
**Story ID:** 7.3  
**Status:** Not Started  
**Complexity:** Medium  
**Priority:** P1 (Sticky Feature)

---

## User Story

**As a** church administrator,  
**I want** to create profiles for each pastor with their preferred Bible translation,  
**so that** the operator can quickly switch settings when different pastors are preaching.

---

## Background

**The Problem:**
Different pastors have different preferences:
- Pastor John prefers KJV
- Pastor Sarah prefers NIV
- Guest speaker may use ESV

Currently, the operator must manually change translation settings between services.

**The Solution:**
Pastor Profiles that store:
- Preferred Bible translation
- Any pastor-specific detection tuning
- Quick-switch capability

**Professor BMAD:**
> "This is a 'Sticky Feature.' Once a church sets up their 4 pastors with their preferred translations, they will never switch to another app."

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Create new pastor profile | Name, photo, translation saved |
| 2 | Edit existing profile | Changes persist |
| 3 | Delete profile | Removed from list |
| 4 | Quick-switch between profiles | One-click change |
| 5 | Active profile shown in UI | Current pastor visible |
| 6 | Translation changes when profile switches | Correct Bible used |
| 7 | Profiles persist across app restarts | Stored locally |
| 8 | Default/Guest profile available | For unknown speakers |
| 9 | Profile sync across devices (optional) | Via iCloud or Supabase |
| 10 | Keyboard shortcut for profile switch | Cmd+1/2/3/4 |

---

## Technical Notes

### Pastor Profile Model

```swift
// PastorProfile.swift
import Foundation

struct PastorProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var photoData: Data?  // Optional profile photo
    var preferredTranslation: BibleTranslation
    var notes: String?
    var createdAt: Date
    var lastUsed: Date?
    
    // Future: AI tuning parameters
    var speechPatterns: [String]?  // Common phrases this pastor uses
    var preferredConfidenceThreshold: Double?
    
    init(name: String, translation: BibleTranslation) {
        self.id = UUID()
        self.name = name
        self.preferredTranslation = translation
        self.createdAt = Date()
    }
    
    static var guest: PastorProfile {
        var profile = PastorProfile(name: "Guest Speaker", translation: .kjv)
        profile.id = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        return profile
    }
}

enum BibleTranslation: String, Codable, CaseIterable {
    case kjv = "KJV"
    case niv = "NIV"
    case esv = "ESV"
    case nlt = "NLT"
    case nasb = "NASB"
    case nkjv = "NKJV"
    case amp = "AMP"
    case msg = "MSG"
    
    var fullName: String {
        switch self {
        case .kjv: return "King James Version"
        case .niv: return "New International Version"
        case .esv: return "English Standard Version"
        case .nlt: return "New Living Translation"
        case .nasb: return "New American Standard Bible"
        case .nkjv: return "New King James Version"
        case .amp: return "Amplified Bible"
        case .msg: return "The Message"
        }
    }
}
```

### Profile Manager Service

```swift
// PastorProfileManager.swift
import Foundation
import SwiftUI

class PastorProfileManager: ObservableObject {
    @Published var profiles: [PastorProfile] = []
    @Published var activeProfile: PastorProfile?
    
    private let storageKey = "divine_link_pastor_profiles"
    private let activeProfileKey = "divine_link_active_profile"
    
    // MARK: - Initialization
    
    init() {
        loadProfiles()
        loadActiveProfile()
        
        // Ensure Guest profile exists
        if !profiles.contains(where: { $0.id == PastorProfile.guest.id }) {
            profiles.insert(.guest, at: 0)
            saveProfiles()
        }
    }
    
    // MARK: - CRUD Operations
    
    func addProfile(_ profile: PastorProfile) {
        profiles.append(profile)
        saveProfiles()
    }
    
    func updateProfile(_ profile: PastorProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
            saveProfiles()
            
            // Update active if this is the active profile
            if activeProfile?.id == profile.id {
                activeProfile = profile
            }
        }
    }
    
    func deleteProfile(_ profile: PastorProfile) {
        // Don't delete Guest profile
        guard profile.id != PastorProfile.guest.id else { return }
        
        profiles.removeAll { $0.id == profile.id }
        saveProfiles()
        
        // Switch to Guest if active profile deleted
        if activeProfile?.id == profile.id {
            switchToProfile(.guest)
        }
    }
    
    // MARK: - Profile Switching
    
    func switchToProfile(_ profile: PastorProfile) {
        // Update last used timestamp
        if var updatedProfile = profiles.first(where: { $0.id == profile.id }) {
            updatedProfile.lastUsed = Date()
            updateProfile(updatedProfile)
        }
        
        activeProfile = profile
        saveActiveProfile()
        
        // Notify observers
        NotificationCenter.default.post(
            name: .pastorProfileChanged,
            object: profile
        )
    }
    
    func switchToProfileAtIndex(_ index: Int) {
        guard index < profiles.count else { return }
        switchToProfile(profiles[index])
    }
    
    // MARK: - Persistence
    
    private func loadProfiles() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([PastorProfile].self, from: data) else {
            profiles = [.guest]
            return
        }
        profiles = decoded
    }
    
    private func saveProfiles() {
        guard let encoded = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }
    
    private func loadActiveProfile() {
        guard let idString = UserDefaults.standard.string(forKey: activeProfileKey),
              let id = UUID(uuidString: idString),
              let profile = profiles.first(where: { $0.id == id }) else {
            activeProfile = .guest
            return
        }
        activeProfile = profile
    }
    
    private func saveActiveProfile() {
        UserDefaults.standard.set(activeProfile?.id.uuidString, forKey: activeProfileKey)
    }
}

extension Notification.Name {
    static let pastorProfileChanged = Notification.Name("pastorProfileChanged")
}
```

### Integration with Bible Service

```swift
// BibleService.swift (updated)
class BibleService: ObservableObject {
    @Published var currentTranslation: BibleTranslation = .kjv
    
    private var profileManager: PastorProfileManager
    private var cancellables = Set<AnyCancellable>()
    
    init(profileManager: PastorProfileManager) {
        self.profileManager = profileManager
        
        // Listen for profile changes
        NotificationCenter.default.publisher(for: .pastorProfileChanged)
            .compactMap { $0.object as? PastorProfile }
            .sink { [weak self] profile in
                self?.switchTranslation(to: profile.preferredTranslation)
            }
            .store(in: &cancellables)
        
        // Set initial translation from active profile
        if let active = profileManager.activeProfile {
            currentTranslation = active.preferredTranslation
        }
    }
    
    func switchTranslation(to translation: BibleTranslation) {
        currentTranslation = translation
        // Reload Bible database if needed
        loadBibleDatabase(for: translation)
    }
    
    private func loadBibleDatabase(for translation: BibleTranslation) {
        // Load appropriate SQLite database
        let dbName = "\(translation.rawValue.lowercased())_bible.db"
        // ... database loading logic
    }
}
```

### UI: Profile Selector

```swift
// ProfileSelectorView.swift
struct ProfileSelectorView: View {
    @ObservedObject var profileManager: PastorProfileManager
    @State private var showingProfileEditor = false
    @State private var editingProfile: PastorProfile?
    
    var body: some View {
        Menu {
            // Profile list
            ForEach(profileManager.profiles) { profile in
                Button(action: { profileManager.switchToProfile(profile) }) {
                    HStack {
                        if profile.id == profileManager.activeProfile?.id {
                            Image(systemName: "checkmark")
                        }
                        Text(profile.name)
                        Text("(\(profile.preferredTranslation.rawValue))")
                            .foregroundColor(.secondary)
                    }
                }
                .keyboardShortcut(shortcutKey(for: profile))
            }
            
            Divider()
            
            // Management options
            Button("Manage Profiles...") {
                showingProfileEditor = true
            }
            
        } label: {
            HStack(spacing: 6) {
                // Profile avatar
                ProfileAvatarView(profile: profileManager.activeProfile ?? .guest)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(profileManager.activeProfile?.name ?? "Guest")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(profileManager.activeProfile?.preferredTranslation.rawValue ?? "KJV")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(6)
        }
        .sheet(isPresented: $showingProfileEditor) {
            ProfileManagementView(profileManager: profileManager)
        }
    }
    
    func shortcutKey(for profile: PastorProfile) -> KeyEquivalent? {
        guard let index = profileManager.profiles.firstIndex(where: { $0.id == profile.id }),
              index < 9 else { return nil }
        return KeyEquivalent(Character("\(index + 1)"))
    }
}

struct ProfileAvatarView: View {
    let profile: PastorProfile
    
    var body: some View {
        if let photoData = profile.photoData,
           let nsImage = NSImage(data: photoData) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                Text(profile.name.prefix(1).uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
            }
        }
    }
}
```

### UI: Profile Management

```swift
// ProfileManagementView.swift
struct ProfileManagementView: View {
    @ObservedObject var profileManager: PastorProfileManager
    @State private var showingAddProfile = false
    @State private var editingProfile: PastorProfile?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Pastor Profiles")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddProfile = true }) {
                    Image(systemName: "plus")
                }
            }
            .padding()
            
            Divider()
            
            // Profile list
            List {
                ForEach(profileManager.profiles) { profile in
                    ProfileRowView(
                        profile: profile,
                        isActive: profile.id == profileManager.activeProfile?.id,
                        onEdit: { editingProfile = profile },
                        onDelete: { profileManager.deleteProfile(profile) }
                    )
                }
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("Keyboard shortcuts: ⌘1 through ⌘9")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .sheet(isPresented: $showingAddProfile) {
            ProfileEditorView(profileManager: profileManager)
        }
        .sheet(item: $editingProfile) { profile in
            ProfileEditorView(profileManager: profileManager, existingProfile: profile)
        }
    }
}

struct ProfileRowView: View {
    let profile: PastorProfile
    let isActive: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            ProfileAvatarView(profile: profile)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading) {
                HStack {
                    Text(profile.name)
                        .fontWeight(isActive ? .bold : .regular)
                    if isActive {
                        Text("Active")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
                Text(profile.preferredTranslation.fullName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if profile.id != PastorProfile.guest.id {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
```

### UI: Profile Editor

```swift
// ProfileEditorView.swift
struct ProfileEditorView: View {
    @ObservedObject var profileManager: PastorProfileManager
    var existingProfile: PastorProfile?
    
    @State private var name: String = ""
    @State private var translation: BibleTranslation = .kjv
    @State private var notes: String = ""
    @State private var photoData: Data?
    
    @Environment(\.dismiss) var dismiss
    
    var isEditing: Bool { existingProfile != nil }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(isEditing ? "Edit Profile" : "New Pastor Profile")
                .font(.headline)
            
            // Photo picker
            PhotoPickerButton(photoData: $photoData)
            
            Form {
                TextField("Pastor Name", text: $name)
                
                Picker("Preferred Translation", selection: $translation) {
                    ForEach(BibleTranslation.allCases, id: \.self) { trans in
                        Text("\(trans.rawValue) - \(trans.fullName)").tag(trans)
                    }
                }
                
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                
                Spacer()
                
                Button(isEditing ? "Save" : "Create") {
                    saveProfile()
                    dismiss()
                }
                .keyboardShortcut(.return)
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 350)
        .onAppear {
            if let existing = existingProfile {
                name = existing.name
                translation = existing.preferredTranslation
                notes = existing.notes ?? ""
                photoData = existing.photoData
            }
        }
    }
    
    func saveProfile() {
        if var existing = existingProfile {
            existing.name = name
            existing.preferredTranslation = translation
            existing.notes = notes.isEmpty ? nil : notes
            existing.photoData = photoData
            profileManager.updateProfile(existing)
        } else {
            var newProfile = PastorProfile(name: name, translation: translation)
            newProfile.notes = notes.isEmpty ? nil : notes
            newProfile.photoData = photoData
            profileManager.addProfile(newProfile)
        }
    }
}
```

---

## UI Mockup

### Profile Selector (Menu Bar)

```
┌──────────────────────────────────────────────────────────────────┐
│ [🎤 Listening] [📖 John 3:16]    [👤 Pastor John ▼] [KJV]       │
└──────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
                          ┌─────────────────────────────┐
                          │ ✓ 👤 Pastor John (KJV)  ⌘1  │
                          │   👤 Pastor Sarah (NIV) ⌘2  │
                          │   👤 Pastor Mike (ESV)  ⌘3  │
                          │   👤 Guest Speaker      ⌘4  │
                          ├─────────────────────────────┤
                          │   Manage Profiles...        │
                          └─────────────────────────────┘
```

### Profile Management Sheet

```
┌─────────────────────────────────────────────────────────────────┐
│ Pastor Profiles                                          [+]    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  [👤] Guest Speaker                                              │
│       King James Version                                         │
│                                                                  │
│  [📷] Pastor John                            [Active] [✏️] [🗑️] │
│       King James Version                                         │
│       "Senior pastor, prefers traditional language"              │
│                                                                  │
│  [📷] Pastor Sarah                                  [✏️] [🗑️]   │
│       New International Version                                  │
│       "Youth pastor, uses modern translations"                   │
│                                                                  │
│  [📷] Pastor Mike                                   [✏️] [🗑️]   │
│       English Standard Version                                   │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│ Keyboard shortcuts: ⌘1 through ⌘9                      [Done]   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘1 | Switch to Profile 1 |
| ⌘2 | Switch to Profile 2 |
| ⌘3 | Switch to Profile 3 |
| ⌘4 | Switch to Profile 4 |
| ⌘5-9 | Profiles 5-9 |

---

## Future Enhancements

- **Pastor-specific speech patterns**: Learn common phrases each pastor uses
- **Usage analytics**: Track which pastor uses the app most
- **Cloud sync**: Sync profiles via iCloud or Supabase
- **Quick switch widget**: Touch Bar / Menu Bar extra for faster switching
- **Auto-detect pastor**: Use voice recognition to auto-select profile

---

## Dependencies

- Story 2.4 (Bible Translation Support) ✅ Complete
- Story 7.1 (Reference Buffer) - Optional integration

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] PastorProfile model implemented
- [ ] PastorProfileManager service complete
- [ ] Profile CRUD operations working
- [ ] Quick-switch in UI
- [ ] Keyboard shortcuts (⌘1-9) working
- [ ] Translation changes on profile switch
- [ ] Profiles persist across restarts
- [ ] Guest profile always available
- [ ] UI shows active profile
- [ ] Committed to Git

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Profile data loss | Low | High | Backup/export feature |
| Too many profiles | Low | Low | Limit to 9 (keyboard shortcuts) |
| Wrong profile active | Low | Medium | Clear visual indicator |

---

## Estimated Effort

| Task | Hours |
|------|-------|
| PastorProfile model | 1 |
| ProfileManager service | 3 |
| Profile selector UI | 2 |
| Profile management sheet | 3 |
| Profile editor | 2 |
| Keyboard shortcuts | 1 |
| Persistence | 1 |
| Testing | 2 |
| **Total** | **15** |

---

## Notes

- This is a **key retention feature**
- Profiles create switching costs - once set up, churches won't leave
- Keep the UI simple - pastors/admins shouldn't need training
- Consider adding "Import/Export" for backing up profiles
