# Divine Link - Development Stories

**Total Stories:** 28 (across 4 Epics)  
**Completed:** 11 stories (39%)  
**Status:** Epic 2 Complete - Ready for Epic 3

---

## Story Index

### Epic 1: Foundation & Audio Capture (5 Stories)

| # | Story | Complexity | Dependencies |
|---|-------|------------|--------------|
| 1.1 | [Project Scaffolding & Menu Bar App Shell](epic-1/story-1.1-project-scaffolding.md) | Medium | None |
| 1.2 | [Audio Input Device Selection](epic-1/story-1.2-audio-input-selection.md) | Small | 1.1 |
| 1.3 | [Audio Capture Engine](epic-1/story-1.3-audio-capture-engine.md) | Medium | 1.1, 1.2 |
| 1.4 | [Audio Level Monitoring UI](epic-1/story-1.4-audio-level-monitoring.md) | Small | 1.3 |
| 1.5 | [Listening State Management](epic-1/story-1.5-listening-state-management.md) | Small | 1.3, 1.4 |

**Epic 1 Deliverable:** A functional macOS menu bar application that captures and monitors audio input.

---

### Epic 2: Transcription & Scripture Detection (6 Stories)

| # | Story | Complexity | Dependencies |
|---|-------|------------|--------------|
| 2.1 | [Bible Database Setup](epic-2/story-2.1-bible-database-setup.md) | Medium | 1.1 |
| 2.2 | [Speech Recognition Service](epic-2/story-2.2-speech-recognition-service.md) | Medium | 1.3 |
| 2.3 | [Custom Language Model for Bible Vocabulary](epic-2/story-2.3-custom-language-model.md) | Medium | 2.2 |
| 2.4 | [Listening Feed UI](epic-2/story-2.4-listening-feed-ui.md) | Small | 2.2, 1.5 |
| 2.5 | [Scripture Reference Detection Engine](epic-2/story-2.5-scripture-detection-engine.md) | Medium | 2.1 |
| 2.6 | [Detection Pipeline Integration](epic-2/story-2.6-detection-pipeline-integration.md) | Small | 2.1, 2.2, 2.5 |

**Epic 2 Deliverable:** Real-time transcription with Bible vocabulary biasing and scripture detection.

---

### Epic 3: Pending Buffer & ProPresenter Integration (9 Stories)

| # | Story | Complexity | Dependencies |
|---|-------|------------|--------------|
| 3.1 | [Pending Buffer Data Model](epic-3/story-3.1-pending-buffer-data-model.md) | Small | 2.6 |
| 3.2 | [Pending Scripture Card UI](epic-3/story-3.2-pending-scripture-card-ui.md) | Medium | 3.1 |
| 3.3 | [Operator Action Buttons](epic-3/story-3.3-operator-action-buttons.md) | Small | 3.1, 1.5 |
| 3.4 | [Keyboard Shortcut Handling](epic-3/story-3.4-keyboard-shortcut-handling.md) | Small | 3.3 |
| 3.5 | [ProPresenter Connection Settings](epic-3/story-3.5-propresenter-connection-settings.md) | Small | 1.2 |
| 3.6 | [ProPresenter API Client](epic-3/story-3.6-propresenter-api-client.md) | Medium | 3.5 |
| 3.7 | [Push to ProPresenter Action](epic-3/story-3.7-push-to-propresenter-action.md) | Small | 3.1, 3.6 |
| 3.8 | [Connection Status Header](epic-3/story-3.8-connection-status-header.md) | Small | 3.6 |
| 3.9 | [Settings Panel Polish](epic-3/story-3.9-settings-panel-polish.md) | Small | 1.2, 3.5 |

**Epic 3 Deliverable:** Complete MVP with operator workflow and ProPresenter integration.

---

### Epic 4: Service Sessions & Pastor Profiles (7 Stories)

| # | Story | Complexity | Dependencies | Status |
|---|-------|------------|--------------|--------|
| 4.1 | [Service Session Creation](epic-4/story-4.1-service-session-creation.md) | Medium | 2.6 | Not Started |
| 4.2 | [Service Type Suggestions](epic-4/story-4.2-service-type-suggestions.md) | Small | 4.1 | Not Started |
| 4.3 | [Service History Archive](epic-4/story-4.3-service-history-archive.md) | Medium | 4.1 | Not Started |
| 4.4 | [Service History UI](epic-4/story-4.4-service-history-ui.md) | Small | 4.3 | Not Started |
| 4.5 | [Pastor Profile Management](epic-4/story-4.5-pastor-profile-management.md) | Medium | 4.1 | Not Started |
| 4.6 | [Pastor Speech Learning](epic-4/story-4.6-pastor-speech-learning.md) | Large | 4.5, 2.3 | Not Started |
| 4.7 | [Archive Auto-Cleanup](epic-4/story-4.7-archive-auto-cleanup.md) | Small | 4.3 | Not Started |

**Epic 4 Deliverable:** Service session management with pastor-specific speech learning.

---

## Complexity Summary

| Complexity | Count |
|------------|-------|
| Small | 12 |
| Medium | 8 |
| **Total** | **20** |

---

## Recommended Development Order

Stories should be completed in the order listed, respecting dependencies:

```
Epic 1 (Foundation)
├── 1.1 Project Scaffolding ──────────────────────────┐
├── 1.2 Audio Input Selection ◄───────────────────────┤
├── 1.3 Audio Capture Engine ◄────────────────────────┤
├── 1.4 Audio Level Monitoring ◄──────────────────────┤
└── 1.5 Listening State Management ◄──────────────────┘
                                                      │
Epic 2 (Detection)                                    │
├── 2.1 Bible Database ◄──────────────────────────────┤
├── 2.2 Speech Recognition ◄──────────────────────────┤
├── 2.3 Custom Language Model ◄───────────────────────┤
├── 2.4 Listening Feed UI ◄───────────────────────────┤
├── 2.5 Detection Engine ◄────────────────────────────┤
└── 2.6 Pipeline Integration ◄────────────────────────┘
                                                      │
Epic 3 (Integration)                                  │
├── 3.1 Buffer Data Model ◄───────────────────────────┤
├── 3.2 Scripture Card UI ◄───────────────────────────┤
├── 3.3 Action Buttons ◄──────────────────────────────┤
├── 3.4 Keyboard Shortcuts ◄──────────────────────────┤
├── 3.5 PP Connection Settings ◄──────────────────────┤
├── 3.6 PP API Client ◄───────────────────────────────┤
├── 3.7 Push Action ◄─────────────────────────────────┤
├── 3.8 Status Header ◄───────────────────────────────┤
└── 3.9 Settings Polish ◄─────────────────────────────┘
                                                      │
                                                      ▼
                                              🎉 MVP COMPLETE
```

---

## Story File Format

Each story file contains:

1. **User Story** - Who, What, Why format
2. **Acceptance Criteria** - Testable requirements
3. **Technical Notes** - Implementation guidance with code examples
4. **Dependencies** - Prerequisites from other stories
5. **Definition of Done** - Checklist for completion

---

## Next Steps

1. **Wireframes** - Create visual designs before development
2. **Architecture Document** - Detailed technical architecture
3. **Development** - Implement stories in order
4. **Testing** - Verify each story's acceptance criteria
5. **Release** - Package and distribute MVP
