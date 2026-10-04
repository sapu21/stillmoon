# Calm check: phone-only body signals around a wind-down

2026-10-04 · Builds on the redesign (branch `redesign-lumi`). Screen Time (evening phone use) is deferred until the paid Apple Developer account is active: a free Personal Team cannot sign the Family Controls entitlement.

## Intent

Let people see their body settle because of something they did, using only an iPhone: a camera heart reading and a "how tense do you feel?" answer before and after a wind-down, an optional breathing-pace estimate during it, and their own answers saved to Apple Health's State of Mind. Everything is a labelled estimate or a self-report; nothing becomes a stress or anxiety label.

## PRD amendment (v1.2 → v1.3)

- New principle 6: **Body signals are estimates.** Heart rate, heart rate variability and breathing pace measured by the phone are shown as "estimate from your phone's camera/microphone", beside (never merged with) what the user reports. They are never turned into stress, anxiety or mood labels, never scored, never rewarded, and never trigger anything at night.
- §3 non-goals keep "diagnosing anxiety"; add "labelling stress or anxiety from body signals".
- §9: calm checks live on the device with the other health data; raw camera frames and audio are never stored.

## Features

**1. Camera heart reading (calm check).** Optional, off by default (Settings › "Offer a calm check"). For wind-down exercises the player opens with "Check your pulse first?" (Start / Skip). The user covers the back camera and flash with a fingertip for 45 s while Lumi breathes. Each frame's average color is reduced to one brightness value; a pure analyzer finds beats and returns heart rate and RMSSD (HRV), or "unclear" when the finger is not covering the lens, the signal is flat or noisy, or beats are irregular. After the exercise the completion screen (day) or the quiet ending (night) offers "Check again". Results read "Heart rate 78 → 66 bpm · estimate from your phone's camera". Not shown on the simulator (no camera).

**2. "How tense do you feel?" + State of Mind.** A 1–5 row (Calm … Very tense) before and after, shown with the calm check (and on its own when the camera reading is skipped). With Settings › "Save how I feel to Apple Health" on (asks for permission when turned on), each answer is written to HealthKit State of Mind as a momentary emotion (iOS 18+; silently skipped below). Write only, never read. Mapping: 1 → valence 0.6, label calm; 2 → 0.3, calm; 3 → 0, no label; 4 → -0.3, stressed; 5 → -0.6, stressed. The label is the user's own answer, not an inference.

**3. Breathing pace.** Optional, off by default (Settings › "Listen to breathing"; asks for the microphone). In the player for wind-down and awake-at-night exercises, when no sleep session is using the microphone. Audio is reduced to a loudness envelope (20 per second); a pure analyzer estimates breaths per minute over the last 30 s, or nothing when unclear. The player shows "About 9 breaths a minute · estimate". The calm check keeps the first and last clear estimates: "Breathing about 14 → 8 a minute".

**Where results appear.** The completion / quiet ending screen, and a "Before bed" section in the night's detail on the Sleep tab listing that evening's calm checks. Never in Today's header, Journey, stars or progress.

## Data

`CalmCheck` (value) / `CalmCheckRecord` (SwiftData, health store, CloudKit-compatible defaults): id, ownerID, exerciseID, at, bpmBefore/After, hrvBefore/After (ms), tenseBefore/After (1–5), breathsStart/End (per minute). Schema V3 adds the record with a lightweight V2 → V3 migration. Delete-all-data removes them.

## Testing

Pure analyzers tested with synthetic signals (clean sine at known rates → correct estimate; flat, noisy, uncovered, irregular → unclear). Store round-trip, owner isolation and deletion. State of Mind mapping. Calm-check flow and result lines. Settings decode of old payloads. Device test on the user's iPhone 15 Pro is the real check for the camera and microphone.
