# Epic 4: Service Sessions & Pastor Profiles

## Overview

This epic introduces service session management, historical archive capabilities, and pastor-specific speech learning to improve detection accuracy over time.

## Key Features

1. **Service Sessions** - Create named services with type classification
2. **Service Archive** - Store and retrieve past 3 months of service history
3. **Pastor Profiles** - Track individual pastors and their speaking patterns
4. **Speech Learning** - Learn corrections (e.g., "Some" → "Psalms") per pastor

## Stories

| ID | Story | Complexity | Status |
|----|-------|------------|--------|
| 4.1 | Service Session Creation | Medium | Not Started |
| 4.2 | Service Type Caching & Suggestions | Small | Not Started |
| 4.3 | Service History Archive | Medium | Not Started |
| 4.4 | Service History UI | Small | Not Started |
| 4.5 | Pastor Profile Management | Medium | Not Started |
| 4.6 | Pastor Speech Learning | Large | Not Started |
| 4.7 | Archive Auto-Cleanup (90 days) | Small | Not Started |

## Dependencies

- Epic 2 (Transcription & Detection) - Complete
- Epic 3 (ProPresenter Integration) - In Progress

## Data Retention Policy

- **Service Sessions**: Retained for 90 days, then auto-deleted if not exported
- **Pastor Profiles**: Retained indefinitely (user-managed)
- **Speech Corrections**: Retained with pastor profile
