# Stillmoon redesign: Lumi, gentle play, livelier screens

2026-10-04 · Mockup (source of truth for look): https://claude.ai/artifact/Ay9184KdWnNyRUpbbhrGC8

## Intent

Make Stillmoon feel warm, alive and friendly by day and truly calm at night. A mascot, Lumi, becomes the app's voice. Gamification borrows the *shape* of Duolingo (chunky pressable controls, a winding path, a mascot that reacts) and the *tone* of Finch and Gentler Streak (missing a day is fine).

References (Mobbin): Duolingo path and speech-bubble onboarding, Finch home pet and "it's okay to miss a day", Gentler Streak mascot intro and on-device privacy line, Headspace Today timeline, Wysa and Noom check-ins with a reacting character.

## Constraints kept from the PRD

- Progress rewards habits only (wind-downs, check-ins are not scored). No XP, currency, streaks, leagues or streak-lost messages. Nothing reacts to sleep duration, stages or any metric.
- Night mode (PRD §7): no celebration, minimal motion, large controls. Lumi never cheers or bounces at night.
- Observations and feelings stay visibly separate ("Apple Watch estimate" label vs "This is how you felt").
- Every suggestion shows its reason.
- Reduce Motion stops every animation; Lumi renders as a still pose.
- Dynamic Type and VoiceOver work on every screen; Lumi is decorative (`accessibilityHidden`), its speech bubble is read as text.
- No new third-party dependencies.

## Scope

In: design tokens and shared components; Lumi; restyle of Today (day and night), check-in sheet, player, a new daytime completion screen, Journey ("Your sky"), onboarding; new Log in and Sign up views; Sleep, Exercises, article, Settings and sound session restyled with the shared components (no bespoke mockups).

Out: real authentication (Plan 5 wires Sign in with Apple, Google and Supabase into the new views); new content; data model changes beyond what the completion screen needs (none expected).

## Design system

`App/Stillmoon/Design/` grows from `Theme.swift` to a small system.

**Colors** (`Theme`, day / night):

| Token | Day | Night |
| --- | --- | --- |
| background | #FBF7F1 | #12142B |
| surface | #FFFFFF | #1E1F3F |
| sky (Today header, login) | #E9E3FA | #12142B |
| hill / hill2 | #DCD3F6 / #CDC1F1 | — |
| text | #231E3A | #D9D4EE |
| secondaryText | #5E5876 | #9A93B8 |
| accent (buttons) | #6F5BB0, edge #4E3F8A | #A99BE0 (flat, text #12142B) |
| accentSoft (selected fills, chips) | #EDE8FA | #2A2650 |
| cardBorder | #ECE6F6 | #2C2B55 |
| reason box | #FDF1EC, text #8A3F2E | surface, secondaryText |
| moon (Lumi, weekly moons, stars) | #FFE38F / #FFD66B, edge #E0AE33 | #EADFB8 |

**Type:** SF Pro Rounded everywhere, via `.fontDesign(.rounded)` at the root, with semibold/bold weights standing in for the mockup's Fredoka titles and Nunito body. System text styles only, so Dynamic Type works unchanged. (The mockup's Google Fonts ship only as variable fonts, which SwiftUI cannot reliably weight under Dynamic Type; nothing is bundled.)

**Components** (`Design/Components.swift`):
- `Card`: surface, 2pt `cardBorder`, 5pt bottom edge, 22pt continuous radius. Night: no edge, 26pt radius.
- `ChunkyButtonStyle` (primary): accent fill, 5pt darker bottom edge; on press it moves down 3pt and the edge shrinks to 2pt (spring 0.12 s). Night variant is flat.
- `ChunkyButtonStyle(.secondary)`: surface fill, 2pt border and 5pt edge.
- `RoundPlayButton`: 56pt circle chunky button with a play glyph.
- `Chip`: 44pt min height capsule, toggles `accentSoft` + accent border when selected.
- `MoonPhase(level: 1...5)`: new moon to full moon glyph used for restedness.
- `SpeechBubble(text:, tail: .leading/.trailing)`: surface, 2pt border, pops in with a spring scale (0.6 → 1.05 → 1) after 0.3 s.
- `ReasonLine`: "Why: …" in the reason box.
- Tab bar stays the native `TabView` (accent tint, existing SF Symbols); the mockup's pill tab bar is not built, to keep system behavior and accessibility.

