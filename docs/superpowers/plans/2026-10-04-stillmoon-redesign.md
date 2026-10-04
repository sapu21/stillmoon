# Stillmoon Redesign Implementation Plan (Lumi, gentle play, livelier screens)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle every Stillmoon screen around a shared design system and an animated mascot, Lumi, with gentle habit-only gamification, plus new Log in and Sign up views.

**Architecture:** A small design system in `App/Stillmoon/Design/` (theme tokens, chunky controls, sky backdrop) and a code-drawn mascot in `Design/Lumi/` (pure pose and animation math, a `Canvas` renderer, and a pure `LumiDirector` that decides mood and copy). Screens keep their existing `@Observable` models; new logic lives in small pure types (`SkyPath`, `CompletionStyle`, `CompletionSummary`, `StageBar.segments`, `MoonPhase`) that are unit-tested. Views stay thin.

**Tech Stack:** SwiftUI (iOS 17), Swift 6 with main-actor default isolation, Swift Testing, XcodeGen. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-10-04-stillmoon-redesign-design.md`. Mockup: https://claude.ai/artifact/Ay9184KdWnNyRUpbbhrGC8

## Global Constraints

- iOS 17.0 floor; Swift 6; `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor` (types are main-actor unless marked `nonisolated`).
- No third-party dependencies; no bundled fonts. Type is SF Pro Rounded via `.fontDesign(.rounded)` at the root and system text styles only (Dynamic Type).
- Progress rewards habits only. No XP, currency, streaks, leagues, streak-lost copy. Lumi never reacts to sleep duration, stages or any metric.
- Night mode: no celebration. Lumi never `cheer`s or `bounce`s at night; the completion celebration is daytime-only and wind-down-only.
- Reduce Motion stops every animation (Lumi, stars, rays, rings, pop-ins).
- Lumi is decorative: `accessibilityHidden(true)`; anything Lumi "says" is real `Text`.
- Observations and feelings stay labelled apart ("<source> estimate" vs "This is how you felt…").
- Keep every string the UI tests tap: "Get started", goal titles, "Skip for now", "Not now", "Connect Apple Health", "Turn on sound detection", "Continue", "Go to Today", "Start gentle breathing", "End exercise", "Start sleep session", "Listening for sounds", "End session", identifier `greeting`.
- Test command: `scripts/test-app.sh` (all) or `scripts/test-app.sh -only-testing:StillmoonTests/<Suite>`.
- Commit after each task; messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Reduce Motion on:** every Lumi motion resolves to `.still` and nothing loops. Pinned in Task 2 (`reduceMotionStopsEverything`).
2. **Finishing a wind-down at night:** quiet "Well done. Rest now.", no cheer, no moons popping. Pinned in Task 5 (`celebratesOnlyDaytimeWindDowns`).
3. **More wind-downs than the weekly goal (5 of 3):** pill and completion show "3 of 3", the moon is full, Lumi says the moon is full. Pinned in Task 1 (`weekMoonFillsWithProgress`) and Task 3 (`headerCountsDownToAFullMoon`).
4. **A full sky (21+ wind-downs):** no "next" star, no crash, completion shows no star card. Pinned in Task 4 (`fullSkyHasNoNextStar`) and Task 5 (`summaryPastTheLastStarHasNoStar`).
5. **Progress hidden in Settings:** Lumi's Today line never mentions counts or moons. Pinned in Task 3 (`hiddenProgressNeverShowsCounts`).

---

## File Structure

| File | Responsibility |
| --- | --- |
| `App/Stillmoon/Design/Theme.swift` (modify) | Color tokens (day/night), `Card` restyle |
| `App/Stillmoon/Design/Components.swift` (create) | Chunky button styles, `Chip`, `MoonPhase` + views, `SpeechBubble`, `ReasonLine`, `LabelPill`, `IconTile`, `StepProgress`, `riseIn`, `FlowLayout`, `SkyBackdrop`, `Hills`, `Cloud`, `StarField` |
| `App/Stillmoon/Design/Lumi/LumiModel.swift` (create) | `LumiMood`, `LumiMotion`, `LumiPose`, `LumiAnimation` (pure) |
| `App/Stillmoon/Design/Lumi/LumiView.swift` (create) | `LumiPalette`, `LumiView`, `LumiArt` renderer, `LumiEmptyState` |
| `App/Stillmoon/Design/Lumi/LumiDirector.swift` (create) | Mood, motion and copy decisions (pure) |
| `App/Stillmoon/Features/Journey/SkyPath.swift` (create) | Stars and stages from total wind-downs (pure) |
| `App/Stillmoon/Features/Journey/JourneyModel.swift`, `JourneyView.swift` (modify) | "Your sky" |
| `App/Stillmoon/Features/Exercises/Completion.swift` (create) | `CompletionStyle`, `CompletionSummary` (pure) |
| `App/Stillmoon/Features/Exercises/CompletionView.swift` (create) | Daytime celebration screen |
| `App/Stillmoon/Features/Exercises/PlayerModel.swift`, `PlayerView.swift` (modify) | Breathing Lumi, hand-off to completion |
| `App/Stillmoon/Root/RootView.swift` (modify) | Rounded font, player arguments |
| `App/Stillmoon/Features/Today/StageBar.swift` (create) | Compact stage strip + pure segmenting |
| `App/Stillmoon/Features/Today/TodayModel.swift`, `TodayView.swift` (modify) | Sky header, new cards, night scene |
| `App/Stillmoon/Features/Sleep/CheckInSheet.swift` (modify) | Lumi check-in |
| `App/Stillmoon/Design/Format.swift`, `Features/Onboarding/OnboardingView.swift` (modify) | Goal subtitles/symbols, Lumi onboarding |
| `App/Stillmoon/Features/Account/AccountViews.swift` (create) | `LoginView`, `SignUpView`, `ProviderButtons` |
| `App/Stillmoon/Resources/Assets.xcassets/…` (create) | `GoogleG` vector |
| Exercises, detail, Sleep, Sound session, Settings views (modify) | Adopt components, Lumi empty states |
| `App/StillmoonTests/DesignTests.swift`, `LumiTests.swift`, `LumiDirectorTests.swift`, `SkyPathTests.swift`, `CompletionTests.swift`, `StageBarTests.swift`, `AccountTests.swift` (create); `PlayerModelTests.swift`, `TodayModelTests.swift`, `JourneyModelTests.swift`, `FormatTests.swift` (modify) | Tests |

---

### Task 1: Design system (tokens, components, rounded type)

**Files:**
- Modify: `App/Stillmoon/Design/Theme.swift`
- Create: `App/Stillmoon/Design/Components.swift`
- Modify: `App/Stillmoon/Root/RootView.swift`
- Test: `App/StillmoonTests/DesignTests.swift`

**Interfaces:**
- Produces: `Theme` fields `accentEdge, accentSoft, onAccent, cardBorder, sky, hill, hill2, reasonFill, reasonText, moon, moonEdge` (plus existing); `ChunkyButtonStyle(kind: .primary/.secondary)`, `RoundChunkyButtonStyle(diameter:)`, `TileButtonStyle(fill:border:)`, `Chip(title:isSelected:action:)`, `MoonPhase.shadowOffset(level:) -> CGFloat`, `MoonPhase.label(level:) -> String`, `MoonPhase.level(done:goal:) -> Int`, `MoonPhaseView(level:background:size:)`, `MoonButton(level:isSelected:size:action:)`, `SpeechBubble(text:tail:)`, `ReasonLine(reason:)`, `LabelPill(text:)`, `IconTile(systemName:size:)`, `StepProgress(value:total:)`, `View.riseIn(delay:)`, `FlowLayout(spacing:)`, `SkyBackdrop()`, `Hills`, `Cloud`, `StarField(stars:color:period:alphaRange:)`, `SkyDot`, `StarField.day`, `StarField.night`.

- [ ] **Step 1: Write the failing test**

Create `App/StillmoonTests/DesignTests.swift`:

```swift
import Testing
@testable import Stillmoon

struct DesignTests {
    @Test func moonPhaseGoesFromNewToFull() {
        let offsets = (1...5).map { MoonPhase.shadowOffset(level: $0) }
        #expect(offsets == offsets.sorted())
        #expect(MoonPhase.shadowOffset(level: 1) == 0)
        #expect(MoonPhase.shadowOffset(level: 5) >= 2) // shadow fully clear of the moon
        #expect(MoonPhase.shadowOffset(level: 0) == MoonPhase.shadowOffset(level: 1))
        #expect(MoonPhase.shadowOffset(level: 9) == MoonPhase.shadowOffset(level: 5))
    }

    @Test func restednessLabels() {
        #expect((1...5).map(MoonPhase.label(level:)) == ["Not rested", "A little rested", "Okay", "Rested", "Very rested"])
    }

    @Test func weekMoonFillsWithProgress() {
        #expect(MoonPhase.level(done: 0, goal: 3) == 1)
        #expect(MoonPhase.level(done: 1, goal: 3) == 2)
        #expect(MoonPhase.level(done: 2, goal: 3) == 3)
        #expect(MoonPhase.level(done: 3, goal: 3) == 5)
        #expect(MoonPhase.level(done: 5, goal: 3) == 5)
        #expect(MoonPhase.level(done: 1, goal: 0) == 5) // goal floors at 1
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/DesignTests`
Expected: build error `cannot find 'MoonPhase' in scope`.

- [ ] **Step 3: Replace `App/Stillmoon/Design/Theme.swift`**

```swift
import SwiftUI

extension Color {
    nonisolated init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// nonisolated + Sendable so it can be an environment default under main-actor default isolation.
nonisolated struct Theme: Equatable, Sendable {
    let background: Color
    let surface: Color
    let text: Color
    let secondaryText: Color
    /// Primary buttons, links and selected states.
    let accent: Color
    /// The darker edge under chunky accent buttons (unused at night: night controls are flat).
    let accentEdge: Color
    /// Selected fills, chips and icon tiles.
    let accentSoft: Color
    /// Text and icons on `accent`.
    let onAccent: Color
    let accent2: Color
    let cardBorder: Color
    /// Today and Log in header sky, with its two hill layers.
    let sky: Color
    let hill: Color
    let hill2: Color
    /// The "Why: …" box under a suggestion.
    let reasonFill: Color
    let reasonText: Color
    /// Full moons and lit stars.
    let moon: Color
    let moonEdge: Color
    let isNight: Bool

    static let day = Theme(background: Color(hex: 0xFBF7F1), surface: Color(hex: 0xFFFFFF),
                           text: Color(hex: 0x231E3A), secondaryText: Color(hex: 0x5E5876),
                           accent: Color(hex: 0x6F5BB0), accentEdge: Color(hex: 0x4E3F8A),
                           accentSoft: Color(hex: 0xEDE8FA), onAccent: Color(hex: 0xFFFFFF),
                           accent2: Color(hex: 0xE8907E), cardBorder: Color(hex: 0xECE6F6),
                           sky: Color(hex: 0xE9E3FA), hill: Color(hex: 0xDCD3F6), hill2: Color(hex: 0xCDC1F1),
                           reasonFill: Color(hex: 0xFDF1EC), reasonText: Color(hex: 0x8A3F2E),
                           moon: Color(hex: 0xFFD66B), moonEdge: Color(hex: 0xE0AE33), isNight: false)

    static let night = Theme(background: Color(hex: 0x12142B), surface: Color(hex: 0x1E1F3F),
                             text: Color(hex: 0xD9D4EE), secondaryText: Color(hex: 0x9A93B8),
                             accent: Color(hex: 0xA99BE0), accentEdge: Color(hex: 0xA99BE0),
                             accentSoft: Color(hex: 0x2A2650), onAccent: Color(hex: 0x12142B),
                             accent2: Color(hex: 0xC98B80), cardBorder: Color(hex: 0x2C2B55),
                             sky: Color(hex: 0x12142B), hill: Color(hex: 0x1A1B3A), hill2: Color(hex: 0x16183A),
                             reasonFill: Color(hex: 0x1E1F3F), reasonText: Color(hex: 0x9A93B8),
                             moon: Color(hex: 0xEADFB8), moonEdge: Color(hex: 0xC9BD8F), isNight: true)
}

extension EnvironmentValues {
    @Entry var theme: Theme = .day
}

/// Rounded card (PRD §2 "Cards"): soft border and a chunky bottom edge by day, flat at night.
struct Card<Content: View>: View {
    @Environment(\.theme) private var theme
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.isNight ? 26 : 22, style: .continuous)
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(theme.isNight ? 20 : 16)
            .foregroundStyle(theme.text)
            .background(shape.fill(theme.surface))
            .overlay(shape.strokeBorder(theme.isNight ? Color.clear : theme.cardBorder, lineWidth: 2))
            .background(shape.fill(theme.isNight ? Color.clear : theme.cardBorder).offset(y: 3))
            .padding(.bottom, theme.isNight ? 0 : 3)
    }
}
```

- [ ] **Step 4: Check nothing else constructs `Theme(`**

Run: `grep -rn "Theme(" App --include=*.swift | grep -v Design/Theme.swift`
Expected: no output (only `Theme.day` / `Theme.night` are used elsewhere).

- [ ] **Step 5: Create `App/Stillmoon/Design/Components.swift`**

```swift
import SwiftUI

// MARK: Buttons

/// Duolingo-style pressable button: the face sits on a darker edge and sinks into it when pressed.
/// Flat at night (PRD §2: nothing stimulating at night).
struct ChunkyButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        ChunkyFace(kind: kind, configuration: configuration)
    }

    private struct ChunkyFace: View {
        @Environment(\.theme) private var theme
        @Environment(\.isEnabled) private var isEnabled
        let kind: Kind
        let configuration: ButtonStyleConfiguration

        var body: some View {
            let depth: CGFloat = theme.isNight ? 0 : 5
            let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
            let primary = kind == .primary
            let fill = primary ? (isEnabled ? theme.accent : theme.cardBorder) : theme.surface
            let edge = primary && isEnabled ? theme.accentEdge : theme.cardBorder
            let text = primary ? (isEnabled ? theme.onAccent : theme.secondaryText) : theme.text
            configuration.label
                .font(.headline)
                .foregroundStyle(text)
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.horizontal, 16)
                .background(shape.fill(fill))
                .overlay(shape.strokeBorder(primary ? Color.clear : theme.cardBorder, lineWidth: 2))
                .offset(y: configuration.isPressed ? min(3, depth) : 0)
                .background(shape.fill(edge).offset(y: depth))
                .padding(.bottom, depth)
                .contentShape(shape)
                .animation(.spring(duration: 0.12), value: configuration.isPressed)
        }
    }
}

/// Round chunky button, e.g. the play button on a suggestion.
struct RoundChunkyButtonStyle: ButtonStyle {
    var diameter: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        RoundFace(diameter: diameter, configuration: configuration)
    }

    private struct RoundFace: View {
        @Environment(\.theme) private var theme
        let diameter: CGFloat
        let configuration: ButtonStyleConfiguration

        var body: some View {
            let depth: CGFloat = theme.isNight ? 0 : 5
            configuration.label
                .foregroundStyle(theme.onAccent)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(theme.accent))
                .offset(y: configuration.isPressed ? min(3, depth) : 0)
                .background(Circle().fill(theme.accentEdge).offset(y: depth))
                .padding(.bottom, depth)
                .contentShape(Circle())
                .animation(.spring(duration: 0.12), value: configuration.isPressed)
        }
    }
}

