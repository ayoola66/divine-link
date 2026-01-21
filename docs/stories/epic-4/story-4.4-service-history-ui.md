# Story 4.4: Service History UI

**Epic:** 4 - Service Sessions & Pastor Profiles  
**Story ID:** 4.4  
**Status:** Not Started  
**Complexity:** Small  

---

## User Story

**As an** operator,  
**I want** to browse and review past services,  
**so that** I can see what scriptures were used and learn from past sessions.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | "History" tab or section accessible from main app | Tab visible |
| 2 | List of past services grouped by month | Grouped display |
| 3 | Each service shows: name, date, scripture count | Info visible |
| 4 | Clicking service opens detail view | Navigation works |
| 5 | Detail shows all detected scriptures with timestamps | Full list shown |
| 6 | Detail shows which scriptures were pushed vs ignored | Status indicators |
| 7 | Export button in detail view | Export works |
| 8 | Delete button with confirmation | Delete works |

---

## Technical Notes

### History List View

```swift
struct ServiceHistoryView: View {
    @StateObject private var archive = ServiceArchive.shared
    
    var groupedServices: [String: [ServiceSession]] {
        Dictionary(grouping: archive.sessions) { session in
            session.date.formatted(.dateTime.month(.wide).year())
        }
    }
    
    var body: some View {
        List {
            ForEach(groupedServices.keys.sorted().reversed(), id: \.self) { month in
                Section(month) {
                    ForEach(groupedServices[month] ?? []) { session in
                        NavigationLink(destination: ServiceDetailView(session: session)) {
                            ServiceRow(session: session)
                        }
                    }
                }
            }
        }
        .navigationTitle("Service History")
    }
}

struct ServiceRow: View {
    let session: ServiceSession
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(session.name)
                .font(.headline)
            HStack {
                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                Spacer()
                Text("\(session.detectedScriptures.count) scriptures")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
```

### Service Detail View

```swift
struct ServiceDetailView: View {
    let session: ServiceSession
    @StateObject private var archive = ServiceArchive.shared
    
    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Date", value: session.date.formatted())
                LabeledContent("Type", value: session.serviceType)
                if let pastor = session.pastor {
                    LabeledContent("Pastor", value: pastor.name)
                }
            }
            
            Section("Detected Scriptures") {
                ForEach(session.detectedScriptures) { scripture in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(scripture.reference)
                                .font(.headline)
                            Text(scripture.timestamp.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                        }
                        Spacer()
                        if scripture.wasPushed {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "xmark.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .toolbar {
            Button("Export") { /* export */ }
            Button("Delete", role: .destructive) { /* delete */ }
        }
    }
}
```

---

## Dependencies

- Story 4.3 (Service History Archive)

---

## Definition of Done

- [ ] History list displays services
- [ ] Grouping by month works
- [ ] Detail view shows all info
- [ ] Export and delete work
- [ ] Committed to Git
