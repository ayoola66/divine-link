# Divine Link — Release Hygiene Resolution Plan

**Date:** 2026-04-04
**Status:** Awaiting Approval
**Scope:** Fix version drift, stale docs, unpushed commits, and Xcode toolchain

---

## Problem Summary

Three rapid-fire bug-fix releases (v1.3.6, v1.3.7, v1.3.8) were shipped correctly through the Sparkle/appcast pipeline, but the surrounding documentation and version files were not updated. This creates confusion about what version is current and what issues are resolved.

### Current State (Verified)

| Truth Source | Says | Should Say | Status |
|---|---|---|---|
| Xcode `project.pbxproj` | v1.3.8 / build 14 | v1.3.8 | Correct |
| `appcast.xml` (Netlify) | v1.3.8 latest | v1.3.8 | Correct |
| `VERSION` file | 1.3.5 | 1.3.8 | **Stale** |
| `CHANGELOG.md` | Stops at 1.3.5 | Through 1.3.8 | **Stale** |
| `PROJECT_STATUS.md` | v1.0.2 | v1.3.8 | **Very stale** |
| `docs/development-log.md` | Audio capture: "Open" | Should be "Resolved" | **Stale** |
| `docs/analysis/audio-capture-issues-and-fixes.md` | Header says resolved | Consistent | Needs alignment with dev-log |
| Git (local main) | 3 commits ahead of origin | Should be pushed | **Unpushed** |
| Working tree | Modified + deleted files | Should be triaged | **Dirty** |

---

## Execution Plan

### Phase 1 — Local Doc Fixes (Safe, No Side Effects)

**Step 1.1: Update `VERSION` file**
- Change `1.3.5` to `1.3.8`
- One-line change, zero risk

**Step 1.2: Add CHANGELOG entries for v1.3.6, v1.3.7, v1.3.8**
- Source content from git commit messages + appcast.xml descriptions (both verified)
- Insert above the existing v1.3.5 entry
- v1.3.6: Transcription fallback fix (on-device → server-based recognition)
- v1.3.7: Audio device switch fix + BlackHole wording
- v1.3.8: External device transcription fix (RunLoop stall on background thread)

**Step 1.3: Update `PROJECT_STATUS.md`**
- Change current version from 1.0.2 to 1.3.8
- Update phase statuses to reflect completed work (Sparkle, Supabase auth, Stripe, ads, audio fixes)
- Keep the document structure, just update the facts

**Step 1.4: Fix `docs/development-log.md`**
- Change audio capture issue status from "Open (Investigating)" to "Resolved"
- Add resolution note referencing the fixes in v1.3.5 through v1.3.8
- Keep the original investigation detail intact (valuable for future debugging)

**Step 1.5: Align `docs/analysis/audio-capture-issues-and-fixes.md`**
- Ensure "Status" line in header consistently says "Resolved" with date
- No other changes needed — the document body already documents the fixes

### Phase 2 — Triage Working Tree Changes

**Step 2.1: Review uncommitted changes**

The working tree has three categories of changes:

| Category | Files | Recommendation |
|---|---|---|
| **Website HTML** (modified) | `index.html`, `admin.html`, `cancel.html`, `privacy.html`, `releases.html`, `success.html`, `terms.html` | Review and commit if intentional (likely from landing page revamp) |
| **Deleted BMAD files** | `.claude/commands/bmad-cw/*`, `.claude/commands/bmadInfraDevOps/*`, deleted docs/wireframe images | These appear replaced by new BMAD structure (new untracked files exist). Commit deletions + additions together |
| **Swift source changes** | `BibleVocabularyData.swift`, `ImplicitReferenceDetector.swift`, `HybridIntegrationManager.swift`, `ProPresenterSettingsView.swift`, `BibleLanguageModel.swift`, `DivineLink.entitlements` | Review — these may be in-progress Epic 8 work. **Ask Ayo before committing** |
| **Untracked new files** | `.agent/`, `.agents/`, new `.claude/commands/bmad-*`, `.claude/skills/`, marketing/, epic-8 docs | Triage: commit project files, gitignore tool-local dirs |

**Step 2.2: Decision needed from Ayo**
- Are the Swift source changes ready to commit, or is this in-progress work?
- Are the website HTML changes final?
- Should `.agent/`, `.agents/`, `.playwright-cli/` be gitignored?

### Phase 3 — Commit and Push

**Step 3.1: Commit doc fixes**
- Stage only: `VERSION`, `CHANGELOG.md`, `PROJECT_STATUS.md`, `docs/development-log.md`, `docs/analysis/audio-capture-issues-and-fixes.md`
- Commit message: `docs: align version files and docs with v1.3.8 release`

**Step 3.2: (After Ayo's triage) Commit working tree changes**
- Separate commit(s) for website changes, BMAD restructure, and Swift changes as appropriate

**Step 3.3: Push to origin/main**
- This triggers Netlify auto-deploy
- The 3 existing release commits (v1.3.6, v1.3.7, v1.3.8) + our doc fix commit will all push together
- If website HTML changes are committed, they deploy too — verify they're ready

### Phase 4 — Xcode Toolchain Diagnosis

**Step 4.1: Run `xcodebuild -runFirstLaunch`**
- Downloads missing simulator runtimes and components
- Fixes `IDESimulatorFoundation` / `DVTDownloads` framework mismatch

**Step 4.2: Verify with `xcodebuild -list`**
- Confirm project and schemes are recognized
- If still failing, may need Xcode Command Line Tools reinstall: `xcode-select --install`

**Step 4.3: (If needed) Test archive build**
- `xcodebuild -scheme DivineLink -configuration Release archive`
- Confirms the full release pipeline still works locally

### Phase 5 — Update PAI Memory

**Step 5.1: Update `divine-link.md`**
- Current state: v1.3.8 / build 14
- Latest appcast entry: 1.3.8 with valid edSignature
- Release pipeline status: all docs now aligned
- Note: no Swift tests exist — regression relies on manual validation

---

## Risk Mitigation

| Risk | Mitigation |
|---|---|
| Push deploys broken website | Review HTML changes before pushing; can rollback via Netlify dashboard |
| Committing in-progress Swift code | Ask Ayo first; stage only confirmed files |
| CHANGELOG entries inaccurate | Source exclusively from git commits + appcast (verified sources) |
| Xcode fix requires reinstall | Try `xcodebuild -runFirstLaunch` first; escalate only if needed |

## Success Criteria

- All version truth sources agree on v1.3.8
- CHANGELOG has accurate entries for all shipped versions
- No documentation marks resolved issues as open
- All commits pushed to origin
- Working tree is clean or has only intentionally-uncommitted work
- Xcode can at minimum list project schemes