/// A pressable tile with a border-colored edge (moon buttons, goal cards).
struct TileButtonStyle: ButtonStyle {
    let fill: Color
    let border: Color

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        configuration.label
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(border, lineWidth: 2))
            .offset(y: configuration.isPressed ? 3 : 0)
            .background(shape.fill(border).offset(y: 4))
            .padding(.bottom, 4)
            .contentShape(shape)
            .animation(.spring(duration: 0.12), value: configuration.isPressed)
    }
}

/// Toggleable capsule; 44pt minimum height.
struct Chip: View {
    @Environment(\.theme) private var theme
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .multilineTextAlignment(.leading)
                .foregroundStyle(isSelected ? theme.accent : theme.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .background(Capsule().fill(isSelected ? theme.accentSoft : theme.surface))
                .overlay(Capsule().strokeBorder(isSelected ? theme.accent : theme.cardBorder, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: Moons

/// Restedness and weekly progress as moon phases: level 1 is a new moon, 5 is full.
enum MoonPhase {
    static let labels = ["Not rested", "A little rested", "Okay", "Rested", "Very rested"]

    private static func clamped(_ level: Int) -> Int { min(max(level, 1), 5) }

    /// How far the shadow disc sits from the moon's center, as a fraction of its radius.
    static func shadowOffset(level: Int) -> CGFloat {
        let offsets: [CGFloat] = [0, 0.62, 1.15, 1.77, 4.6]
        return offsets[clamped(level) - 1]
    }

    static func label(level: Int) -> String { labels[clamped(level) - 1] }

    /// The week's moon: new with nothing done, full once the goal is met, never past full.
    static func level(done: Int, goal: Int) -> Int {
        let goal = max(1, goal)
        if done >= goal { return 5 }
        return 1 + Int(Double(max(0, done)) / Double(goal) * 4)
    }
}

struct MoonPhaseView: View {
    @Environment(\.theme) private var theme
    let level: Int
    /// The color behind the moon; the shadow disc is painted in it.
    let background: Color
    var size: CGFloat = 32

    var body: some View {
        let diameter = size * 26 / 32
        ZStack {
            Circle().fill(theme.moon).frame(width: diameter, height: diameter)
            Circle().fill(background).frame(width: diameter, height: diameter)
                .offset(x: MoonPhase.shadowOffset(level: level) * diameter / 2)
            Circle().strokeBorder(theme.moonEdge, lineWidth: 2).frame(width: diameter, height: diameter)
        }
        .frame(width: size, height: size)
        .clipped()
        .accessibilityHidden(true)
    }
}

struct MoonButton: View {
    @Environment(\.theme) private var theme
    let level: Int
    let isSelected: Bool
    var size: CGFloat = 54
    let action: () -> Void

    var body: some View {
        let fill = isSelected ? theme.accentSoft : theme.surface
        Button(action: action) {
            MoonPhaseView(level: level, background: fill, size: size * 0.6)
                .frame(width: size, height: size)
        }
        .buttonStyle(TileButtonStyle(fill: fill, border: isSelected ? theme.accent : theme.cardBorder))
        .accessibilityLabel(MoonPhase.label(level: level))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: Text pieces

/// What Lumi says. Pops in once; later changes cross-fade.
struct SpeechBubble: View {
    enum Tail { case leading, trailing }
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let text: String
    var tail: Tail = .leading
    @State private var shown = false

    var body: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: tail == .leading ? 6 : 18,
                                           bottomTrailingRadius: tail == .trailing ? 6 : 18, topTrailingRadius: 18,
                                           style: .continuous)
        Text(text)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(theme.text)
            .fixedSize(horizontal: false, vertical: true)
            .contentTransition(.opacity)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(shape.fill(theme.surface))
            .overlay(shape.strokeBorder(theme.cardBorder, lineWidth: 2))
            .scaleEffect(shown || reduceMotion ? 1 : 0.6, anchor: tail == .leading ? .bottomLeading : .bottomTrailing)
            .opacity(shown || reduceMotion ? 1 : 0)
            .animation(.easeOut(duration: 0.2), value: text)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.3)) { shown = true }
            }
    }
}

/// "Why: …" under a suggestion (PRD principle 4).
struct ReasonLine: View {
    @Environment(\.theme) private var theme
    let reason: String

    var body: some View {
        Text("Why: \(reason)")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(theme.reasonText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.reasonFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Small label pill, e.g. "Apple Watch estimate". (Not `Tag`: Swift Testing has one.)
struct LabelPill: View {
    @Environment(\.theme) private var theme
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(theme.accentSoft, in: Capsule())
    }
}

struct IconTile: View {
    @Environment(\.theme) private var theme
    let systemName: String
    var size: CGFloat = 56

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(theme.accent)
            .frame(width: size, height: size)
            .background(theme.accentSoft, in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct StepProgress: View {
    @Environment(\.theme) private var theme
    let value: Int
    let total: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.cardBorder)
                Capsule().fill(theme.accent)
                    .frame(width: geo.size.width * CGFloat(value) / CGFloat(max(total, 1)))
            }
        }
        .frame(height: 14)
        .animation(.spring(duration: 0.4), value: value)
        .accessibilityElement()
        .accessibilityLabel("Step \(value) of \(total)")
    }
}

// MARK: Motion helpers

private struct RiseIn: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear { withAnimation(.easeOut(duration: 0.5).delay(delay)) { shown = true } }
    }
}

extension View {
    /// Fades and slides the view up on first appearance (cards on Today).
    func riseIn(delay: Double = 0) -> some View { modifier(RiseIn(delay: delay)) }
}

/// Wraps children onto new lines, left to right (chips).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = makeRows(maxWidth, subviews)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? (rows.map(\.width).max() ?? 0), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in makeRows(bounds.width, subviews) {
            var x = bounds.minX
            for i in row.indices {
                let size = subviews[i].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                subviews[i].place(at: CGPoint(x: x, y: y),
                                  proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func makeRows(_ maxWidth: CGFloat, _ subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if !current.indices.isEmpty && current.width + spacing + size.width > maxWidth {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(i)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: Sky

struct SkyDot {
    let x: CGFloat // 0...1 of the width
    let y: CGFloat // 0...1 of the height
    let r: CGFloat // points
}

/// Twinkling dots. Day twinkles in 3 s, night in a slow 6 s at low opacity.
struct StarField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let stars: [SkyDot]
    let color: Color
    var period: Double = 3
    var alphaRange: ClosedRange<Double> = 0.25...1

    static let day = [SkyDot(x: 0.10, y: 0.50, r: 2.5), SkyDot(x: 0.38, y: 0.36, r: 2),
                      SkyDot(x: 0.77, y: 0.30, r: 3), SkyDot(x: 0.90, y: 0.50, r: 2)]
    static let night = [SkyDot(x: 0.08, y: 0.14, r: 1.5), SkyDot(x: 0.25, y: 0.30, r: 1),
                        SkyDot(x: 0.44, y: 0.12, r: 1.5), SkyDot(x: 0.64, y: 0.26, r: 1),
                        SkyDot(x: 0.85, y: 0.16, r: 1.5), SkyDot(x: 0.93, y: 0.42, r: 1),
                        SkyDot(x: 0.06, y: 0.50, r: 1), SkyDot(x: 0.77, y: 0.56, r: 1.5),
                        SkyDot(x: 0.16, y: 0.70, r: 1), SkyDot(x: 0.54, y: 0.64, r: 1)]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { gc, size in
                for (i, star) in stars.enumerated() {
                    let phase = reduceMotion ? 0.5 : (sin((t / period + Double(i) * 0.37) * 2 * .pi) + 1) / 2
                    let alpha = alphaRange.lowerBound + (alphaRange.upperBound - alphaRange.lowerBound) * phase
                    let rect = CGRect(x: star.x * size.width - star.r, y: star.y * size.height - star.r,
                                      width: star.r * 2, height: star.r * 2)
                    gc.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Rolling hill silhouette along the bottom of its rect.
struct Hills: Shape {
    var lift: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.45))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY + h * (0.42 + lift)),
                       control: CGPoint(x: rect.minX + w * 0.25, y: rect.minY + h * 0.02))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.35),
                       control: CGPoint(x: rect.minX + w * 0.75, y: rect.minY + h * (0.72 - lift)))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// A soft cloud for Lumi to rest on at night.
struct Cloud: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + w * x, y: r.minY + h * y) }
        var p = Path()
        p.move(to: pt(0.09, 1))
        p.addQuadCurve(to: pt(0.15, 0.43), control: pt(0, 0.5))
        p.addQuadCurve(to: pt(0.49, 0.22), control: pt(0.25, -0.1))
        p.addQuadCurve(to: pt(0.83, 0.4), control: pt(0.7, -0.15))
        p.addQuadCurve(to: pt(0.92, 1), control: pt(1.05, 0.45))
        p.closeSubpath()
        return p
    }
}

/// Lavender sky with hills and twinkling stars (Today and Log in headers).
struct SkyBackdrop: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack(alignment: .bottom) {
            theme.sky
            StarField(stars: theme.isNight ? StarField.night : StarField.day,
                      color: theme.isNight ? Color(hex: 0xCFC6EE) : .white,
                      period: theme.isNight ? 6 : 3,
                      alphaRange: theme.isNight ? 0.15...0.6 : 0.25...1)
            Hills().fill(theme.hill).frame(height: 110)
            Hills(lift: 0.2).fill(theme.hill2).frame(height: 70)
        }
        .accessibilityHidden(true)
    }
}
```

- [ ] **Step 6: Rounded type at the root**

In `App/Stillmoon/Root/RootView.swift`, change

```swift
            .environment(\.theme, theme)
            .tint(theme.accent)
```

to

```swift
            .environment(\.theme, theme)
            .tint(theme.accent)
            .fontDesign(.rounded)
```

- [ ] **Step 7: Run tests**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/DesignTests`
Expected: `** TEST SUCCEEDED **`, 3 tests passed.

- [ ] **Step 8: Commit**

```bash
git add App/Stillmoon/Design App/Stillmoon/Root/RootView.swift App/StillmoonTests/DesignTests.swift
git commit -m "feat(design): theme tokens, chunky components, moon phases, sky backdrop, rounded type

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Lumi (pose, motion, renderer)

**Files:**
- Create: `App/Stillmoon/Design/Lumi/LumiModel.swift`
- Create: `App/Stillmoon/Design/Lumi/LumiView.swift`
- Test: `App/StillmoonTests/LumiTests.swift`

**Interfaces:**
- Consumes: `Theme` (Task 1).
- Produces: `LumiMood` (`calm, wave, happy, cheer, sleepy, concerned`, `effective(isNight:)`), `LumiMotion` (`float, drift, bounce, still, breathe(period:)`, `effective(reduceMotion:isNight:)`), `LumiPose.of(_:)`, `LumiAnimation.wave(_:period:)`, `LumiAnimation.transform(_:at:)`, `LumiAnimation.eyeScale(at:)`, `LumiView(mood:motion:size:animated:)`, `LumiEmptyState(title:message:)`.

- [ ] **Step 1: Write the failing test**

Create `App/StillmoonTests/LumiTests.swift`:

```swift
import Testing
@testable import Stillmoon

struct LumiTests {
    @Test func reduceMotionStopsEverything() {
        for motion in [LumiMotion.float, .drift, .bounce, .still, .breathe(period: 8)] {
            #expect(motion.effective(reduceMotion: true, isNight: false) == .still)
            #expect(motion.effective(reduceMotion: true, isNight: true) == .still)
        }
    }

    @Test func neverBouncesOrCheersAtNight() {
        #expect(LumiMotion.bounce.effective(reduceMotion: false, isNight: true) == .drift)
        #expect(LumiMotion.bounce.effective(reduceMotion: false, isNight: false) == .bounce)
        #expect(LumiMood.cheer.effective(isNight: true) == .happy)
        #expect(LumiMood.cheer.effective(isNight: false) == .cheer)
        for mood in LumiMood.allCases {
            #expect(!LumiPose.of(mood.effective(isNight: true)).sparkles)
        }
    }

    @Test func posesMatchTheCharacterSheet() {
        #expect(LumiPose.of(.cheer).leftArmUp && LumiPose.of(.cheer).rightArmUp)
        #expect(LumiPose.of(.wave).rightArmUp && !LumiPose.of(.wave).leftArmUp)
        #expect(LumiPose.of(.sleepy).zzz && LumiPose.of(.sleepy).eyes == .sleepy)
        #expect(LumiPose.of(.concerned).brows && LumiPose.of(.concerned).mouth == .wobble)
        #expect(LumiMood.allCases.filter { LumiPose.of($0).sparkles } == [.cheer])
    }

    @Test func motionCurves() {
        #expect(LumiAnimation.transform(.still, at: 3) == LumiAnimation.Transform())
        #expect(abs(LumiAnimation.transform(.float, at: 2).dy + 7) < 0.001) // top of the float halfway through 4 s
        let exhaled = LumiAnimation.transform(.breathe(period: 8), at: 0)
        let inhaled = LumiAnimation.transform(.breathe(period: 8), at: 4)
        #expect(abs(exhaled.scaleX - 0.92) < 0.001)
        #expect(abs(inhaled.scaleX - 1.06) < 0.001)
        let hops = stride(from: 0.0, to: 1.6, by: 0.05).map { LumiAnimation.transform(.bounce, at: $0).dy }
        #expect(hops.allSatisfy { $0 <= 0 && $0 >= -18 })
    }