## Lumi

`App/Stillmoon/Design/Lumi/LumiView.swift`: `LumiView(mood: LumiMood, motion: LumiMotion, size: CGFloat)` reading `\.theme` for night colors. Drawn with SwiftUI `Path`/`Shape` in a 200×200 coordinate space scaled to `size`, matching `Lumi.dc.html` in the mockup: round moon body with craters and a highlight, lavender nightcap with a star and pom-pom, rosy cheeks, stubby arms.

| Mood | Face | Arms | Extras |
| --- | --- | --- | --- |
| calm | open eyes, small smile | down | — |
| wave | open eyes, open smile | right up | — |
| happy | arc eyes, open smile | down | — |
| cheer | arc eyes, open smile | both up | sparkles |
| sleepy | closed eyes, small "o" | down | drifting "z z" |
| concerned | open eyes, worried brows, wobbly mouth | down | — |

| Motion | Animation |
| --- | --- |
| float | ±7pt vertical, 4 s ease-in-out |
| drift | ±4pt, 7 s (night) |
| breathe | scale 0.92 ↔ 1.06, period passed in (8 s default) so it can follow the exercise |
| bounce | squash-and-stretch hop, 1.6 s |
| still | none |

Always on unless Reduce Motion: blink every ~5 s, pom-pom sway. Animations are driven by `TimelineView(.animation)` phases so they cost nothing when off-screen. With Reduce Motion every motion becomes `still`.

**Rules** (`LumiDirector`, pure and unit-tested): given context (screen, night, check-in level, just completed) returns mood, motion and line of copy.
- Night → only `sleepy` or `calm`, motion `drift` or `breathe`, never `cheer`/`bounce`.
- Check-in level 1…5 → concerned, sleepy, calm, happy, cheer, with lines: "Rough night. Let's go gently today." / "Slow mornings are allowed." / "Okay is perfectly okay." / "Nice. Let's keep tonight calm too." / "Wonderful! Hold on to that feeling." (Level 5 bounces only by day.)
- Today header line from weekly progress: goal not met → "One more wind-down fills this week's moon." (count adjusts); met → "This week's moon is full."; no completions ever → "Hi! Want to try a few calm minutes?". Never mentions sleep metrics.

## Screens

**Today (day).** Sky header (~300pt) with rolling hills, a few twinkling dots, greeting and date, a weekly-moon pill ("2 of 3 this week"; informational, hidden when progress is hidden), profile button, Lumi (happy, float) with the director's speech bubble. Below, on a sheet with 28pt top corners, in order: check-in card (five `MoonPhase` buttons, labels "Not rested" / "Very rested"; when done, shows the chosen moon and "Edit"); Last night card ("Apple Watch estimate" or "You recorded" label, big Fredoka duration, time range, compact stage bar when stage detail exists); doctor and snoring notes as today; suggestion card (icon tile, category caption, title, duration and format, `RoundPlayButton`, `ReasonLine`, feedback menu); "Also for you" list; sound start button. Weekly goal now lives in the header pill. Cards rise in with a 0.08 s stagger on first appearance. Existing behavior (sheets, health refresh, night switching) is unchanged.

**Today (night).** Night background with a few slow-twinkling stars (6 s, low opacity), "Good evening" / "Night mode is on", Lumi sleepy and drifting on a cloud, then one card: "Time to wind down" or "Awake at night?", exercise and reason, large flat Start, sound-session button, and "Show everything".

