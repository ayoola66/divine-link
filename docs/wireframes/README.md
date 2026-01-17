# Divine Link - Wireframes

**Document Type:** UI Wireframes  
**Version:** 1.0  
**Date:** January 2026  
**Status:** Ready for Design

---

## Overview

This folder contains wireframe specifications for Divine Link in multiple formats:

| File | Format | Use With |
|------|--------|----------|
| `ascii-wireframes.md` | ASCII text layouts | Reference / AI prompts |
| `figma-prompts.md` | Natural language prompts | Figma AI / Make feature |
| `screen-specs.md` | Detailed specifications | Manual design / developers |

---

## Screens to Design

| # | Screen | Priority | Description |
|---|--------|----------|-------------|
| 1 | Main Window - Listening | High | Default state, empty buffer |
| 2 | Main Window - Pending Verse | High | Scripture detected, awaiting action |
| 3 | Main Window - Paused | Medium | Muted state, listening stopped |
| 4 | Main Window - Push Success | Medium | Brief success indicator |
| 5 | Settings - Audio | High | Input device selection |
| 6 | Settings - ProPresenter | High | Connection configuration |
| 7 | Settings - About | Low | App info and version |
| 8 | Menu Bar States | Medium | Icon variations |
| 9 | Error States | Medium | Connection lost, permission denied |
| 10 | Onboarding - Audio Setup | Medium | First-run wizard |

---

## Design System Quick Reference

### Colours

| Name | Hex | Use |
|------|-----|-----|
| Divine Blue | `#2563EB` | Scripture text, listening indicator |
| Divine Gold | `#D4AF37` | Push button, pending border |
| Calm Blue | `#3B82F6` | Listening pulse |
| Off-White | `#F8F8F8` | Card background |
| Near-Black | `#1F2937` | Primary text |
| Grey | `#6B7280` | Secondary text |
| Muted Grey | `#9CA3AF` | Paused state |
| Success Green | `#22C55E` | Connected, success |
| Error Red | `#DC2626` | Disconnected, errors |
| Warning Amber | `#F59E0B` | Reconnecting |

### Typography

| Element | Font | Size | Weight |
|---------|------|------|--------|
| Scripture text | SF Pro | 18pt | Regular |
| Scripture reference | SF Pro | 24pt | Semibold |
| Status text | SF Pro | 14pt | Medium |
| Transcript | SF Mono | 13pt | Regular |
| Button labels | SF Pro | 16pt | Semibold |
| Captions | SF Pro | 12pt | Regular |

### Spacing

| Name | Value |
|------|-------|
| xs | 4px |
| sm | 8px |
| md | 16px |
| lg | 24px |
| xl | 32px |

### Corner Radius

| Element | Radius |
|---------|--------|
| Buttons | 10px |
| Cards | 12px |
| Input fields | 8px |
| Indicators | 4px |

---

## How to Use These Wireframes

### With Figma AI (Make)

1. Open Figma → Create new file
2. Press ⌘+K (Mac) or Ctrl+K (Windows)
3. Type "Generate" or use `/generate`
4. Paste the prompt from `figma-prompts.md`
5. Refine as needed

### With Cursor AI for Figma Plugin

1. Install the plugin from Figma Community
2. Open the plugin
3. Paste the ASCII wireframe or prompt
4. Let it generate the design
5. Adjust styling to match design system

### Manual Design

Use `screen-specs.md` for detailed specifications including:
- Exact dimensions
- Component hierarchy
- State variations
- Interaction notes