    @Test func blinksBriefly() {
        #expect(LumiAnimation.eyeScale(at: 0) == 1)
        #expect(LumiAnimation.eyeScale(at: 4.8) < 0.5) // 96% through the 5 s cycle
        let closed = stride(from: 0.0, to: 5.0, by: 0.01).filter { LumiAnimation.eyeScale(at: $0) < 0.5 }.count
        #expect(closed < 30) // eyes shut for well under a third of a second
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/LumiTests`
Expected: build error `cannot find 'LumiMotion' in scope`.

- [ ] **Step 3: Create `App/Stillmoon/Design/Lumi/LumiModel.swift`**

```swift
import CoreGraphics
import Foundation

/// Lumi's expressions (spec "Lumi"). Pick one through `LumiDirector`.
enum LumiMood: String, CaseIterable, Sendable {
    case calm, wave, happy, cheer, sleepy, concerned

    /// Night never celebrates (PRD §2).
    func effective(isNight: Bool) -> LumiMood {
        isNight && self == .cheer ? .happy : self
    }
}

enum LumiMotion: Equatable, Sendable {
    case float, drift, bounce, still
    /// Grows on the in-breath; `period` is one full breath in seconds.
    case breathe(period: Double)

    /// What actually plays: nothing with Reduce Motion, never a bounce at night.
    func effective(reduceMotion: Bool, isNight: Bool) -> LumiMotion {
        if reduceMotion { return .still }
        if isNight && self == .bounce { return .drift }
        return self
    }
}

/// Which parts of the drawing a mood shows.
struct LumiPose: Equatable {
    enum Eyes: Equatable { case open, happy, sleepy }
    enum Mouth: Equatable { case smile, open, o, wobble }

    var eyes: Eyes
    var mouth: Mouth
    var brows = false
    var leftArmUp = false
    var rightArmUp = false
    var zzz = false
    var sparkles = false

    static func of(_ mood: LumiMood) -> LumiPose {
        switch mood {
        case .calm: LumiPose(eyes: .open, mouth: .smile)
        case .wave: LumiPose(eyes: .open, mouth: .open, rightArmUp: true)
        case .happy: LumiPose(eyes: .happy, mouth: .open)
        case .cheer: LumiPose(eyes: .happy, mouth: .open, leftArmUp: true, rightArmUp: true, sparkles: true)
        case .sleepy: LumiPose(eyes: .sleepy, mouth: .o, zzz: true)
        case .concerned: LumiPose(eyes: .open, mouth: .wobble, brows: true)
        }
    }
}

/// Pure animation curves over time `t` in seconds (any reference). Kept here so they are testable.
enum LumiAnimation {
    struct Transform: Equatable {
        var dy: CGFloat = 0
        var scaleX: CGFloat = 1
        var scaleY: CGFloat = 1
    }

    struct Drift: Equatable {
        var dx: CGFloat
        var dy: CGFloat
        var opacity: Double
    }

    /// 0 → 1 → 0 over `period`, easing in and out; 0 at t = 0.
    static func wave(_ t: Double, period: Double) -> Double {
        (1 - cos(2 * .pi * t / period)) / 2
    }

    static func transform(_ motion: LumiMotion, at t: Double) -> Transform {
        switch motion {
        case .still:
            return Transform()
        case .float:
            return Transform(dy: -7 * wave(t, period: 4))
        case .drift:
            return Transform(dy: -4 * wave(t, period: 7))
        case .breathe(let period):
            let s = 0.92 + 0.14 * wave(t, period: period)
            return Transform(scaleX: s, scaleY: s)
        case .bounce:
            let p = (t / 1.6).truncatingRemainder(dividingBy: 1)
            if p < 0.5 { return Transform(dy: -18 * sin(p * 2 * .pi)) }
            let squash = p < 0.7 ? 0.06 * sin((p - 0.5) / 0.2 * .pi) : 0
            return Transform(scaleX: 1 + squash, scaleY: 1 - squash)
        }
    }

    /// Vertical eye scale: a quick blink near the end of every 5 s.
    static func eyeScale(at t: Double) -> CGFloat {
        let p = (t / 5).truncatingRemainder(dividingBy: 1)
        guard p > 0.93 && p < 0.99 else { return 1 }
        return 1 - 0.9 * sin((p - 0.93) / 0.06 * .pi)
    }

    /// Pom-pom sway in degrees.
    static func pomAngle(at t: Double) -> Double { 10 * wave(t, period: 3) }

    /// A "z" rising and fading over 3 s.
    static func zDrift(at t: Double) -> Drift {
        let p = (t / 3).truncatingRemainder(dividingBy: 1)
        let opacity = p < 0.25 ? p / 0.25 : 1 - (p - 0.25) / 0.75
        return Drift(dx: 10 * p, dy: 6 - 24 * p, opacity: opacity)
    }

    /// Sparkle scale, staggered by index.
    static func sparkleScale(at t: Double, index: Int) -> CGFloat {
        0.6 + 0.5 * wave(t + 0.3 * Double(index), period: 1.4)
    }
}
```

- [ ] **Step 4: Create `App/Stillmoon/Design/Lumi/LumiView.swift`**

Geometry is a 200×200 space matching `Lumi.dc.html` in the mockup.

```swift
import SwiftUI

struct LumiPalette {
    let body: Color
    let shade: Color
    let cap: Color
    let pom: Color
    let z: Color

    static let ink = Color(hex: 0x231E3A)
    static let cheek = Color(hex: 0xF4A99B)
    static let mouth = Color(hex: 0xB85479)
    static let capStar = Color(hex: 0xFFE38F)
    static let sparkle = Color(hex: 0xFFC94D)

    static let day = LumiPalette(body: Color(hex: 0xFFE7A0), shade: Color(hex: 0xF2CB6B),
                                 cap: Color(hex: 0x8E7CC3), pom: Color(hex: 0xF6F2FF), z: Color(hex: 0x8E7CC3))
    static let night = LumiPalette(body: Color(hex: 0xEADFB8), shade: Color(hex: 0xD6C68F),
                                   cap: Color(hex: 0x6F62A8), pom: Color(hex: 0xCFC6EE), z: Color(hex: 0xCFC6EE))
}

/// Stillmoon's mascot: a sleepy little moon in a nightcap. Decorative only; pair it with text.
struct LumiView: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let mood: LumiMood
    var motion: LumiMotion = .float
    var size: CGFloat = 160
    /// False holds a still pose with no blinking (sound session: PRD §7 "no animation").
    var animated = true

    var body: some View {
        let live = animated && !reduceMotion
        let pose = LumiPose.of(mood.effective(isNight: theme.isNight))
        let palette = theme.isNight ? LumiPalette.night : LumiPalette.day
        let resolvedMotion = live ? motion.effective(reduceMotion: false, isNight: theme.isNight) : .still
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live)) { context in
            let t = live ? context.date.timeIntervalSinceReferenceDate : 0
            Canvas { gc, canvasSize in
                LumiArt.draw(in: &gc, size: canvasSize, pose: pose, palette: palette, motion: resolvedMotion, t: t, live: live)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Draws Lumi into a 200×200 space.
enum LumiArt {
    static func draw(in gc: inout GraphicsContext, size: CGSize, pose: LumiPose, palette: LumiPalette,
                     motion: LumiMotion, t: Double, live: Bool) {
        gc.scaleBy(x: size.width / 200, y: size.height / 200)
        gc.fill(ellipse(100, 188, 52, 7), with: .color(LumiPalette.ink.opacity(0.10))) // shadow stays put
        let m = LumiAnimation.transform(motion, at: t)
        gc.translateBy(x: 100, y: 186 + m.dy)
        gc.scaleBy(x: m.scaleX, y: m.scaleY)
        gc.translateBy(x: -100, y: -186)
        drawArms(&gc, pose, palette)
        drawBody(&gc, palette)
        drawCap(&gc, palette, t: t, live: live)
        drawFace(&gc, pose, t: t, live: live)
        if pose.zzz { drawZzz(&gc, palette, t: t, live: live) }
        if pose.sparkles { drawSparkles(&gc, t: t, live: live) }
    }

    private static func drawArms(_ gc: inout GraphicsContext, _ pose: LumiPose, _ p: LumiPalette) {
        let left = pose.leftArmUp ? ellipse(34, 94, 11, 16, rotate: -28) : ellipse(36, 142, 11, 15, rotate: 20)
        let right = pose.rightArmUp ? ellipse(166, 94, 11, 16, rotate: 28) : ellipse(164, 142, 11, 15, rotate: -20)
        for arm in [left, right] {
            gc.fill(arm, with: .color(p.body))
            gc.stroke(arm, with: .color(p.shade), lineWidth: 2)
        }
    }

    private static func drawBody(_ gc: inout GraphicsContext, _ p: LumiPalette) {
        let body = ellipse(100, 116, 68, 62)
        gc.fill(body, with: .color(p.body))
        var inner = gc
        inner.clip(to: body)
        inner.fill(ellipse(100, 156, 50, 18), with: .color(p.shade.opacity(0.45)))
        inner.fill(ellipse(70, 90, 15, 9, rotate: -30), with: .color(.white.opacity(0.45)))
        inner.fill(ellipse(150, 104, 5, 5), with: .color(p.shade))
        inner.fill(ellipse(140, 160, 6, 6), with: .color(p.shade.opacity(0.8)))
        inner.fill(ellipse(58, 156, 4, 4), with: .color(p.shade.opacity(0.8)))
    }

    private static func drawCap(_ gc: inout GraphicsContext, _ p: LumiPalette, t: Double, live: Bool) {
        var cap = Path()
        cap.move(to: pt(44, 88))
        cap.addCurve(to: pt(154, 50), control1: pt(50, 40), control2: pt(116, 14))
        cap.addCurve(to: pt(182, 104), control1: pt(170, 64), control2: pt(180, 84))
        cap.addLine(to: pt(170, 102))
        cap.addCurve(to: pt(148, 78), control1: pt(166, 88), control2: pt(158, 80))
        cap.addQuadCurve(to: pt(44, 88), control: pt(96, 70))
        cap.closeSubpath()
        gc.fill(cap, with: .color(p.cap))
        gc.fill(star4(cx: 104, cy: 44, r: 10), with: .color(LumiPalette.capStar))
        var brim = Path()
        brim.move(to: pt(40, 90))
        brim.addQuadCurve(to: pt(156, 80), control: pt(98, 66))
        gc.stroke(brim, with: .color(p.pom), style: StrokeStyle(lineWidth: 12, lineCap: .round))
        var pom = gc // sways around the cap's tip
        pom.translateBy(x: 150, y: 60)
        pom.rotate(by: .degrees(live ? LumiAnimation.pomAngle(at: t) : 0))
        pom.translateBy(x: -150, y: -60)
        pom.fill(ellipse(180, 108, 11, 11), with: .color(p.pom))
    }

    private static func drawFace(_ gc: inout GraphicsContext, _ pose: LumiPose, t: Double, live: Bool) {
        let ink = GraphicsContext.Shading.color(LumiPalette.ink)
        let line = StrokeStyle(lineWidth: 4.5, lineCap: .round)
        switch pose.eyes {
        case .open:
            let s = live ? LumiAnimation.eyeScale(at: t) : 1
            for cx in [78.0, 122.0] {
                gc.fill(ellipse(cx, 118, 6.5, 8.5 * s), with: ink)
                if s > 0.5 { gc.fill(ellipse(cx + 2.5, 114.5, 2.3, 2.3), with: .color(.white)) }
            }
        case .happy:
            gc.stroke(arc(70, 120, 78, 109, 86, 120), with: ink, style: line)
            gc.stroke(arc(114, 120, 122, 109, 130, 120), with: ink, style: line)
        case .sleepy:
            gc.stroke(arc(70, 116, 78, 125, 86, 116), with: ink, style: line)
            gc.stroke(arc(114, 116, 122, 125, 130, 116), with: ink, style: line)
        }
        if pose.brows {
            var brows = Path()
            brows.move(to: pt(68, 105)); brows.addLine(to: pt(86, 100))
            brows.move(to: pt(114, 100)); brows.addLine(to: pt(132, 105))
            gc.stroke(brows, with: ink, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        }
        gc.fill(ellipse(60, 134, 11, 6.5), with: .color(LumiPalette.cheek.opacity(0.75)))
        gc.fill(ellipse(140, 134, 11, 6.5), with: .color(LumiPalette.cheek.opacity(0.75)))
        switch pose.mouth {
        case .smile:
            gc.stroke(arc(90, 134, 100, 144, 110, 134), with: ink, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        case .open:
            var mouth = arc(88, 132, 100, 154, 112, 132)
            mouth.closeSubpath()
            gc.fill(mouth, with: .color(LumiPalette.mouth))
            gc.stroke(mouth, with: ink, style: StrokeStyle(lineWidth: 3, lineJoin: .round))
        case .o:
            gc.fill(ellipse(100, 139, 4.5, 3.5), with: ink)
        case .wobble:
            var mouth = Path()
            mouth.move(to: pt(90, 141))
            mouth.addQuadCurve(to: pt(100, 141), control: pt(95, 136))
            mouth.addQuadCurve(to: pt(110, 141), control: pt(105, 146))
            gc.stroke(mouth, with: ink, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        }
    }

    private static func drawZzz(_ gc: inout GraphicsContext, _ p: LumiPalette, t: Double, live: Bool) {
        let letters: [(x: Double, y: Double, size: Double)] = [(148, 46, 24), (168, 26, 17)]
        for (i, z) in letters.enumerated() {
            let drift = live ? LumiAnimation.zDrift(at: t + Double(i) * 1.5) : LumiAnimation.Drift(dx: 0, dy: 0, opacity: 1)
            var layer = gc
            layer.opacity = drift.opacity
            layer.draw(Text("z").font(.system(size: z.size, weight: .semibold, design: .rounded)).foregroundStyle(p.z),
                       at: pt(z.x + drift.dx, z.y + drift.dy))
        }
    }

    private static func drawSparkles(_ gc: inout GraphicsContext, t: Double, live: Bool) {
        let spots: [(x: Double, y: Double, r: Double)] = [(24, 52, 10), (178, 36, 8), (26, 150, 7)]
        for (i, s) in spots.enumerated() {
            let scale = live ? LumiAnimation.sparkleScale(at: t, index: i) : 1
            gc.fill(star4(cx: s.x, cy: s.y, r: s.r * scale), with: .color(LumiPalette.sparkle))
        }
    }

    // MARK: Geometry helpers

    private static func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

    private static func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, rotate degrees: Double = 0) -> Path {
        let path = Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
        guard degrees != 0 else { return path }
        let turn = CGAffineTransform(translationX: cx, y: cy)
            .rotated(by: degrees * .pi / 180)
            .translatedBy(x: -cx, y: -cy)
        return path.applying(turn)
    }

    /// A quadratic stroke from (x0, y0) through control (cx, cy) to (x1, y1).
    private static func arc(_ x0: Double, _ y0: Double, _ cx: Double, _ cy: Double, _ x1: Double, _ y1: Double) -> Path {
        var p = Path()
        p.move(to: pt(x0, y0))
        p.addQuadCurve(to: pt(x1, y1), control: pt(cx, cy))
        return p
    }

    /// Four-point twinkle star.
    private static func star4(cx: Double, cy: Double, r: Double) -> Path {
        let w = r * 0.3
        var p = Path()
        p.move(to: pt(cx, cy - r))
        p.addLine(to: pt(cx + w, cy - w)); p.addLine(to: pt(cx + r, cy))
        p.addLine(to: pt(cx + w, cy + w)); p.addLine(to: pt(cx, cy + r))
        p.addLine(to: pt(cx - w, cy + w)); p.addLine(to: pt(cx - r, cy))
        p.addLine(to: pt(cx - w, cy - w))
        p.closeSubpath()
        return p
    }
}

/// Empty states: a small Lumi and one line of copy.
struct LumiEmptyState: View {
    @Environment(\.theme) private var theme
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            LumiView(mood: theme.isNight ? .sleepy : .calm, motion: theme.isNight ? .drift : .float, size: 110)
            Text(title).font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Moods") {
    ScrollView {
        LazyVGrid(columns: [GridItem(), GridItem()]) {
            ForEach(LumiMood.allCases, id: \.self) { mood in
                VStack {
                    LumiView(mood: mood, motion: mood == .cheer ? .bounce : .float, size: 150)
                    Text(mood.rawValue)
                }
            }
        }
    }
    .background(Theme.day.background)
}
```

- [ ] **Step 5: Run tests**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/LumiTests`
Expected: `** TEST SUCCEEDED **`, 5 tests passed.

- [ ] **Step 6: Look at Lumi**

Open `LumiView.swift` in Xcode and check the "Moods" preview (or run the app later in Task 6). Lumi should read as a round yellow moon with a lavender cap, pom-pom on the right, rosy cheeks. Fix only geometry constants if something is clearly off (e.g. the cap not covering the head).

- [ ] **Step 7: Commit**

```bash
git add App/Stillmoon/Design/Lumi App/StillmoonTests/LumiTests.swift
git commit -m "feat(lumi): mascot poses, motion curves and canvas renderer

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: LumiDirector (what Lumi feels and says)

**Files:**
- Create: `App/Stillmoon/Design/Lumi/LumiDirector.swift`
- Test: `App/StillmoonTests/LumiDirectorTests.swift`

**Interfaces:**
- Consumes: `LumiMood`, `LumiMotion` (Task 2); `ProgressSummary` (StillmoonCore); `OnboardingModel.Step`.
- Produces: `LumiDirector.Line(mood:motion:text:)`, `LumiDirector.todayHeader(progress:hideProgress:isNight:) -> Line`, `LumiDirector.checkIn(level:isNight:) -> Line`, `LumiDirector.onboarding(_:) -> Line`, `LumiDirector.allLines: [String]`.

- [ ] **Step 1: Write the failing test**

Create `App/StillmoonTests/LumiDirectorTests.swift`:

```swift
import Testing
import StillmoonCore
@testable import Stillmoon

struct LumiDirectorTests {
    func progress(_ week: Int, goal: Int = 3, total: Int) -> ProgressSummary {
        ProgressSummary(windDownsThisWeek: week, weeklyGoal: goal, goalMet: week >= goal,
                        totalWindDowns: total, journeyStage: 1)
    }

    @Test func headerCountsDownToAFullMoon() {
        func text(_ p: ProgressSummary) -> String? {
            LumiDirector.todayHeader(progress: p, hideProgress: false, isNight: false).text
        }
        #expect(text(progress(2, total: 4)) == "One more wind-down fills this week's moon.")
        #expect(text(progress(0, total: 4)) == "3 more wind-downs fill this week's moon.")
        #expect(text(progress(3, total: 7)) == "This week's moon is full.")
        #expect(text(progress(5, total: 9)) == "This week's moon is full.")
        let first = LumiDirector.todayHeader(progress: progress(0, total: 0), hideProgress: false, isNight: false)
        #expect(first.mood == .wave)
        #expect(first.text == "Hi! Want to try a few calm minutes?")
    }

    @Test func hiddenProgressNeverShowsCounts() {
        let line = LumiDirector.todayHeader(progress: progress(1, total: 4), hideProgress: true, isNight: false)
        #expect(line.text == "Here whenever you need a calm minute.")
    }

    @Test func nightIsQuiet() {
        let header = LumiDirector.todayHeader(progress: progress(3, total: 9), hideProgress: false, isNight: true)
        #expect(header == LumiDirector.Line(mood: .sleepy, motion: .drift, text: nil))
        for level in 1...5 {
            let line = LumiDirector.checkIn(level: level, isNight: true)
            #expect(line.mood != .cheer)
            #expect(line.motion == .drift)
        }
    }

    @Test func checkInFollowsRestedness() {
        #expect(LumiDirector.checkIn(level: 1, isNight: false).mood == .concerned)
        #expect(LumiDirector.checkIn(level: 1, isNight: false).text == "Rough night. Let's go gently today.")
        #expect(LumiDirector.checkIn(level: 3, isNight: false).mood == .calm)
        #expect(LumiDirector.checkIn(level: 5, isNight: false)
                == LumiDirector.Line(mood: .cheer, motion: .bounce, text: "Wonderful! Hold on to that feeling."))
        #expect(LumiDirector.checkIn(level: 0, isNight: false) == LumiDirector.checkIn(level: 1, isNight: false))
        #expect(LumiDirector.checkIn(level: 8, isNight: false) == LumiDirector.checkIn(level: 5, isNight: false))
    }

    @Test func everyOnboardingStepHasALine() {
        for step in OnboardingModel.Step.allCases {
            #expect(LumiDirector.onboarding(step).text?.isEmpty == false)
        }
        #expect(LumiDirector.onboarding(.welcome).mood == .wave)
    }

    @Test func neverTalksAboutSleepMetrics() {
        let banned = ["score", "rem ", "deep", "hour", "asleep", "anxious", "stress", "streak"]
        #expect(LumiDirector.allLines.count > 15)
        for line in LumiDirector.allLines {
            for word in banned {
                #expect(!line.lowercased().contains(word), "\(line) mentions \(word)")
            }
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/LumiDirectorTests`
Expected: build error `cannot find 'LumiDirector' in scope`.

- [ ] **Step 3: Create `App/Stillmoon/Design/Lumi/LumiDirector.swift`**

```swift
import StillmoonCore

/// Decides how Lumi looks and what it says. Pure, so the PRD's rules are testable:
/// rewards habits only, never celebrates at night, never mentions sleep metrics.
enum LumiDirector {
    struct Line: Equatable {
        let mood: LumiMood
        let motion: LumiMotion
        let text: String?
    }

    /// Today's header. Counts wind-downs (a habit), never sleep.
    static func todayHeader(progress: ProgressSummary, hideProgress: Bool, isNight: Bool) -> Line {
        if isNight { return Line(mood: .sleepy, motion: .drift, text: nil) }
        if progress.totalWindDowns == 0 {
            return Line(mood: .wave, motion: .float, text: "Hi! Want to try a few calm minutes?")
        }
        if hideProgress { return Line(mood: .happy, motion: .float, text: "Here whenever you need a calm minute.") }
        if progress.windDownsThisWeek >= progress.weeklyGoal {
            return Line(mood: .happy, motion: .float, text: "This week's moon is full.")
        }
        let left = progress.weeklyGoal - progress.windDownsThisWeek
        return Line(mood: .happy, motion: .float,
                    text: left == 1 ? "One more wind-down fills this week's moon." : "\(left) more wind-downs fill this week's moon.")
    }

    static let checkInLines = [
        "Rough night. Let's go gently today.",
        "Slow mornings are allowed.",
        "Okay is perfectly okay.",
        "Nice. Let's keep tonight calm too.",
        "Wonderful! Hold on to that feeling.",
    ]

    /// Lumi mirrors the chosen restedness (1...5) with comfort, never judgement.
    static func checkIn(level: Int, isNight: Bool) -> Line {
        let i = min(max(level, 1), 5) - 1
        let moods: [LumiMood] = [.concerned, .sleepy, .calm, .happy, .cheer]
        let motion: LumiMotion = isNight ? .drift : (i == 4 ? .bounce : .float)
        return Line(mood: moods[i].effective(isNight: isNight), motion: motion, text: checkInLines[i])
    }

    static func onboarding(_ step: OnboardingModel.Step) -> Line {
        switch step {
        case .welcome: Line(mood: .wave, motion: .float, text: "Hi, I'm Lumi! I'll help you find a calmer next step each night.")
        case .goal: Line(mood: .calm, motion: .float, text: "What would you like a little help with?")
        case .schedule: Line(mood: .calm, motion: .float, text: "When do you usually sleep? I'll dim things down at bedtime.")
        case .health: Line(mood: .calm, motion: .float, text: "Got a watch? I can read its sleep estimates. They stay on this iPhone.")
        case .microphone: Line(mood: .calm, motion: .float, text: "I can listen for snoring or coughing during a session you start. Nothing is recorded.")
        case .privacy: Line(mood: .happy, motion: .float, text: "Your nights stay yours.")
        case .firstExercise: Line(mood: .happy, motion: .float, text: "Want to try a few calm minutes together?")
        }
    }

    /// Every line Lumi can say, for copy checks.
    static var allLines: [String] {
        let weeks = (0...4).map {
            ProgressSummary(windDownsThisWeek: $0, weeklyGoal: 3, goalMet: $0 >= 3, totalWindDowns: $0 + 1, journeyStage: 1)
        }
        let headers = weeks.flatMap { p in
            [false, true].compactMap { todayHeader(progress: p, hideProgress: $0, isNight: false).text }
        }
        let first = ProgressSummary(windDownsThisWeek: 0, weeklyGoal: 3, goalMet: false, totalWindDowns: 0, journeyStage: 0)
        let welcome = todayHeader(progress: first, hideProgress: false, isNight: false).text
        let onboardingLines = OnboardingModel.Step.allCases.compactMap { onboarding($0).text }
        return headers + [welcome].compactMap { $0 } + checkInLines + onboardingLines
    }
}
```

- [ ] **Step 4: Run tests**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/LumiDirectorTests`
Expected: `** TEST SUCCEEDED **`, 6 tests passed.

- [ ] **Step 5: Commit**

```bash
git add App/Stillmoon/Design/Lumi/LumiDirector.swift App/StillmoonTests/LumiDirectorTests.swift
git commit -m "feat(lumi): director for mood, motion and copy with night and metric rules

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Journey becomes "Your sky"

**Files:**
- Create: `App/Stillmoon/Features/Journey/SkyPath.swift`
- Modify: `App/Stillmoon/Features/Journey/JourneyModel.swift`
- Replace: `App/Stillmoon/Features/Journey/JourneyView.swift`
- Test: `App/StillmoonTests/SkyPathTests.swift`, `App/StillmoonTests/JourneyModelTests.swift`

**Interfaces:**
- Consumes: `ProgressCalculator.stageThresholds`, `JourneyModel.stageNames`, components (Task 1), `LumiView` (Task 2).
- Produces: `SkyStar(index:state:)`, `SkyStage(number:name:stars:)` with `litCount`, `SkyPath.stages(totalWindDowns:names:thresholds:)`, `SkyPath.stage(ofStar:thresholds:) -> Int?`, `SkyPath.xOffset(forStar:)`, `JourneyModel.sky`, `JourneyModel.nextWindDown`.

- [ ] **Step 1: Write the failing tests**

Create `App/StillmoonTests/SkyPathTests.swift`:

```swift
import Testing
@testable import Stillmoon

struct SkyPathTests {
    @Test func stagesHoldOneMoreStarEachTime() {
        let stages = SkyPath.stages(totalWindDowns: 0)
        #expect(stages.map(\.stars.count) == [1, 2, 3, 4, 5, 6])
        #expect(stages.map(\.name) == ["First light", "Quiet meadow", "Willow bend", "Still lake", "Hilltop", "Moonrise"])
        #expect(stages[0].stars[0].state == .next)
    }

    @Test func starsLightInOrder() {
        let stages = SkyPath.stages(totalWindDowns: 4)
        #expect(stages[0].stars.map(\.state) == [.lit])
        #expect(stages[1].stars.map(\.state) == [.lit, .lit])
        #expect(stages[2].stars.map(\.state) == [.lit, .next, .locked])
        #expect(stages[2].litCount == 1)
        #expect(stages.flatMap(\.stars).map(\.index) == Array(0..<21))
    }

    @Test func fullSkyHasNoNextStar() {
        for total in [21, 40] {
            let stars = SkyPath.stages(totalWindDowns: total).flatMap(\.stars)
            #expect(stars.allSatisfy { $0.state == .lit })
        }
    }

    @Test func stageOfStar() {
        #expect(SkyPath.stage(ofStar: 0) == 1)
        #expect(SkyPath.stage(ofStar: 3) == 3)
        #expect(SkyPath.stage(ofStar: 20) == 6)
        #expect(SkyPath.stage(ofStar: 21) == nil)
        #expect(SkyPath.stage(ofStar: -1) == nil)
    }

    @Test func pathZigzags() {
        #expect(SkyPath.xOffset(forStar: 0) == 0)
        #expect(SkyPath.xOffset(forStar: 2) == -90)
        #expect(SkyPath.xOffset(forStar: 8) == SkyPath.xOffset(forStar: 0))
    }
}
```

In `App/StillmoonTests/JourneyModelTests.swift`, append inside `summarisesWeekAndRecent` after the last `#expect`:

```swift
        #expect(model.sky.flatMap(\.stars).filter { $0.state == .lit }.count == 3)
        #expect(model.nextWindDown?.title == "Gentle breathing")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/SkyPathTests -only-testing:StillmoonTests/JourneyModelTests`
Expected: build error `cannot find 'SkyPath' in scope`.

- [ ] **Step 3: Create `App/Stillmoon/Features/Journey/SkyPath.swift`**

```swift
import CoreGraphics
import StillmoonCore

/// One star per wind-down on the Journey path. Stars only ever light, never unlight (PRD §8).
struct SkyStar: Identifiable, Equatable {
    enum State: Equatable { case lit, next, locked }
    let index: Int
    let state: State
    var id: Int { index }
}

struct SkyStage: Identifiable, Equatable {
    let number: Int
    let name: String
    let stars: [SkyStar]
    var id: Int { number }
    var litCount: Int { stars.filter { $0.state == .lit }.count }
}

enum SkyPath {
    /// Stage k (1...6) holds the stars between thresholds k-1 and k.
    static func stages(totalWindDowns: Int, names: [String] = JourneyModel.stageNames,
                       thresholds: [Int] = ProgressCalculator.stageThresholds) -> [SkyStage] {
        (1..<thresholds.count).map { n in
            let stars = (thresholds[n - 1]..<thresholds[n]).map { i in
                SkyStar(index: i, state: i < totalWindDowns ? .lit : (i == totalWindDowns ? .next : .locked))
            }
            return SkyStage(number: n, name: names[n], stars: stars)
        }
    }

    /// The stage holding the star at `index`, or nil outside the sky.
    static func stage(ofStar index: Int, thresholds: [Int] = ProgressCalculator.stageThresholds) -> Int? {
        (1..<thresholds.count).first { index >= thresholds[$0 - 1] && index < thresholds[$0] }
    }

    /// Horizontal offset from the path's center line: a gentle zigzag.
    static func xOffset(forStar index: Int) -> CGFloat {
        let pattern: [CGFloat] = [0, -60, -90, -60, 0, 60, 90, 60]
        return pattern[index % pattern.count]
    }
}
```

- [ ] **Step 4: Extend `JourneyModel`**

In `App/Stillmoon/Features/Journey/JourneyModel.swift`, after the `stageName` property add:

```swift
    var sky: [SkyStage] { SkyPath.stages(totalWindDowns: summary.totalWindDowns) }

    /// What the glowing "next" star starts.
    var nextWindDown: Exercise? { catalog.exercises.first { $0.category == .windDown } }
```

- [ ] **Step 5: Replace `App/Stillmoon/Features/Journey/JourneyView.swift`**

```swift
import SwiftUI
import StillmoonCore

/// "Your sky": one star per wind-down, Duolingo-style path, Lumi beside the next star.
struct JourneyView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    let model: JourneyModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    if model.isHidden {
                        Card {
                            Text("Progress is hidden. You can show it again in Settings.")
                                .foregroundStyle(theme.secondaryText)
                        }
                    } else {
                        weekCard
                        ForEach(model.sky) { stage in
                            StageBanner(stage: stage)
                            VStack(spacing: 14) {
                                ForEach(stage.stars) { star in
                                    StarNode(star: star, nextTitle: model.nextWindDown?.title, onStart: startNext)
                                        .offset(x: SkyPath.xOffset(forStar: star.index))
                                        .frame(maxWidth: .infinity)
                                        .id(star.index)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        if !model.recent.isEmpty { recentCard }
                    }
                }
                .padding()
            }
            .onAppear {
                model.refresh()
                let target = min(model.summary.totalWindDowns, 20)
                Task { proxy.scrollTo(target, anchor: .center) }
            }
        }
        .foregroundStyle(theme.text)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Your sky")
    }

    private func startNext() {
        guard let exercise = model.nextWindDown else { return }
        env.playerRequest = PlayerRequest(exerciseID: exercise.id)
    }

    private var weekCard: some View {
        let done = min(model.summary.windDownsThisWeek, model.summary.weeklyGoal)
        let goal = model.summary.weeklyGoal
        return Card {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(theme.cardBorder, lineWidth: 8)
                    Circle().trim(from: 0, to: CGFloat(done) / CGFloat(max(goal, 1)))
                        .stroke(theme.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(done)/\(goal)").font(.subheadline.bold())
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(done) of \(goal) wind-downs this week").font(.headline)
                    Text("Missed days are fine. Your sky only grows.")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var recentCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recently").font(.headline).accessibilityAddTraits(.isHeader)
                ForEach(model.recent) { item in
                    HStack {
                        Text(item.title)
                        Spacer()
                        Text(item.completedAt, format: .dateTime.month().day())
                            .foregroundStyle(theme.secondaryText)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

private struct StageBanner: View {
    @Environment(\.theme) private var theme
    let stage: SkyStage

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Stage \(stage.number)").font(.caption.weight(.heavy)).textCase(.uppercase)
                Text(stage.name).font(.title3.bold())
            }
            Spacer()
            Text("\(stage.litCount) of \(stage.stars.count) stars").font(.subheadline.bold())
        }
        .foregroundStyle(theme.onAccent)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(shape.fill(theme.accent))
        .background(shape.fill(theme.accentEdge).offset(y: theme.isNight ? 0 : 5))
        .padding(.bottom, theme.isNight ? 0 : 5)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct StarNode: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let star: SkyStar
    let nextTitle: String?
    let onStart: () -> Void
    @State private var pulsing = false

    var body: some View {
        switch star.state {
        case .lit:
            node(fill: theme.moon, edge: theme.moonEdge, symbol: "star.fill", tint: .white, size: 56)
                .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                .accessibilityElement()
                .accessibilityLabel("Star \(star.index + 1), lit")
        case .locked:
            node(fill: theme.cardBorder, edge: theme.secondaryText.opacity(0.25), symbol: "star.fill",
                 tint: theme.secondaryText.opacity(0.4), size: 56)
                .accessibilityElement()
                .accessibilityLabel("Star \(star.index + 1), not lit yet")
        case .next:
            Button(action: onStart) {
                node(fill: theme.accent, edge: theme.accentEdge, symbol: "play.fill", tint: theme.onAccent, size: 68)
            }
            .buttonStyle(.plain)
            .background {
                Circle().fill(theme.accent)
                    .frame(width: 68, height: 68)
                    .scaleEffect(pulsing ? 1.6 : 1)
                    .opacity(pulsing ? 0 : 0.5)
            }
            .overlay(alignment: .top) {
                Text("TONIGHT")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(theme.cardBorder, lineWidth: 2))
                    .offset(y: -30)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: SkyPath.xOffset(forStar: star.index) > 0 ? .leading : .trailing) {
                LumiView(mood: .happy, motion: .float, size: 90)
                    .offset(x: SkyPath.xOffset(forStar: star.index) > 0 ? -100 : 100)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) { pulsing = true }
            }
            .accessibilityLabel(nextTitle.map { "Next star. Start \($0)" } ?? "Next star")
        }
    }

    private func node(fill: Color, edge: Color, symbol: String, tint: Color, size: CGFloat) -> some View {
        ZStack {
            Circle().fill(edge).offset(y: 6)
            Circle().fill(fill)
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .padding(.bottom, 6)
    }
}
```

- [ ] **Step 6: Check the old path view is unused**

Run: `grep -rn "JourneyPath" App`
Expected: no output.

- [ ] **Step 7: Run tests**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/SkyPathTests -only-testing:StillmoonTests/JourneyModelTests`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 8: Commit**

```bash
git add App/Stillmoon/Features/Journey App/StillmoonTests/SkyPathTests.swift App/StillmoonTests/JourneyModelTests.swift
git commit -m "feat(journey): Your sky path with stage banners, pulsing next star and Lumi

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Breathing player and daytime completion

**Files:**
- Create: `App/Stillmoon/Features/Exercises/Completion.swift`
- Create: `App/Stillmoon/Features/Exercises/CompletionView.swift`
- Modify: `App/Stillmoon/Features/Exercises/PlayerModel.swift`
- Replace: `App/Stillmoon/Features/Exercises/PlayerView.swift`
- Modify: `App/Stillmoon/Root/RootView.swift`
- Test: `App/StillmoonTests/CompletionTests.swift`, `App/StillmoonTests/PlayerModelTests.swift`

**Interfaces:**
- Consumes: `SkyPath.stage(ofStar:thresholds:)` (Task 4), `LumiView` (Task 2), components (Task 1).
- Produces: `CompletionStyle.style(for:isNight:)`, `CompletionSummary(progress:playedSeconds:savedToHealth:names:thresholds:)` with `minutes, windDownsThisWeek, weeklyGoal, star: Star?, savedToHealth`; `PlayerModel.progress(weeklyGoal:calendar:) -> ProgressSummary`; `PlayerView(exercise:store:weeklyGoal:savesToHealth:onFinish:)`; `CompletionView(summary:onDone:)`.

- [ ] **Step 1: Write the failing tests**

Create `App/StillmoonTests/CompletionTests.swift`:

```swift
import Testing
import StillmoonCore
@testable import Stillmoon

struct CompletionTests {
    @Test func celebratesOnlyDaytimeWindDowns() {
        #expect(CompletionStyle.style(for: .windDown, isNight: false) == .celebrate)
        #expect(CompletionStyle.style(for: .windDown, isNight: true) == .quiet)
        #expect(CompletionStyle.style(for: .awakeAtNight, isNight: false) == .quiet)
        #expect(CompletionStyle.style(for: .morningReset, isNight: false) == .quiet)
    }

    @Test func summaryNamesTheStarJustLit() {
        let progress = ProgressSummary(windDownsThisWeek: 3, weeklyGoal: 3, goalMet: true, totalWindDowns: 5, journeyStage: 3)
        let summary = CompletionSummary(progress: progress, playedSeconds: 290, savedToHealth: true)
        #expect(summary.minutes == 5)
        #expect(summary.windDownsThisWeek == 3)
        #expect(summary.star == CompletionSummary.Star(stageName: "Willow bend", litInStage: 2, starsInStage: 3))
        #expect(summary.savedToHealth)
    }

    @Test func summaryPastTheLastStarHasNoStar() {
        let progress = ProgressSummary(windDownsThisWeek: 1, weeklyGoal: 3, goalMet: false, totalWindDowns: 22, journeyStage: 6)
        #expect(CompletionSummary(progress: progress, playedSeconds: 20, savedToHealth: false).star == nil)
        #expect(CompletionSummary(progress: progress, playedSeconds: 20, savedToHealth: false).minutes == 1)
    }
}
```

In `App/StillmoonTests/PlayerModelTests.swift`, add inside the suite:

```swift
    @Test func progressIncludesTheFinishedWindDown() throws {
        let store = try TestEnv.store()
        let now = TestEnv.d(2026, 10, 2, 21)
        let model = PlayerModel(exercise: TestEnv.catalog.exercises[0], store: store, now: { now })
        model.play()
        model.skipStep()
        model.skipStep()
        #expect(model.isComplete)
        let progress = model.progress(weeklyGoal: 3, calendar: TestEnv.cal)
        #expect(progress.windDownsThisWeek == 1)
        #expect(progress.totalWindDowns == 1)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/CompletionTests -only-testing:StillmoonTests/PlayerModelTests`
Expected: build error `cannot find 'CompletionStyle' in scope`.

- [ ] **Step 3: Create `App/Stillmoon/Features/Exercises/Completion.swift`**

```swift
import StillmoonCore

enum CompletionStyle: Equatable {
    /// Daytime wind-down: Lumi cheers, the weekly moon fills, a star lights.
    case celebrate
    /// Night, or any other exercise: the player's quiet "Well done. Rest now." (PRD §7: no reward at night).
    case quiet

    static func style(for category: ExerciseCategory, isNight: Bool) -> CompletionStyle {
        category == .windDown && !isNight ? .celebrate : .quiet
    }
}

/// What the celebration shows, from progress that already includes this completion.
struct CompletionSummary: Equatable {
    struct Star: Equatable {
        let stageName: String
        let litInStage: Int
        let starsInStage: Int
    }

    let minutes: Int
    let windDownsThisWeek: Int
    let weeklyGoal: Int
    /// The star this completion lit; nil once the sky is full.
    let star: Star?
    let savedToHealth: Bool

    init(progress: ProgressSummary, playedSeconds: Int, savedToHealth: Bool,
         names: [String] = JourneyModel.stageNames, thresholds: [Int] = ProgressCalculator.stageThresholds) {
        minutes = max(1, Int((Double(playedSeconds) / 60).rounded()))
        windDownsThisWeek = progress.windDownsThisWeek
        weeklyGoal = progress.weeklyGoal
        self.savedToHealth = savedToHealth
        let index = progress.totalWindDowns - 1
        if let stage = SkyPath.stage(ofStar: index, thresholds: thresholds) {
            star = Star(stageName: names[stage], litInStage: index - thresholds[stage - 1] + 1,
                        starsInStage: thresholds[stage] - thresholds[stage - 1])
        } else {
            star = nil
        }
    }
}
```

- [ ] **Step 4: Add `progress` to `PlayerModel`**

In `App/Stillmoon/Features/Exercises/PlayerModel.swift`, after `finish()` add:

```swift
    /// Progress including this completion, for the daytime celebration.
    func progress(weeklyGoal: Int, calendar: Calendar) -> ProgressSummary {
        ProgressCalculator.summary(completions: store.completions(), weeklyGoal: weeklyGoal, now: now(), calendar: calendar)
    }
```

- [ ] **Step 5: Create `App/Stillmoon/Features/Exercises/CompletionView.swift`**

```swift
import SwiftUI

/// Daytime wind-down celebration (spec "Completion"). Never shown at night.
struct CompletionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let summary: CompletionSummary
    let onDone: () -> Void
    private let theme = Theme.day
    @State private var newMoonShown = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack {
                    Rays()
                    LumiView(mood: .cheer, motion: .bounce, size: 190)
                }
                .frame(height: 250)
                Text("Wind-down done!")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("You gave yourself \(summary.minutes) calm \(summary.minutes == 1 ? "minute" : "minutes").")
                    .font(.headline)
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
                weekCard
                if let star = summary.star { starCard(star) }
                if summary.savedToHealth {
                    Text("Saved to Apple Health as Mindful Minutes")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                }
                Button("Continue", action: onDone)
                    .buttonStyle(ChunkyButtonStyle())
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .foregroundStyle(theme.text)
        .background(theme.accentSoft.ignoresSafeArea())
        .environment(\.theme, theme)
        .preferredColorScheme(.light)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.5).delay(0.7)) {
                newMoonShown = true
            }
        }
    }

    private var weekCard: some View {
        let shown = min(summary.windDownsThisWeek, summary.weeklyGoal)
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("This week").font(.headline)
                    Spacer()
                    Text("\(shown) of \(summary.weeklyGoal)").font(.subheadline.weight(.heavy)).foregroundStyle(theme.accent)
                }
                HStack(spacing: 12) {
                    ForEach(0..<min(summary.weeklyGoal, 7), id: \.self) { i in
                        MoonPhaseView(level: i < shown ? 5 : 1, background: theme.surface, size: 44)
                            .scaleEffect(i == shown - 1 && !newMoonShown ? 0.01 : 1)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(shown) of \(summary.weeklyGoal) wind-downs this week")
                Text(shown >= summary.weeklyGoal ? "This week's moon is full." : "Every wind-down fills a little more.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }

    private func starCard(_ star: CompletionSummary.Star) -> some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.title)
                    .foregroundStyle(theme.moon)
                    .scaleEffect(newMoonShown ? 1 : 0.01)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("A new star lit up in Lumi's sky").font(.headline)
                    Text("\(star.stageName) · \(star.litInStage) of \(star.starsInStage) stars")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// Slowly turning soft rays behind Lumi.
private struct Rays: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { context in
            let turn = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 40) / 40 * 360
            Canvas { gc, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let r = max(size.width, size.height)
                for i in 0..<8 {
                    let a = (Double(i) * 45 + turn) * .pi / 180
                    var ray = Path()
                    ray.move(to: c)
                    ray.addLine(to: CGPoint(x: c.x + r * cos(a - 0.09), y: c.y + r * sin(a - 0.09)))
                    ray.addLine(to: CGPoint(x: c.x + r * cos(a + 0.09), y: c.y + r * sin(a + 0.09)))
                    ray.closeSubpath()
                    gc.fill(ray, with: .color(.white.opacity(0.6)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
```

- [ ] **Step 6: Replace `App/Stillmoon/Features/Exercises/PlayerView.swift`**

```swift
import SwiftUI
import UIKit
import StillmoonCore

/// Always dim (PRD §2 night interaction): large controls, minimal text, no reward animation.
/// A finished daytime wind-down hands over to `CompletionView`.
struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    /// The app's theme outside the player (the player itself is always dim).
    @Environment(\.theme) private var appTheme
    @State private var model: PlayerModel
    @State private var celebration: CompletionSummary?
    private let weeklyGoal: Int
    private let savesToHealth: Bool
    private let theme = Theme.night

    init(exercise: Exercise, store: LocalStore, weeklyGoal: Int = 3, savesToHealth: Bool = false,
         onFinish: ((DateInterval) -> Void)? = nil) {
        _model = State(initialValue: PlayerModel(exercise: exercise, store: store, onFinish: onFinish))
        self.weeklyGoal = weeklyGoal
        self.savesToHealth = savesToHealth
    }

    var body: some View {
        Group {
            if let celebration {
                CompletionView(summary: celebration) { dismiss() }
                    .transition(.opacity)
            } else {
                player
            }
        }
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { break }
                guard !Task.isCancelled else { break }
                model.tick()
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            if model.stepIndex == 0 && model.elapsedInStep == 0 && !model.isComplete { model.play() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.pause() }
        }
        .onChange(of: model.isComplete) { _, done in
            guard done, CompletionStyle.style(for: model.exercise.category, isNight: appTheme.isNight) == .celebrate else { return }
            let summary = CompletionSummary(progress: model.progress(weeklyGoal: weeklyGoal, calendar: .current),
                                            playedSeconds: model.playedSeconds, savedToHealth: savesToHealth)
            withAnimation(.easeInOut(duration: 0.4)) { celebration = summary }
        }
        .onDisappear {
            model.pause()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var total: Int { model.exercise.durationSeconds }

    private var player: some View {
        VStack(spacing: 24) {
            HStack {
                Button { model.pause(); dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .background(theme.surface, in: Circle())
                }
                .accessibilityLabel(model.isComplete ? "Close" : "End exercise")
                Spacer()
                Text(model.exercise.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.secondaryText)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer()
            if model.isComplete {
                LumiView(mood: .sleepy, motion: .drift, size: 140)
                Text("Well done. Rest now.")
                    .font(.title.weight(.semibold))
                    .multilineTextAlignment(.center)
                Button("Done") { dismiss() }
                    .buttonStyle(ChunkyButtonStyle())
                    .padding(.horizontal, 40)
            } else {
                ZStack {
                    BreathingRings()
                    LumiView(mood: .calm, motion: .breathe(period: 8), size: 170)
                }
                .frame(width: 280, height: 280)
                Text(model.currentStep.text)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 90)
                VStack(spacing: 6) {
                    ProgressView(value: Double(total - model.remainingSeconds), total: Double(max(total, 1)))
                        .tint(theme.accent)
                        .accessibilityHidden(true)
                    HStack {
                        Text(Format.clock(seconds: total - model.remainingSeconds))
                            .accessibilityHidden(true)
                        Spacer()
                        Text(Format.clock(seconds: model.remainingSeconds))
                            .accessibilityLabel("\(Format.exerciseLength(seconds: model.remainingSeconds)) left")
                    }
                    .font(.footnote.monospacedDigit().weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                }
                HStack(spacing: 40) {
                    Button { model.togglePlay() } label: {
                        Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(theme.onAccent)
                            .frame(width: 84, height: 84)
                            .background(theme.accent, in: Circle())
                    }
                    .accessibilityLabel(model.isPlaying ? "Pause" : "Play")
                    Button { model.skipStep() } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.title2)
                            .frame(width: 56, height: 56)
                            .background(theme.surface, in: Circle())
                    }
                    .accessibilityLabel("Next step")
                }
            }
            Spacer()
        }
        .padding()
        .foregroundStyle(theme.text)
        .tint(theme.accent)
        .background(theme.background.ignoresSafeArea())
        .environment(\.theme, theme)
        .preferredColorScheme(.dark)
    }
}

/// Two soft rings breathing on the same 8 s cycle as Lumi.
private struct BreathingRings: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let k = reduceMotion ? 0.5 : LumiAnimation.wave(context.date.timeIntervalSinceReferenceDate, period: 8)
            ZStack {
                Circle().fill(theme.accentSoft.opacity(0.6)).scaleEffect(0.78 + 0.3 * k)
                Circle().fill(theme.accentSoft).padding(40).scaleEffect(0.78 + 0.3 * k)
            }
        }
        .accessibilityHidden(true)
    }
}
```

- [ ] **Step 7: Pass weekly goal and Health state from `RootView`**

In `App/Stillmoon/Root/RootView.swift`, replace

```swift
                PlayerView(exercise: exercise, store: env.store) { interval in
```

with

```swift
                PlayerView(exercise: exercise, store: env.store,
                           weeklyGoal: env.settings.settings.weeklyGoal,
                           savesToHealth: env.settings.settings.healthConnected) { interval in
```

- [ ] **Step 8: Run tests**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/CompletionTests -only-testing:StillmoonTests/PlayerModelTests`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 9: Commit**

```bash
git add App/Stillmoon/Features/Exercises App/Stillmoon/Root/RootView.swift App/StillmoonTests/CompletionTests.swift App/StillmoonTests/PlayerModelTests.swift
git commit -m "feat(player): breathing Lumi player and daytime wind-down celebration

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Today (sky header, new cards, night scene)

**Files:**
- Create: `App/Stillmoon/Features/Today/StageBar.swift`
- Modify: `App/Stillmoon/Features/Today/TodayModel.swift`
- Replace: `App/Stillmoon/Features/Today/TodayView.swift`
- Modify: `App/Stillmoon/Features/Sleep/CheckInSheet.swift` (init only, full redesign in Task 7)
- Test: `App/StillmoonTests/StageBarTests.swift`, `App/StillmoonTests/TodayModelTests.swift`

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces: `StageBar(timeline:)`, `StageBar.segments(_:) -> [StageBar.Segment]` (`stage`, `fraction`); `TodayModel.meta(for:) -> String?`; `CheckInSheet(existing:initialLevel:onSave:)`.

- [ ] **Step 1: Write the failing tests**

Create `App/StillmoonTests/StageBarTests.swift`:

```swift
import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct StageBarTests {
    func sample(_ stage: SleepStage, _ from: Int, _ to: Int) -> SleepSample {
        SleepSample(stage: stage, start: TestEnv.d(2026, 10, 2, 0, from), end: TestEnv.d(2026, 10, 2, 0, to), sourceName: "Watch")
    }

    @Test func mergesNeighboursAndSkipsInBed() {
        let segments = StageBar.segments([
            sample(.inBed, 0, 60), sample(.core, 0, 10), sample(.core, 10, 20), sample(.deep, 20, 30), sample(.awake, 30, 40),
        ])
        #expect(segments.map(\.stage) == [.core, .deep, .awake])
        #expect(abs(segments[0].fraction - 0.5) < 0.001)
        #expect(abs(segments.map(\.fraction).reduce(0, +) - 1) < 0.001)
    }

    @Test func emptyTimelineHasNoSegments() {
        #expect(StageBar.segments([]).isEmpty)
        #expect(StageBar.segments([sample(.inBed, 0, 30)]).isEmpty)
    }
}
```

In `App/StillmoonTests/TodayModelTests.swift`, add inside the suite:

```swift
    @Test func metaDescribesExercisesOnly() throws {
        let model = TodayModel(store: try TestEnv.store(), settings: TestEnv.settings(), catalog: TestEnv.catalog)
        let exercise = ResolvedRecommendation(itemID: "breath", kind: .exercise, title: "Gentle breathing", reason: "")
        let article = ResolvedRecommendation(itemID: "steady-bedtime", kind: .article, title: "Keeping a steady bedtime", reason: "")
        #expect(model.meta(for: exercise) == "1 min · Text")
        #expect(model.meta(for: article) == nil)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/StageBarTests -only-testing:StillmoonTests/TodayModelTests`
Expected: build error `cannot find 'StageBar' in scope`.

- [ ] **Step 3: Create `App/Stillmoon/Features/Today/StageBar.swift`**

```swift
import SwiftUI
import StillmoonCore

/// A compact strip of last night's estimated stages in time order. The card's text says the same, so it is hidden from VoiceOver.
struct StageBar: View {
    @Environment(\.theme) private var theme
    let timeline: [SleepSample]

    struct Segment: Equatable {
        let stage: SleepStage
        let fraction: Double
    }

    /// Consecutive samples of one stage merge; "in bed" is not a stage to show.
    static func segments(_ timeline: [SleepSample]) -> [Segment] {
        var merged: [(stage: SleepStage, seconds: Double)] = []
        for sample in timeline where sample.stage != .inBed {
            let seconds = max(0, sample.end.timeIntervalSince(sample.start))
            if let last = merged.last, last.stage == sample.stage {
                merged[merged.count - 1].seconds += seconds
            } else {
                merged.append((sample.stage, seconds))
            }
        }
        let total = merged.reduce(0) { $0 + $1.seconds }
        guard total > 0 else { return [] }
        return merged.map { Segment(stage: $0.stage, fraction: $0.seconds / total) }
    }

    var body: some View {
        let segments = Self.segments(timeline)
        GeometryReader { geo in
            let usable = geo.size.width - CGFloat(max(0, segments.count - 1)) * 2
            HStack(spacing: 2) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    Rectangle()
                        .fill(color(segment.stage))
                        .frame(width: max(2, usable * segment.fraction))
                }
            }
        }
        .frame(height: 12)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    private func color(_ stage: SleepStage) -> Color {
        switch stage {
        case .awake: theme.accent2
        case .deep: theme.accent
        case .rem: theme.accent.opacity(0.7)
        case .core, .asleepUnspecified, .inBed: theme.accent.opacity(0.4)
        }
    }
}
```

- [ ] **Step 4: Add `meta(for:)` to `TodayModel`**

In `App/Stillmoon/Features/Today/TodayModel.swift`, after `var hideProgress` add:

```swift
    /// "5 min · Audio" for exercises; nil for articles.
    func meta(for rec: ResolvedRecommendation) -> String? {
        guard let exercise = catalog.exercise(id: rec.itemID) else { return nil }
        return "\(Format.exerciseLength(seconds: exercise.durationSeconds)) · \(exercise.format == .audio ? "Audio" : "Text")"
    }
```

- [ ] **Step 5: Let the check-in sheet start at a tapped level**

In `App/Stillmoon/Features/Sleep/CheckInSheet.swift`, change the initializer signature and the restedness line:

```swift
    init(existing: CheckIn?, initialLevel: Int? = nil, onSave: @escaping (CheckIn) -> Void) {
        self.existing = existing
        self.onSave = onSave
        _restedness = State(initialValue: initialLevel ?? existing?.restedness ?? 3)
```

(the remaining `_tense`, `_woke`, `_persistent`, `_note` lines stay).

- [ ] **Step 6: Replace `App/Stillmoon/Features/Today/TodayView.swift`**

```swift
import SwiftUI
import StillmoonCore

struct TodayView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let model: TodayModel
    @State private var showingCheckIn = false
    @State private var checkInLevel: Int?
    @State private var showingJournal = false
    @State private var showingSettings = false
    @State private var showEverythingAtNight = false

    var body: some View {
        ScrollView {
            if theme.isNight && !showEverythingAtNight {
                nightContent
            } else {
                VStack(spacing: 0) {
                    header
                    dayContent
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(theme.background,
                                    in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous))
                        .padding(.top, -28)
                }
            }
        }
        .foregroundStyle(theme.text)
        .background(alignment: .top) { theme.sky.frame(height: 400).ignoresSafeArea() }
        .background(theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingCheckIn, onDismiss: model.refresh) {
            CheckInSheet(existing: model.todayCheckIn, initialLevel: checkInLevel) { model.saveCheckIn($0) }
        }
        .sheet(isPresented: $showingJournal, onDismiss: model.refresh) {
            JournalEntryForm { model.saveJournalEntry($0) }
        }
        .sheet(isPresented: $showingSettings, onDismiss: { Task { await model.refreshHealth() } }) {
            SettingsView()
        }
        .task { await model.refreshHealth() }
        .onChange(of: theme.isNight) { _, _ in showEverythingAtNight = false }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await model.refreshHealth() } } }
    }

    // MARK: Shared pieces

    private var settingsButton: some View {
        Button { showingSettings = true } label: {
            Image(systemName: "person.fill")
                .font(.headline)
                .foregroundStyle(theme.accent)
                .frame(width: 44, height: 44)
                .background(theme.surface, in: Circle())
        }
        .accessibilityLabel("Settings")
    }

    private var greetingBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.greeting)
                .font(.largeTitle.bold())
                .accessibilityIdentifier("greeting")
                .accessibilityAddTraits(.isHeader)
            Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
        }
    }

    private var showsSoundStart: Bool {
        env.sound.isAvailable && !env.sound.isActive && env.playerRequest == nil
    }

    // MARK: Night: one card, large controls, nothing to track (PRD §7).

    @ViewBuilder private var nightContent: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.greeting)
                        .font(.title.weight(.semibold))
                        .accessibilityIdentifier("greeting")
                        .accessibilityAddTraits(.isHeader)
                    Text("Night mode is on")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer()
                settingsButton
            }
            VStack(spacing: 0) {
                LumiView(mood: .sleepy, motion: .drift, size: 150)
                Cloud().fill(theme.surface).frame(width: 200, height: 40).padding(.top, -30)
                    .accessibilityHidden(true)
            }
            switch model.nightPhase(at: .now) {
            case .windDown: windDownCard
            case .awake: awakeCard
            }
            Button("Show everything") { showEverythingAtNight = true }
                .font(.headline)
                .frame(minHeight: 44)
        }
        .padding(20)
        .background(alignment: .top) {
            StarField(stars: StarField.night, color: Color(hex: 0xCFC6EE), period: 6, alphaRange: 0.15...0.6)
                .frame(height: 420)
        }
    }

    @ViewBuilder private var windDownCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Time to wind down").font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                if let suggestion = model.windDownSuggestion {
                    Text(suggestion.title).font(.title3.weight(.bold))
                    if !suggestion.reason.isEmpty {
                        Text(suggestion.reason).foregroundStyle(theme.secondaryText)
                    }
                    Button {
                        env.playerRequest = PlayerRequest(exerciseID: suggestion.itemID)
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle())
                    .accessibilityLabel("Start \(suggestion.title)")
                } else {
                    Text("Dim the lights and breathe out slowly. Resting is enough.")
                }
                if showsSoundStart { SoundStartButton() }
            }
        }
    }

    @ViewBuilder private var awakeCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Awake at night?").font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                Text("A few quiet minutes can help you settle. There's nothing to track.")
                    .foregroundStyle(theme.secondaryText)
                if let exercise = model.awakeAtNightExercise {
                    Button {
                        env.playerRequest = PlayerRequest(exerciseID: exercise.id)
                    } label: {
                        Label(exercise.title, systemImage: "play.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle())
                } else {
                    Text("Breathe out slowly, a little longer than you breathe in. Resting is enough.")
                }
            }
        }
    }

    // MARK: Day

    private var header: some View {
        let line = LumiDirector.todayHeader(progress: model.progress, hideProgress: model.hideProgress, isNight: theme.isNight)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                if !model.hideProgress { WeekPill(progress: model.progress) }
                Spacer()
                settingsButton
            }
            if dynamicTypeSize.isAccessibilitySize {
                greetingBlock
                if let text = line.text { SpeechBubble(text: text) }
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: .leading, spacing: 14) {
                        greetingBlock
                        if let text = line.text { SpeechBubble(text: text, tail: .trailing) }
                    }
                    Spacer(minLength: 0)
                    LumiView(mood: line.mood, motion: line.motion, size: 130)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 44)
        .background { SkyBackdrop().ignoresSafeArea(edges: .top) }
    }

    @ViewBuilder private var dayContent: some View {
        VStack(spacing: 14) {
            checkInCard.riseIn()
            lastNightCard.riseIn(delay: 0.08)
            if model.showsDifficultyCard {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("If sleep has been hard for weeks, it can help to talk with a doctor.")
                        NavigationLink("When to talk to a doctor", value: Route.article(TodayModel.doctorArticleID))
                            .font(.headline)
                    }
                }
            }
            if model.showsSnoringNote {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Frequent loud snoring is worth mentioning to a doctor.")
                        NavigationLink("When to talk to a doctor", value: Route.article(TodayModel.doctorArticleID))
                            .font(.headline)
                        Button("Dismiss") { model.dismissSnoringNote() }
                    }
                }
            }
            if let first = model.recommendations.first {
                suggestionCard(first).riseIn(delay: 0.16)
            }
            if model.recommendations.count > 1 {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Also for you").font(.headline).accessibilityAddTraits(.isHeader)
                        ForEach(model.recommendations.dropFirst()) { rec in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    NavigationLink(rec.title, value: rec.route).font(.headline)
                                    Text(rec.reason).font(.caption).foregroundStyle(theme.secondaryText)
                                }
                                Spacer()
                                feedbackMenu(rec.itemID, title: rec.title)
                            }
                        }
                    }
                }
            }
            if showsSoundStart { SoundStartButton() }
        }
    }

    @ViewBuilder private var checkInCard: some View {
        Card {
            if let checkIn = model.todayCheckIn {
                HStack(spacing: 12) {
                    MoonPhaseView(level: checkIn.restedness, background: theme.surface, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You checked in: \(MoonPhase.label(level: checkIn.restedness))").font(.headline)
                        Text("Kept apart from your watch's estimates")
                            .font(.footnote)
                            .foregroundStyle(theme.secondaryText)
                    }
                    Spacer()
                    Button("Edit") {
                        checkInLevel = nil
                        showingCheckIn = true
                    }
                    .font(.headline)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("How rested do you feel?").font(.headline).accessibilityAddTraits(.isHeader)
                    HStack(spacing: 0) {
                        ForEach(1...5, id: \.self) { level in
                            MoonButton(level: level, isSelected: false, size: 54) {
                                checkInLevel = level
                                showingCheckIn = true
                            }
                            if level < 5 { Spacer(minLength: 4) }
                        }
                    }
                    HStack {
                        Text("Not rested")
                        Spacer()
                        Text("Very rested")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                    .accessibilityHidden(true)
                }
            }
        }
    }

    @ViewBuilder private var lastNightCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Last night").font(.headline).accessibilityAddTraits(.isHeader)
                    Spacer()
                    if let report = model.lastNightReport {
                        LabelPill(text: "\(report.primarySource) estimate")
                    } else if model.lastNight != nil {
                        LabelPill(text: "You recorded")
                    }
                }
                if let report = model.lastNightReport {
                    Text(NightSummary.estimateLine(report)).font(.title3.weight(.semibold))
                    Text("\(report.sleepStart.formatted(date: .omitted, time: .shortened)) to \(report.sleepEnd.formatted(date: .omitted, time: .shortened))")
                        .foregroundStyle(theme.secondaryText)
                    if report.hasStageDetail { StageBar(timeline: report.timeline) }
                    if let entry = model.lastNight {
                        Text("You recorded \(Format.duration(minutes: entry.inBedMinutes)) in bed")
                            .foregroundStyle(theme.secondaryText)
                    }
                } else if let entry = model.lastNight {
                    Text("You recorded \(Format.duration(minutes: entry.inBedMinutes)) in bed")
                        .font(.title3.weight(.semibold))
                    Text("\(entry.bedtime.formatted(date: .omitted, time: .shortened)) to \(entry.wakeTime.formatted(date: .omitted, time: .shortened))")
                        .foregroundStyle(theme.secondaryText)
                } else {
                    Text("Nothing recorded for last night yet.")
                        .foregroundStyle(theme.secondaryText)
                    Button("Add last night") { showingJournal = true }
                        .font(.headline)
                }
            }
        }
    }

    private func suggestionCard(_ rec: ResolvedRecommendation) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    IconTile(systemName: rec.kind == .exercise ? "wind" : "book.closed")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Suggested for you")
                            .font(.caption.weight(.heavy))
                            .textCase(.uppercase)
                            .foregroundStyle(theme.secondaryText)
                        NavigationLink(value: rec.route) {
                            Text(rec.title).font(.headline).multilineTextAlignment(.leading)
                        }
                        .foregroundStyle(theme.text)
                        if let meta = model.meta(for: rec) {
                            Text(meta).font(.footnote.weight(.semibold)).foregroundStyle(theme.secondaryText)
                        }
                    }
                    Spacer(minLength: 0)
                    if rec.kind == .exercise {
                        Button {
                            env.playerRequest = PlayerRequest(exerciseID: rec.itemID)
                        } label: {
                            Image(systemName: "play.fill").font(.title3)
                        }
                        .buttonStyle(RoundChunkyButtonStyle())
                        .accessibilityLabel("Start \(rec.title)")
                    }
                }
                HStack(alignment: .top) {
                    ReasonLine(reason: rec.reason)
                    feedbackMenu(rec.itemID, title: rec.title)
                }
            }
        }
    }

    private func feedbackMenu(_ itemID: String, title: String) -> some View {
        Menu {
            Button("Helpful") { model.rate(itemID, .helpful) }
            Button("Not relevant") { model.rate(itemID, .irrelevant) }
            Button("Don't show this again", role: .destructive) { model.rate(itemID, .unwanted) }
        } label: {
            Image(systemName: "ellipsis")
                .font(.headline)
                .foregroundStyle(theme.secondaryText)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Rate \(title)")
    }
}

/// "2 of 3 this week" with the week's moon filling up.
private struct WeekPill: View {
    @Environment(\.theme) private var theme
    let progress: ProgressSummary

    var body: some View {
        HStack(spacing: 8) {
            MoonPhaseView(level: MoonPhase.level(done: progress.windDownsThisWeek, goal: progress.weeklyGoal),
                          background: theme.surface, size: 24)
            Text("\(min(progress.windDownsThisWeek, progress.weeklyGoal)) of \(progress.weeklyGoal) this week")
                .font(.subheadline.weight(.heavy))
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .frame(minHeight: 40)
        .background(theme.surface, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(min(progress.windDownsThisWeek, progress.weeklyGoal)) of \(progress.weeklyGoal) wind-downs this week")
    }
}
```

- [ ] **Step 7: Run tests**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/StageBarTests -only-testing:StillmoonTests/TodayModelTests`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 8: Look at Today**

Build and run on the iPhone 17 Pro simulator (`xcodebuild build` then launch, or Xcode Run) with `-ui-testing`, finish onboarding, and check: sky header with Lumi and bubble, moon buttons open the check-in sheet, suggestion card with round play button and "Why:" line. Toggle Settings › Night mode › On and check the night scene.

- [ ] **Step 9: Commit**

```bash
git add App/Stillmoon/Features/Today App/Stillmoon/Features/Sleep/CheckInSheet.swift App/StillmoonTests/StageBarTests.swift App/StillmoonTests/TodayModelTests.swift
git commit -m "feat(today): sky header with Lumi, moon check-in, chunky suggestion card, night scene

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Check-in sheet with Lumi

**Files:**
- Replace: `App/Stillmoon/Features/Sleep/CheckInSheet.swift`

**Interfaces:**
- Consumes: `LumiDirector.checkIn(level:isNight:)` (Task 3), `MoonButton`, `Chip`, `FlowLayout`, `SpeechBubble`, `ChunkyButtonStyle` (Task 1).
- Produces: same `CheckInSheet(existing:initialLevel:onSave:)` API; same `CheckIn` saved.

- [ ] **Step 1: Replace `App/Stillmoon/Features/Sleep/CheckInSheet.swift`**

```swift
import SwiftUI
import StillmoonCore

/// Morning check-in: Lumi mirrors the chosen restedness. What the user reports stays separate from estimates (PRD principle 3).
struct CheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    private let existing: CheckIn?
    private let onSave: (CheckIn) -> Void
    @State private var restedness: Int
    @State private var tense: Bool
    @State private var woke: Bool
    @State private var persistent: Bool
    @State private var note: String

    init(existing: CheckIn?, initialLevel: Int? = nil, onSave: @escaping (CheckIn) -> Void) {
        self.existing = existing
        self.onSave = onSave
        _restedness = State(initialValue: initialLevel ?? existing?.restedness ?? 3)
        _tense = State(initialValue: existing?.tenseAtBedtime ?? false)
        _woke = State(initialValue: existing?.wokeDuringNight ?? false)
        _persistent = State(initialValue: existing?.persistentDifficulty ?? false)
        _note = State(initialValue: existing?.note ?? "")
    }

    var body: some View {
        let line = LumiDirector.checkIn(level: restedness, isNight: theme.isNight)
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Text("Morning check-in")
                        .font(.footnote.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(theme.secondaryText)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .frame(width: 44, height: 44)
                            .background(theme.accentSoft, in: Circle())
                    }
                    .accessibilityLabel("Cancel")
                }
                Text("How rested do you feel?")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                if let text = line.text { SpeechBubble(text: text) }
                LumiView(mood: line.mood, motion: line.motion, size: 160)
                Text(MoonPhase.label(level: restedness))
                    .font(.title2.bold())
                    .foregroundStyle(theme.accent)
                    .contentTransition(.opacity)
                HStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { level in
                        MoonButton(level: level, isSelected: level == restedness, size: 58) {
                            withAnimation(.spring(duration: 0.3)) { restedness = level }
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Restedness")
                Text("Anything else from last night?")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                FlowLayout(spacing: 8) {
                    Chip(title: "Felt tense at bedtime", isSelected: tense) { tense.toggle() }
                    Chip(title: "Woke up during the night", isSelected: woke) { woke.toggle() }
                    Chip(title: "Trouble sleeping most nights for 3+ weeks", isSelected: persistent) { persistent.toggle() }
                }
                TextField("Add a note (optional)", text: $note, axis: .vertical)
                    .lineLimit(2...5)
                    .padding(12)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(theme.cardBorder, lineWidth: 2))
                Label("This is how you felt. Stillmoon keeps it apart from what your watch estimated.", systemImage: "heart")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Save check-in") {
                    onSave(CheckIn(id: existing?.id ?? UUID(), date: existing?.date ?? .now,
                                   restedness: restedness, tenseAtBedtime: tense, wokeDuringNight: woke,
                                   persistentDifficulty: persistent, note: note.isEmpty ? nil : note))
                    dismiss()
                }
                .buttonStyle(ChunkyButtonStyle())
            }
            .padding(20)
        }
        .foregroundStyle(theme.text)
        .background(theme.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }
}
```

- [ ] **Step 2: Build and run the existing suite**

Run: `scripts/test-app.sh -only-testing:StillmoonTests`
Expected: `** TEST SUCCEEDED **` (no check-in logic changed; this proves it builds).

- [ ] **Step 3: Look at it**

In the simulator, tap a moon on Today: the sheet opens on that level; tapping other moons changes Lumi's face and line; chips toggle; Save closes and Today shows "You checked in: …".

- [ ] **Step 4: Commit**

```bash
git add App/Stillmoon/Features/Sleep/CheckInSheet.swift
git commit -m "feat(check-in): Lumi reacts to restedness, moon buttons and chips

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Onboarding with Lumi

**Files:**
- Modify: `App/Stillmoon/Design/Format.swift`
- Replace: `App/Stillmoon/Features/Onboarding/OnboardingView.swift`
- Test: `App/StillmoonTests/FormatTests.swift`

**Interfaces:**
- Consumes: `LumiDirector.onboarding(_:)` (Task 3), components (Task 1).
- Produces: `Goal.subtitle: String`, `Goal.symbol: String`.

- [ ] **Step 1: Write the failing test**

In `App/StillmoonTests/FormatTests.swift`, add inside the suite:

```swift
    @Test func everyGoalHasASubtitleAndItsOwnSymbol() {
        #expect(Goal.allCases.allSatisfy { !$0.subtitle.isEmpty })
        #expect(Set(Goal.allCases.map(\.symbol)).count == Goal.allCases.count)
        #expect(Goal.unwind.subtitle == "Calm the mind when the lights go out")
    }
```

(If the file lacks `import StillmoonCore`, add it.)

- [ ] **Step 2: Run test to verify it fails**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/FormatTests`
Expected: build error `value of type 'Goal' has no member 'subtitle'`.

- [ ] **Step 3: Add to `App/Stillmoon/Design/Format.swift`** (inside the existing `extension Goal`, after `title`)

```swift
    var subtitle: String {
        switch self {
        case .unwind: "Calm the mind when the lights go out"
        case .understandSleep: "Make sense of what your watch records"
        case .nightWaking: "Gentle help for 3 a.m. moments"
        case .consistency: "Small habits, steadier bedtimes"
        }
    }

    var symbol: String {
        switch self {
        case .unwind: "moon.stars"
        case .understandSleep: "chart.bar"
        case .nightWaking: "sparkles"
        case .consistency: "calendar"
        }
    }
```

- [ ] **Step 4: Replace `App/Stillmoon/Features/Onboarding/OnboardingView.swift`**

```swift
import SwiftUI
import StillmoonCore

struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    @State private var model: OnboardingModel
    @State private var connecting = false

    init(settings: SettingsStore) {
        _model = State(initialValue: OnboardingModel(settings: settings))
    }

    var body: some View {
        let line = LumiDirector.onboarding(model.step)
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Button { model.back() } label: {
                    Image(systemName: "chevron.left").font(.headline).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Back")
                .disabled(connecting || !model.canGoBack)
                .opacity(model.canGoBack ? 1 : 0)
                .accessibilityHidden(!model.canGoBack)
                StepProgress(value: model.step.rawValue + 1, total: OnboardingModel.Step.allCases.count)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .bottom, spacing: 4) {
                        LumiView(mood: line.mood, motion: line.motion, size: 120)
                        if let text = line.text {
                            SpeechBubble(text: text).padding(.bottom, 56)
                        }
                    }
                    stepContent
                }
                .padding(.vertical, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.horizontal, 20)
        .foregroundStyle(theme.text)
        .tint(theme.accent)
        .background(theme.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: model.step)
    }

    @ViewBuilder private var stepContent: some View {
        switch model.step {
        case .welcome:
            Text("Stillmoon").font(.largeTitle.bold())
            Text("Understand your nights. Find a calmer next step.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
            privacyNote
            primary("Get started") { model.next() }
        case .goal:
            Text("What brings you here?").font(.title.bold())
            ForEach(Goal.allCases, id: \.self) { goal in
                let chosen = goal == model.goal
                Button { model.chooseGoal(goal) } label: { GoalCard(goal: goal) }
                    .buttonStyle(TileButtonStyle(fill: chosen ? theme.accentSoft : theme.surface,
                                                 border: chosen ? theme.accent : theme.cardBorder))
                    .accessibilityLabel(goal.title)
                    .accessibilityHint(goal.subtitle)
            }
        case .schedule:
            Text("When do you usually sleep?").font(.title.bold())
            Text("This sets when Stillmoon turns calm and dim. You can change it any time.")
                .foregroundStyle(theme.secondaryText)
            Card {
                VStack(spacing: 8) {
                    DatePicker("Bedtime", selection: clock($model.bedtime), displayedComponents: .hourAndMinute)
                    Divider()
                    DatePicker("Wake time", selection: clock($model.wakeTime), displayedComponents: .hourAndMinute)
                }
            }
            primary("Continue") { model.next() }
            secondary("Skip for now") { model.skipSchedule() }
        case .health:
            Text("Add your watch's estimates?").font(.title.bold())
            Text("Stillmoon can read sleep from Apple Health and save finished exercises as Mindful Minutes. Your sleep data stays on this iPhone.")
                .foregroundStyle(theme.secondaryText)
            primary("Connect Apple Health") {
                guard !connecting else { return }
                connecting = true
                Task {
                    _ = await env.connectHealth()
                    model.next()
                    connecting = false
                }
            }
            .disabled(connecting)
            secondary("Not now") { model.next() }
                .disabled(connecting)
        case .microphone:
            Text("Listen for sounds at night?").font(.title.bold())
            Text("During a sleep session you start, Stillmoon can notice snoring-like, speech-like and cough-like sounds. Sound is analyzed on this iPhone and never recorded. You can turn this off at any time.")
                .foregroundStyle(theme.secondaryText)
            primary("Turn on sound detection") {
                guard !connecting else { return }
                connecting = true
                Task {
                    env.settings.settings.soundDetectionEnabled = await env.sound.requestPermission()
                    connecting = false
                    model.next()
                }
            }
            .disabled(connecting)
            secondary("Not now") { model.next() }
                .disabled(connecting)
        case .privacy:
            Text("Your nights stay yours").font(.title.bold())
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Your journal and check-ins stay on this iPhone.", systemImage: "iphone")
                    Label("Nothing you write is read or analyzed.", systemImage: "text.badge.xmark")
                    Label("You can delete everything from Settings at any time.", systemImage: "trash")
                }
            }
            primary("Continue") { model.next() }
        case .firstExercise:
            Text("Try a few calm minutes?").font(.title.bold())
            Text("Gentle breathing takes about 5 minutes. No sensors needed.")
                .foregroundStyle(theme.secondaryText)
            primary("Start gentle breathing") {
                model.finish()
                env.playerRequest = PlayerRequest(exerciseID: OnboardingModel.firstExerciseID)
            }
            secondary("Go to Today") { model.finish() }
        }
    }

    private var privacyNote: some View {
        Label("Your sleep data stays on your phone.", systemImage: "lock.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(theme.secondaryText)
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(ChunkyButtonStyle())
            .padding(.top, 4)
    }

    private func secondary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 44)
    }

    private func clock(_ binding: Binding<ClockTime>) -> Binding<Date> {
        Binding(get: { binding.wrappedValue.date(on: .now, calendar: .current) },
                set: { binding.wrappedValue = ClockTime(of: $0, calendar: .current) })
    }
}

private struct GoalCard: View {
    @Environment(\.theme) private var theme
    let goal: Goal

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemName: goal.symbol, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title).font(.headline).foregroundStyle(theme.text)
                Text(goal.subtitle).font(.subheadline).foregroundStyle(theme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .multilineTextAlignment(.leading)
        .padding(14)
    }
}
```

- [ ] **Step 5: Run unit and UI tests**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/FormatTests -only-testing:StillmoonTests/OnboardingModelTests -only-testing:StillmoonUITests`
Expected: `** TEST SUCCEEDED **` (UI tests still find "Get started", "Unwind before bed", "Skip for now", "Not now", "Continue", "Go to Today", "Start gentle breathing", "End exercise").

- [ ] **Step 6: Commit**

```bash
git add App/Stillmoon/Design/Format.swift App/Stillmoon/Features/Onboarding/OnboardingView.swift App/StillmoonTests/FormatTests.swift
git commit -m "feat(onboarding): Lumi guides each step with chunky goal cards and progress bar

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Log in and Sign up views (not yet in the flow)

**Files:**
- Create: `App/Stillmoon/Features/Account/AccountViews.swift`
- Create: `App/Stillmoon/Resources/Assets.xcassets/Contents.json`
- Create: `App/Stillmoon/Resources/Assets.xcassets/GoogleG.imageset/Contents.json`
- Create: `App/Stillmoon/Resources/Assets.xcassets/GoogleG.imageset/google-g.svg`
- Test: `App/StillmoonTests/AccountTests.swift`

**Interfaces:**
- Consumes: `SkyBackdrop`, `LumiView`, `SpeechBubble`, `StepProgress`, `Card` (Tasks 1–2).
- Produces: `ProviderButtons.title(_ provider: Provider, _ intent: Intent) -> String`; `LoginView(isWorking:onApple:onGoogle:onCreateAccount:)`; `SignUpView(step:isWorking:termsURL:privacyURL:onApple:onGoogle:onLogIn:)`. Plan 5 wires these into onboarding.

- [ ] **Step 1: Write the failing test**

Create `App/StillmoonTests/AccountTests.swift`:

```swift
import Testing
@testable import Stillmoon

struct AccountTests {
    @Test func providerButtonTitles() {
        #expect(ProviderButtons.title(.apple, .logIn) == "Continue with Apple")
        #expect(ProviderButtons.title(.google, .logIn) == "Continue with Google")
        #expect(ProviderButtons.title(.apple, .signUp) == "Sign up with Apple")
        #expect(ProviderButtons.title(.google, .signUp) == "Sign up with Google")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/AccountTests`
Expected: build error `cannot find 'ProviderButtons' in scope`.

- [ ] **Step 3: Add the Google mark asset**

`App/Stillmoon/Resources/Assets.xcassets/Contents.json`:

```json
{
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`App/Stillmoon/Resources/Assets.xcassets/GoogleG.imageset/Contents.json`:

```json
{
  "images" : [ { "filename" : "google-g.svg", "idiom" : "universal" } ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : { "preserves-vector-representation" : true, "template-rendering-intent" : "original" }
}
```

`App/Stillmoon/Resources/Assets.xcassets/GoogleG.imageset/google-g.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>
```

- [ ] **Step 4: Create `App/Stillmoon/Features/Account/AccountViews.swift`**

```swift
import SwiftUI

/// Sign in with Apple or Google (PRD §5 step 2). Apple and Google buttons keep their brand colors in every theme.
struct ProviderButtons: View {
    enum Provider { case apple, google }
    enum Intent { case logIn, signUp }

    let intent: Intent
    var isWorking = false
    let onApple: () -> Void
    let onGoogle: () -> Void

    static func title(_ provider: Provider, _ intent: Intent) -> String {
        let name = provider == .apple ? "Apple" : "Google"
        return intent == .logIn ? "Continue with \(name)" : "Sign up with \(name)"
    }

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onApple) {
                Label(Self.title(.apple, intent), systemImage: "apple.logo")
            }
            .buttonStyle(ProviderButtonStyle(fill: .black, text: .white, edge: Color(hex: 0x3A3550), border: nil))
            Button(action: onGoogle) {
                HStack(spacing: 10) {
                    Image("GoogleG").resizable().frame(width: 20, height: 20).accessibilityHidden(true)
                    Text(Self.title(.google, intent))
                }
            }
            .buttonStyle(ProviderButtonStyle(fill: .white, text: Color(hex: 0x231E3A), edge: Color(hex: 0xE2DCEC),
                                             border: Color(hex: 0xE2DCEC)))
        }
        .disabled(isWorking)
        .opacity(isWorking ? 0.6 : 1)
        .overlay { if isWorking { ProgressView() } }
    }
}

private struct ProviderButtonStyle: ButtonStyle {
    let fill: Color
    let text: Color
    let edge: Color
    let border: Color?

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        configuration.label
            .font(.headline)
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(border ?? .clear, lineWidth: 2))
            .offset(y: configuration.isPressed ? 3 : 0)
            .background(shape.fill(edge).offset(y: 5))
            .padding(.bottom, 5)
            .animation(.spring(duration: 0.12), value: configuration.isPressed)
    }
}

/// Returning users. Plan 5 supplies the actions.
struct LoginView: View {
    @Environment(\.theme) private var theme
    var isWorking = false
    let onApple: () -> Void
    let onGoogle: () -> Void
    let onCreateAccount: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                SkyBackdrop().ignoresSafeArea(edges: .top)
                LumiView(mood: .wave, motion: .float, size: 180).padding(.bottom, 36)
            }
            .frame(maxHeight: .infinity)
            VStack(spacing: 8) {
                Text("Welcome back").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                Text("Lumi kept your sky safe. Log in to pick up where you left off.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            VStack(spacing: 14) {
                ProviderButtons(intent: .logIn, isWorking: isWorking, onApple: onApple, onGoogle: onGoogle)
                HStack(spacing: 4) {
                    Text("New to Stillmoon?")
                    Button("Create an account", action: onCreateAccount).fontWeight(.heavy)
                }
                .font(.subheadline.weight(.semibold))
                Label("Your sleep data never leaves your phone.", systemImage: "lock.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(20)
        }
        .foregroundStyle(theme.text)
        .background(theme.background.ignoresSafeArea())
    }
}

/// Account creation inside onboarding. Copy from PRD §5 step 2.
struct SignUpView: View {
    @Environment(\.theme) private var theme
    /// Onboarding position for the progress bar, e.g. (2, 8); nil hides it.
    var step: (value: Int, total: Int)?
    var isWorking = false
    let termsURL: URL
    let privacyURL: URL
    let onApple: () -> Void
    let onGoogle: () -> Void
    let onLogIn: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let step { StepProgress(value: step.value, total: step.total) }
                HStack(alignment: .bottom, spacing: 4) {
                    LumiView(mood: .happy, motion: .float, size: 120)
                    SpeechBubble(text: "Let's keep your stars safe, even on a new phone.").padding(.bottom, 56)
                }
                Text("Create your account").font(.title.bold()).accessibilityAddTraits(.isHeader)
                Text("Keeps your progress, saved exercises and journey safe across devices.")
                    .foregroundStyle(theme.secondaryText)
                Grid(horizontalSpacing: 10) {
                    GridRow {
                        storeTile("icloud", "In your account", "Progress, saved exercises, your sky")
                        storeTile("iphone", "On this iPhone", "Sleep data, check-ins, journal, sounds")
                    }
                }
                ProviderButtons(intent: .signUp, isWorking: isWorking, onApple: onApple, onGoogle: onGoogle)
                    .padding(.top, 8)
                HStack(spacing: 4) {
                    Text("Already have an account?")
                    Button("Log in", action: onLogIn).fontWeight(.heavy)
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                Text(termsLine)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .foregroundStyle(theme.text)
        .tint(theme.accent)
        .background(theme.background.ignoresSafeArea())
    }

    private var termsLine: AttributedString {
        let markdown = "By continuing you agree to the [Terms](\(termsURL.absoluteString)) and [Privacy Policy](\(privacyURL.absoluteString))."
        return (try? AttributedString(markdown: markdown)) ?? AttributedString("By continuing you agree to the Terms and Privacy Policy.")
    }

    private func storeTile(_ symbol: String, _ title: String, _ detail: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol).font(.title3).foregroundStyle(theme.accent).accessibilityHidden(true)
                Text(title).font(.subheadline.bold())
                Text(detail).font(.footnote).foregroundStyle(theme.secondaryText)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview("Log in") {
    LoginView(onApple: {}, onGoogle: {}, onCreateAccount: {})
        .fontDesign(.rounded)
}

#Preview("Sign up") {
    SignUpView(step: (2, 8), termsURL: URL(string: "https://example.com/terms")!,
               privacyURL: URL(string: "https://example.com/privacy")!,
               onApple: {}, onGoogle: {}, onLogIn: {})
        .fontDesign(.rounded)
}
```

- [ ] **Step 5: Run tests**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/AccountTests`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Check the previews**

Open `AccountViews.swift` previews: Log in shows sky, waving Lumi, two provider buttons; Sign up shows progress, bubble, two tiles, buttons, terms links. The Google "G" renders in color.

- [ ] **Step 7: Commit**

```bash
git add App/Stillmoon/Features/Account App/Stillmoon/Resources/Assets.xcassets App/StillmoonTests/AccountTests.swift
git commit -m "feat(account): Log in and Sign up views with Apple and Google buttons (wired in Plan 5)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Remaining screens adopt the system; full verification

**Files:**
- Modify: `App/Stillmoon/Features/Exercises/ExercisesView.swift`
- Modify: `App/Stillmoon/Features/Exercises/ExerciseDetailView.swift`
- Modify: `App/Stillmoon/Features/Sleep/SleepView.swift`
- Modify: `App/Stillmoon/Features/Sound/SoundSessionView.swift`
- Modify: `App/Stillmoon/Features/Settings/SettingsView.swift`
- Modify: `docs/superpowers/plans/2026-10-04-stillmoon-redesign.followups.md` (create)

**Interfaces:**
- Consumes: `Chip`, `ChunkyButtonStyle`, `LumiEmptyState`, `LumiView` (Tasks 1–2).

- [ ] **Step 1: Exercises chips and empty state**

In `ExercisesView.swift`, replace the `chip` function body:

```swift
    private func chip(_ title: String, _ filter: LibraryFilter) -> some View {
        Chip(title: title, isSelected: model.filter == filter) { model.filter = filter }
    }
```

and replace

```swift
                ContentUnavailableView.search(text: model.query)
                    .listRowBackground(Color.clear)
```

with

```swift
                LumiEmptyState(title: "Nothing found",
                               message: model.query.isEmpty ? "Nothing here yet." : "Nothing matches \u{201C}\(model.query)\u{201D}. Try another word.")
                    .listRowBackground(Color.clear)
```

- [ ] **Step 2: Chunky Start on exercise detail**

In `ExerciseDetailView.swift`, replace

```swift
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(theme.accent)
```

with

```swift
                .buttonStyle(ChunkyButtonStyle())
```

- [ ] **Step 3: Sleep empty state**

In `SleepView.swift`, replace

```swift
                ContentUnavailableView("No nights yet", systemImage: "moon.zzz",
                                       description: Text("Add a night with the + button, or connect Apple Health in Settings."))
                    .listRowBackground(Color.clear)
```

with

```swift
                LumiEmptyState(title: "No nights yet",
                               message: "Add a night with the + button, or connect Apple Health in Settings.")
                    .listRowBackground(Color.clear)
```

- [ ] **Step 4: Sound session: still Lumi, flat night buttons**

In `SoundSessionView.swift`, after the first `Spacer()` inside the `VStack(spacing: 28)` add:

```swift
            LumiView(mood: .sleepy, motion: .still, size: 120, animated: false)
```

Replace both

```swift
                    .buttonStyle(.bordered)
                    .controlSize(.large)
```

(on Resume and Pause) with

```swift
                    .buttonStyle(ChunkyButtonStyle(kind: .secondary))
```

replace

```swift
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
```

(on End session) with

```swift
                .buttonStyle(ChunkyButtonStyle())
```

and in `SoundStartButton`, replace

```swift
            .buttonStyle(.bordered)
            .controlSize(.large)
```

with

```swift
            .buttonStyle(ChunkyButtonStyle(kind: .secondary))
```

- [ ] **Step 5: Settings background**

In `SettingsView.swift`, add `@Environment(\.theme) private var theme` below `@Environment(\.dismiss) private var dismiss`, and on the `Form` (after its closing brace, before `.navigationTitle`) add:

```swift
            .scrollContentBackground(.hidden)
            .background(theme.background.ignoresSafeArea())
```

- [ ] **Step 6: Run the whole suite, unit and UI**

Run: `scripts/test-app.sh`
Expected: `** TEST SUCCEEDED **`. If a UI test fails because night mode was active on the simulator clock, rerun; if it fails because a label moved, restore the label (Global Constraints list) rather than editing the test.

- [ ] **Step 7: Manual pass (record results in the commit message body)**

On the iPhone 17 Pro simulator:
1. Settings app › Accessibility › Motion › Reduce Motion on: Lumi, stars, rays and rings are still; bubbles appear without popping.
2. Largest accessibility text size: Today header stacks (greeting, bubble) without clipping; check-in sheet scrolls.
3. VoiceOver on Today: greeting header, "2 of 3 wind-downs this week", five moon buttons with labels, suggestion "Start <title>", "Why: …" read; Lumi not read.
4. Stillmoon Settings › Night mode › On: Today night scene; finish an exercise → quiet "Well done. Rest now." Night mode › Off: finish a wind-down → celebration with moon pop.
5. Journey: next star pulses with "TONIGHT" and Lumi beside it; tapping starts the wind-down.

- [ ] **Step 8: Write follow-ups and commit**

Create `docs/superpowers/plans/2026-10-04-stillmoon-redesign.followups.md` listing any manual-pass issues found (one line each, "Task N: minor (deferred): …"), or "None found." Then:

```bash
git add App/Stillmoon/Features docs/superpowers/plans/2026-10-04-stillmoon-redesign.followups.md
git commit -m "feat(design): exercises, sleep, sound session and settings adopt the new system

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