**Check-in sheet.** Title "How rested do you feel?", Lumi (170pt) whose mood and bubble follow the selected level live, five large `MoonPhase` buttons, "Anything else from last night?" chips for the three existing options ("Felt tense at bedtime", "Woke up during the night", "Trouble sleeping most nights for 3+ weeks"; the mockup's extra "Hard to fall asleep" chip is not added), the line "This is how you felt. Stillmoon keeps it apart from what your watch estimated.", Save. Same data as today's `CheckInSheet`.

**Player.** Always dim (night palette). Lumi `calm`, motion `breathe` on a fixed 8 s cycle (exercise steps carry no breath cadence), soft rings breathing behind, the current step text in Fredoka, progress bar with elapsed and remaining time, the existing controls (84pt play/pause, skip step, exit). The mockup's "back 15 s" button is not added. No reward animation.

**Completion (new, `CompletionView`).** Shown after a finished exercise only when not in night mode; at night the player shows today's quiet "Done" state and dismisses. Lumi `cheer` + `bounce`, slow-rotating soft rays, a few drifting sparkles, "Wind-down done!", minutes line, a "This week" card where the newly earned moon pops in, a "A new star lit up in Lumi's sky · <stage> · n of m stars" card, "Saved to Apple Health as Mindful Minutes" when written, Continue. Only wind-down completions count (as in `ProgressCalculator`).

**Journey ("Your sky").** Title "Your sky"; weekly ring card ("2 of 3 wind-downs this week" / "Missed days are fine. Your sky only grows."); then one continuous winding path of 21 stars, split by stage banners using `JourneyModel.stageNames` and `ProgressCalculator.stageThresholds` (stage k holds k stars). Lit stars are chunky gold circles that gently shimmer; the next star is the accent color, pulses and carries a "TONIGHT" tag and starts the suggested wind-down; future stars are grey. Lumi sits beside the next star. The path scrolls to the current position on appear. "Recently" list below the path. Hide-progress still replaces everything with the existing message.

**Onboarding.** Same steps and model. Each step gets a progress bar, a back button, and Lumi with a speech bubble instead of a plain title (welcome: wave, "Hi, I'm Lumi!"; goal: "What would you like a little help with?"; schedule, health, microphone, privacy, first exercise each have one line). Goals become chunky option cards with an icon and a one-line description. The privacy reassurance "Your sleep data stays on your phone." sits above the primary button.

**Log in / Sign up (new views, not yet in the flow).** `LoginView`: sky header with Lumi waving, "Welcome back", "Lumi kept your sky safe. Log in to pick up where you left off.", Continue with Apple (black) and Continue with Google (white, bordered), "New to Stillmoon? Create an account", "Your sleep data never leaves your phone." `SignUpView`: onboarding progress bar, Lumi happy with "Let's keep your stars safe, even on a new phone.", "Create your account", the PRD copy, two tiles ("In your account: progress, saved exercises, your sky" / "On this iPhone: sleep data, check-ins, journal, sounds"), Sign up with Apple and Google, "Already have an account? Log in", terms line. Both take `onApple`, `onGoogle`, `onSwitch` closures and show a loading state; Plan 5 inserts them into onboarding and wires the providers. Built with `#Preview`s only for now. The Apple button follows Apple's guidelines via `SignInWithAppleButton` styling; the Google mark follows Google's branding rules.

**Sleep, Exercises, Article, Settings, Sound session.** Adopt `Card`, the button styles, chips and fonts. Empty states use a small Lumi (calm, or sleepy at night) with one line of copy. No layout changes beyond that.

## Testing

- Unit tests (Swift Testing) for `LumiDirector`: night never yields cheer/bounce; check-in level mapping; header line for 0, partial and met weekly goals; no line mentions duration or stages.
- Unit test that `CompletionView` is chosen only by day and only for wind-downs (decision lives in a small pure function).
- Journey layout function (star index → stage, lit/next/locked) unit-tested against `stageThresholds`.
- Existing model tests keep passing; `LaunchTests` UI test still passes with updated identifiers.
- Manual: Reduce Motion on/off, largest Dynamic Type, VoiceOver pass on Today, check-in and Journey, night mode at 10 pm.

## Risks

- Hand-drawn Lumi in `Path` may need a visual tuning pass; keep geometry in one file with named constants.
- Continuous animations on Today: use `TimelineView` and pause when the scene is inactive to protect battery.
- The Google mark ships as a vector asset (`GoogleG`) in a new asset catalog.
