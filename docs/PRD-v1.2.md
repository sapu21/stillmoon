# Stillmoon — Product Requirements Document v1.2

2026-10-02 · Living copy: https://claude.ai/code/artifact/6ee2ae28-725e-4a6b-b83e-49c0e614b1f7 (the doc is the source of truth; refresh this file when it changes)

Stillmoon is a free iOS sleep app that helps adults understand their nights and pick one calm next step, with health data kept on the user's device.

**Version:** 1.2 · **Platform:** iOS 17+ · **Stack:** SwiftUI, SwiftData + CloudKit, HealthKit, Sound Analysis, Supabase · **Market:** United States, English · **Team:** solo founder, no fixed deadline

## What changed from v1.1

| Area | v1.1 | v1.2 |
| --- | --- | --- |
| Backend | FastAPI + PostgreSQL storing sleep data | Supabase (Postgres, auth, storage); no health data on the server |
| Health data | Synced to server | On device, optional iCloud sync to the user's private CloudKit database |
| Accounts | Required, unspecified provider | Required; Sign in with Apple and Google |
| Sound detection | Must, but Phase 2 pilot | v1 for everyone, behind a remote flag and an internal quality gate |
| Recommendations | Server rule service | On-device rules |
| Editorial | Ingestion pipeline + admin service | Hand-written Markdown articles; no pipeline |
| Exercises | Unspecified | Public techniques rewritten in Stillmoon's voice; TTS audio at launch |
| Illustrations | Original, unspecified | Generated with Higgsfield from a locked style kit, then hand-finished |
| Business model | Open | Free; content carries a `tier` field for later |

## 1. Product vision

Stillmoon helps users understand their sleep patterns and choose small, practical actions that may improve their sleep routine. It combines Apple Health sleep data, optional bedside sound-event detection, a short morning check-in, guided exercises, an editorial library and gentle habit-based progress.

**Promise:** Understand your nights. Find a calmer next step.

### Product principles

1. **We never wake you.** Every nighttime intervention is user-initiated. No notification, sound or vibration is ever triggered by an inference about stage, stress or emotion.
2. **Your nights stay yours.** Sleep, sound, check-in and journal data never leave the device except through the user's own iCloud.
3. **Observations are not feelings.** Device estimates and the user's own reports are always shown separately and labelled.
4. **Every suggestion has a reason.** No recommendation appears without a plain-language explanation.
5. **Reward habits, not biology.** Progress comes from things the user does, never from sleep metrics they cannot control.
6. **Body signals are estimates.** *(Amendment 2026-10-04, calm check.)* Heart rate, heart rate variability and breathing pace measured by the phone are shown as "estimate from your phone's camera/microphone", beside (never merged with) what the user reports. They are never turned into stress, anxiety or mood labels, never scored or rewarded, and never trigger anything at night.

### What the product does not claim

Stillmoon cannot keep a user in a particular sleep stage, diagnose anxiety from speech or movement, or diagnose a sleep disorder. Wearable sleep stages are estimates and are presented as such.

## 2. Design

Headspace is the reference for interaction patterns and emotional tone only; Stillmoon uses its own artwork, icons, copy, palette and compositions.

| Element | Direction |
| --- | --- |
| Day palette | Warm off-white, muted lavender, soft coral, deep ink text |
| Night palette | Navy and plum surfaces, restrained lavender highlights |
| Cards | Rounded, spacious, clearly separated |
| Charts | Quiet colours, readable labels, explanations beside estimates |
| Typography | Native iOS type with Dynamic Type |
| Motion | Slow transitions; Reduce Motion respected |
| Night interaction | Low brightness, minimal text, large controls, no celebratory animation |

Illustrations: generated with Higgsfield from a locked style kit (4–6 reference images), prompt log per asset, every shipped image hand-finished. Launch set: 4 category cards, onboarding scenes, a 6-stage journey path, day and night Today headers. Never prompt with another brand's name or artwork.

## 3. Problem, goals and users

Stillmoon answers three questions and keeps their answers separate: What did my devices observe? How did I actually feel? What is one useful thing I can try?

Non-goals for v1: diagnosing any condition; labelling stress or anxiety from body signals; identifying a speaker, transcribing or storing audio; waking users for any inferred reason or a smart alarm; real-time stage detection; storing health data on Stillmoon servers; Android, Watch app, paid tier.

