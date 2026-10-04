# Calm Check Implementation Plan

> Executed inline (superpowers:executing-plans) by the same author. Tasks list interfaces and test cases; code is written test-first during execution.

**Goal:** Camera heart reading, tension self-report with Apple Health State of Mind, and breathing-pace estimate around wind-downs.

**Spec:** `docs/superpowers/specs/2026-10-04-calm-check-design.md`

## Global Constraints

- iOS 17 floor; State of Mind behind `#available(iOS 18, *)`. No new dependencies.
- All three features off by default; never shown as stress/anxiety; never feed progress, stars or Lumi's mood.
- Raw frames and audio are never stored; only the derived numbers.
- Body estimates and self-reports always shown separately and labelled.
- Nothing runs without a user tap; nothing at night is triggered by an estimate.
- Test command: `scripts/test-app.sh -only-testing:StillmoonTests[/Suite]`.

## Review Focus

1. Finger not on the lens / moving: "unclear", never a number (PulseAnalyzer tests).
2. Noisy room: no breathing number (BreathAnalyzer tests).
3. Sleep session running: breathing listener unavailable (PlayerBreathing gate test).
4. Older payloads and stores: settings decode, V2 → V3 store opens (tests).
5. State of Mind on iOS 17 or Health off: no crash, nothing written (fake + availability).

### Task 1: Pure analyzers
- Create `App/Stillmoon/Body/PulseAnalyzer.swift`: `struct PulseFrame { r, g, b: Double }`; `enum PulseResult: Equatable { case reading(bpm: Double, hrv: Double), unclear(PulseIssue) }`; `enum PulseIssue { noFinger, tooShort, noisy }`; `PulseAnalyzer.isCovering(_ frame:) -> Bool`; `PulseAnalyzer.analyze(_ frames: [PulseFrame], fps: Double) -> PulseResult`.
- Create `App/Stillmoon/Body/BreathAnalyzer.swift`: `BreathAnalyzer.rate(envelope: [Double], sampleRate: Double) -> Double?`; `BreathAnalyzer.rms(_ samples: [Float]) -> Double`.
- Tests `PulseAnalyzerTests`, `BreathAnalyzerTests`: 72 bpm and 55 bpm synthetic pulses → within ±2; known alternating intervals → RMSSD within 10%; uncovered frames → noFinger; 10 s → tooShort; white noise → noisy; irregular intervals → noisy. 9/min and 15/min envelopes → ±1; flat → nil; noise → nil; 10 s → nil.

### Task 2: Storage
- `CalmCheck` value + `CalmCheckRecord`; `StillmoonSchemaV3`; migration stage V2 → V3; health configuration includes the record.
- `LocalStore.saveCalmCheck(_:)` (upsert by id), `calmChecks(from:to:)`, deletion in `deleteAllData()`.
- Tests: round-trip and upsert, owner isolation, delete-all, an on-disk V2 store opens with V3.

### Task 3: Settings, State of Mind
- `AppSettings`: `calmCheckEnabled`, `breathListeningEnabled`, `stateOfMindEnabled` (decode defaults false).
- `StateOfMindMapping.valence(tension:)`, `.isCalm/.isStressed` per spec.
- `HealthDataSource.requestStateOfMindAuthorization()`, `saveStateOfMind(tension:at:)`; `HealthKitService` (iOS 18 only), `FakeHealthSource` records.
- Tests: mapping table, old payload decodes, fake records saves.

### Task 4: Calm-check flow + camera
- `CalmCheckFlow` (@Observable, pure state): phases `.before`, `.exercise`, `.after`, `.done`; records pulse/tension/breaths; `resultLines` (heart rate, tension, breathing) and `check` (CalmCheck?) for saving.
- `PulseCamera` (AVCapture, torch, 45 s, center-region average per frame) with `isAvailable`; `CalmCheckView` (tension row + camera step + result / unclear / skip).
- Player: shows the before step when enabled and the exercise is a wind-down; "Check again" on completion and quiet ending; saves the calm check on dismiss; completion shows result lines. Info.plist camera string.
- Tests: flow phases and skip paths; result lines formatting ("Heart rate 78 → 66 bpm", "You felt tense 4 → 2", "Breathing about 14 → 8 a minute"); nothing saved when every step was skipped.

### Task 5: Breathing listener
- `BreathListener` (AVAudioEngine envelope, 30 s window, publishes `rate`), gate `BreathGate.canListen(enabled:soundSessionActive:category:)`.
- Player shows the estimate; flow keeps first and last clear rates.
- Tests: gate truth table; flow keeps first/last rates and ignores nils.

### Task 6: Settings UI, Sleep detail, PRD
- Settings section "Calm check" with the three toggles (permission prompts on turning on).
- `NightRow.calmChecks`, SleepModel fills it for the evening window; NightDetailView "Before bed" section.
- PRD amendment v1.3.
- Tests: SleepModel attaches calm checks to the right night.
- Full suite + UI tests; simulator smoke.
