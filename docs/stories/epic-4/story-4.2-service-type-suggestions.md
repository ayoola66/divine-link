# Story 4.2: Service Type Caching & Suggestions

**Epic:** 4 - Service Sessions & Pastor Profiles  
**Story ID:** 4.2  
**Status:** Not Started  
**Complexity:** Small  

---

## User Story

**As an** operator,  
**I want** the app to remember service types I've used before,  
**so that** I can quickly select from past types when starting a new service.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Typing in service type field shows matching past types | Dropdown appears |
| 2 | Most recent types appear first | Order correct |
| 3 | Selecting suggestion fills the field | Selection works |
| 4 | New types are cached for future use | Appears in next session |
| 5 | Cache persists across app restarts | Still available after relaunch |
| 6 | Maximum 20 types cached (oldest removed) | Limit enforced |

---

## Technical Notes

### Autocomplete UI

```swift
struct ServiceTypeField: View {
    @Binding var text: String
    @StateObject private var cache = ServiceTypeCache.shared
    @State private var showSuggestions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Service Type", text: $text)
                .onChange(of: text) { _, _ in
                    showSuggestions = !text.isEmpty
                }
            
            if showSuggestions {
                ForEach(cache.suggestions(for: text), id: \.self) { suggestion in
                    Button(suggestion) {
                        text = suggestion
                        showSuggestions = false
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
```

### Storage

- Use `@AppStorage` or `UserDefaults` for simple persistence
- Key: `"cachedServiceTypes"`

---

## Dependencies

- Story 4.1 (Service Session Creation)

---

## Definition of Done

- [ ] Autocomplete suggestions work
- [ ] Cache persists across restarts
- [ ] Recent types prioritised
- [ ] Committed to Git