Users: adults who struggle to unwind or wake at night; wearable owners wanting explanation; iPhone-only users (never imply the phone measured sleep stages).

## 4. Platform decisions

| Decision | Choice |
| --- | --- |
| Platform | iOS only, iOS 17+ |
| Wearables | Apple Watch optional; HealthKit data is an enhancement |
| Health data storage | On device (SwiftData), optional iCloud sync via the user's private CloudKit database |
| Backend | Supabase: Postgres, Auth, Storage |
| Recommendations | On-device rules |
| Content delivery | Launch content bundled; updates from Supabase Storage as a JSON manifest + audio |
| Market | United States, English |
| Price | Free; content carries a `tier` field |

HealthKit sleep samples (awake, core, deep, REM, unspecified) build the morning report. They are not a live stream, and may be unavailable while the phone is locked.

## 5. Information architecture and journeys

| Tab | Purpose | Primary action |
| --- | --- | --- |
| Today | Last night's summary and one next step | Start the recommended exercise |
| Sleep | Nightly records and weekly patterns | Review last night |
| Exercises | Guided practices and articles | Find support |
| Journey | Progress only | Review the week |

Settings (profile button, top right of Today): account, permissions, sound detection, iCloud sync, analytics opt-in, goal, bedtime and wake time, notifications, export, delete data, delete account.

Onboarding: 1) purpose; 2) Sign in with Apple or Google (required), screen says "Keeps your progress, saved exercises and journey safe across devices. Your sleep data stays on your phone."; 3) goal: unwind, understand sleep, handle waking at night, build consistency; 4) bedtime and wake time (skippable; defaults 10pm and 7am); 5) Apple Health: read sleep, write Mindful Minutes; 6) microphone separately; 7) privacy summary; 8) start an exercise even if every permission was declined.

Before bed: one wind-down with reason; start, save or pick another; visible sound session if enabled (phone on stable surface, ideally charging); night mode.

During the night: wearable records; with consent the iPhone classifies snoring-, speech- and cough-like sounds storing label, time, confidence only; no notification from inference; opening the app shows an "Awake at night?" card.

Morning: import Health data; report with timeline, gaps, source labels, sound events; restedness check-in and note; one suggestion with reason; rate helpful, irrelevant or unwanted.

## 6. Functional requirements

| ID | Requirement | Acceptance condition | Priority |
| --- | --- | --- | --- |
| FR-01 | Account | Sign in with Apple or Google before use; sign out; delete account in-app | Must |
| FR-02 | Permissions | Health and microphone permissions are separate, optional and explained | Must |
| FR-03 | Manual journal | Record sleep and restfulness with no device permissions | Must |
| FR-04 | HealthKit import | Import sleep samples with timestamps and source | Must |
| FR-05 | Nightly report | Sleep window, estimated duration, available stages, gaps, journal entries | Must |
| FR-06 | Sound events | On-device session detects snoring-, speech- and cough-like events; user can mark each incorrect or someone else | Must, behind launch gate |
| FR-07 | Exercise library | Browse, search, save, start, pause, complete | Must |
| FR-08 | Articles | Read original summaries with credited source links and review date | Must |
| FR-09 | Recommendations | One to three on-device suggestions, each with a plain-language reason | Must |
| FR-10 | Recommendation feedback | Rate relevance; suppress unwanted items | Must |
| FR-11 | Gentle progress | Weekly goal and journey path from completions | Must |
| FR-12 | Privacy controls | Pause sound detection, toggle iCloud sync, export, delete data, delete account | Must |
| FR-15 | iCloud sync | Health and journal data sync through the user's private CloudKit database; toggle in Settings | Must |
| FR-16 | Mindful Minutes | Completed exercises written to Apple Health when permitted; never read | Must |
| FR-17 | Wind-down reminder | Optional, off by default, sent at bedtime minus 30 minutes | Should |
| FR-18 | Remote flags | Features such as sound detection can be switched off remotely | Must |
| FR-13 | Apple Watch companion | Session status and selected exercises | Later |
| FR-14 | Smart alarm | Research only | Research |

Sound detection launch gate: labels snoring-like, speech-like, cough-like; 2–3 weeks across about 10 real bedrooms on the oldest supported iPhone; pass bar fewer than 1 in 5 events marked incorrect or someone else, acceptable battery and heat over 8 hours on charge; warn below 30% battery when not charging; if it misses, launch with the feature off by remote flag.

