# PROJECT HANDOFF: "Divine Link" - Scripture Automation
**Date:** January 2026
**Status:** Phase 1 (Analysis) Kickoff
**Context:** This project has been upgraded to a **BMAD Level 3: Complex System**. 

---

## 1. Executive Summary
Development of a macOS application that listens to a live preacher, detects Bible verses (explicit and implicit), and automatically populates/triggers scripture slides in ProPresenter 7+ via network API.

## 2. Technical Consensus (Professor BMAD Synthesis)
The following strategic pillars have been established to balance **User Trust**, **Latency**, and **Commercial Viability**:

* **ASR Strategy:** Local-First Hybrid. 
    * Primary: macOS Native Speech Framework (utilizing 2026 `SpeechAnalyzer` for sub-second latency).
    * Fallback: Swappable ASR interface (e.g., OpenAI Whisper API) for high-complexity accents or low-spec hardware.
* **Correction Layer:** Usage of `SFCustomLanguageModelData` to bias the local AI toward the 66 Bible books and common theological terms (reducing "Habakkuk" vs "Have a cook" errors).
* **Bible Engine:** Local-first SQLite database populated by **HelloAO Bible API** (Free/Public Domain Berean Standard Bible).
* **ProPresenter Integration:** Use of the **Network API** (specifically the `/message` endpoint) to "pour" text into pre-existing branded templates safely.

## 3. The "Human-in-the-Loop" Mandate
Trust is the primary product differentiator.
* **Requirement:** All detected verses must enter a "Pending Buffer" UI.
* **Action:** The operator must click "Push" or hit a hotkey to send the verse to the main screen. No "Auto-Push" without confirmation in the MVP.

## 4. Analyst Instructions (Mary)
Please execute the `*research` workflow to validate and document the following:
1.  **ProPresenter API:** Verify the stability of the `/v1/message` endpoint for real-time text injection on macOS.
2.  **macOS 2026 Speech:** Investigate the latest `SFCustomLanguageModelData` implementation for phrase biasing.
3.  **Licensing:** Confirm the commercial safety of the Berean Standard Bible/HelloAO API for a for-profit SaaS.

---
**Reference Conversation:** Summarized from Professor BMAD V6 Initial Consultation.