## 7. Screens

| Screen | Contents |
| --- | --- |
| Today | Greeting and illustration; last-night card; "How do you feel?" check-in; one recommended action with reason; current wind-down; weekly-goal preview; profile button |
| Sleep | Night selector; timeline with available stages; sound-event markers on a separate lane; "Recorded by" labels; missing-data and low-confidence explanations; check-in and notes; weekly patterns from several nights only |
| Exercises | Wind Down, Awake at Night, Morning Reset, Learn; search; saved; duration and format labels; article cards with source and review date |
| Journey | Completions; weekly goal; illustrated path; weekly reflection; hide-progress toggle |
| Exercise player | Dim; large play and pause; audio first; duration and exit; no reward animation at night |
| Sound session | Running state; mic indicator explanation; pause and stop; battery warning |

Night mode: on when a sleep session is active, or time is between bedtime minus 1 hour and wake time (defaults 9pm to 7am). Manual toggle overrides. Nothing inferred from sensors.

Notifications: only an optional wind-down reminder at bedtime minus 30 minutes, off by default, offered after the first completed wind-down.

## 8. Content, recommendations and progress

Exercises: techniques from public sources, scripts in Stillmoon's voice. Allowed: US federal works, CC0, CC-BY with credit. Not allowed: CC-NC, YouTube/podcast audio, other apps' scripts. TTS audio at launch. Metadata: `technique_source`, `licence`, `duration`, `format`, `category`, `tier`. Launch library about 8.

Articles: about 10 hand-written Markdown files with `sources`, `reviewed_on`, `next_review`; CI flags overdue reviews.

Recommendation rules (on device):

| Signal | Suggestion | Reason shown |
| --- | --- | --- |
| Reports feeling tense at bedtime | Relaxation exercise | "You mentioned feeling tense before bed." |
| Reports waking during the night | Short nighttime exercise | "You mentioned being awake during the night." |
| Bedtime varies over several days | Routine article | "Your recorded bedtimes varied this week." |
| Item dismissed repeatedly | Lower priority | No repeated prompt |
| Sparse data | Goal-based suggestion | "Based on the goal you chose." |

Progress: weekly goal (default 3 wind-downs), journey path moves forward on completions and never back, no streak-lost messages, progress can be hidden. Never rewarded: deep-sleep minutes, REM %, heart rate, sleep scores.

## 9. Privacy, safety and accounts

| Data | Where it lives |
| --- | --- |
| Account, preferences, saved items, completions, achievements, feedback | Supabase |
| HealthKit samples, sleep sessions, sound events, check-ins, journal | Device; user's iCloud if sync on |
| Raw audio | Never stored |
| Calm checks (heart rate, HRV, breathing pace, tension answers) | Device; user's iCloud if sync on. Camera frames and audio never stored; tension answers optionally written to Apple Health State of Mind |
| Analytics | Opt-in event counts only |

Every local record carries the signed-in user's ID. Sign out asks keep or erase local data (default keep). Delete account removes server records and that account's local records. Export: ZIP of JSON (complete) + CSV (nights, check-ins, sound events). Safety language: "Your watch estimated…", "A speech-like sound was detected."; never "You were anxious". Referral only on structured signals: check-in option "Trouble sleeping most nights for 3+ weeks"; standing "When to talk to a doctor" article; snoring-like events marked "this was me" on 5 of 7 nights → one dismissible note, shown once. Journal text is never scanned.

## 10. Technical architecture

iPhone app (SwiftUI) holds Apple Health import, Sound Analysis, SwiftData store, rules engine, content cache. SwiftData syncs with the user's iCloud (CloudKit private DB). Supabase holds Auth, Postgres (progress, prefs, feedback), Storage (content manifest + audio). No health data reaches Stillmoon servers.

Sync rules: events (completions, achievements, feedback) use client UUIDs, sync is a union; preferences and saved items last-write-wins per field by `updated_at`; offline queue; journey progress computed from events.

## 11. Quality, measures and release

Quality: offline bedtime flow; non-stimulating night UI; reports handle delayed, missing, duplicate or conflicting Health data; VoiceOver, Dynamic Type, contrast, Reduce Motion; every recommendation shows its reason; no alert claims stress or anxiety; user-entered info visually distinct from estimates.
