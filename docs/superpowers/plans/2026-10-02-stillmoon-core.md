# StillmoonCore Implementation Plan (Plan 1 of 7)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `StillmoonCore`, a pure-Swift package holding every rule in the PRD that does not need a device: night windows, the nightly sleep report, night mode, weekly progress and journey, recommendations, referral signals, the sound launch-gate metric, and export.

**Architecture:** A Swift package with no dependencies and no Apple-framework imports beyond Foundation. Every type is a value type (`struct`/`enum`), `Sendable`, and every function that reads the clock or calendar takes `now:` and `calendar:` as parameters so tests are deterministic. The iOS app (Plan 2+) maps SwiftData/HealthKit/Supabase records into these types and calls these functions; no UI or persistence lives here.

**Tech Stack:** Swift 6.2, Swift Package Manager, Swift Testing (`import Testing`), Foundation. Tests run on macOS with `swift test`; no simulator needed.

**Spec:** `docs/PRD-v1.2.md` (living copy: https://claude.ai/code/artifact/6ee2ae28-725e-4a6b-b83e-49c0e614b1f7)

## Roadmap (this plan is 1 of 7)

1. **StillmoonCore** (this plan): pure domain logic, `swift test`.
2. **App shell:** XcodeGen project, SwiftData models mapped to Core types, four tabs, onboarding (minus sign-in), journal and check-in, exercise player, day/night theming. Needs an iOS simulator runtime.
3. **HealthKit:** sleep import into `SleepSample`, nightly report screen, Mindful Minutes write.
4. **Sound detection:** Sound Analysis session, background audio, event review and corrections, battery warning, remote flag.
5. **Supabase:** Sign in with Apple and Google, profiles/preferences/events tables with RLS, sync queue, content manifest, feature flags, account deletion.
6. **Content:** exercise scripts, TTS audio, articles with review-date CI check, Higgsfield style kit and assets.
7. **Ship:** iCloud sync toggle, export ZIP, wind-down reminder, opt-in analytics, accessibility pass, App Store submission.

## Global Constraints

- Package platforms: `.iOS(.v17)`, `.macOS(.v14)`; `swift-tools-version: 6.0`; Swift 6 language mode (strict concurrency).
- No third-party dependencies. Only `import Foundation` in sources; `import Testing` in tests.
- No function reads `Date()`, `Calendar.current` or `TimeZone.current`; callers pass `now` and `calendar`.
- Reason strings are copied verbatim from PRD §8: "You mentioned feeling tense before bed.", "You mentioned being awake during the night.", "Your recorded bedtimes varied this week.", "Based on the goal you chose."
- Night-mode defaults: bedtime 22:00, wake 07:00, window opens 1 hour before bedtime.
- Weekly goal default 3; journey has 7 stages (0–6) and never goes backward.
- Sound gate pass bar: false rate strictly below 0.2 (fewer than 1 in 5).
- Snoring note: snoring-like events marked "this was me" on at least 5 distinct nights in the last 7 days, shown once.
- Never reward or score sleep metrics; no type in this package exposes a "sleep score".

## Review Focus

1. **Bedtimes that cross midnight** (23:50 vs 00:10): bedtime variability and night mode must treat these as 20 minutes apart, not 23 hours. Pinned in Task 3 and Task 5.
2. **Duplicate and conflicting Health samples** (Watch + iPhone both writing, re-imports): the report must not double count, and must prefer the source with stage detail. Pinned in Task 2.
3. **Daylight-saving nights** (2026-11-01 fall back in America/New_York): the night window must be 19 hours, not 18, and durations must use real elapsed seconds. Pinned in Task 1 and Task 2.
4. **Free-text notes with commas, quotes and newlines** in CSV export: must stay one field. Pinned in Task 7.
5. **The same completion synced twice** (union sync re-delivers an event): progress must count it once. Pinned in Task 4.

---

## File Structure

```
StillmoonCore/
  Package.swift
  Sources/StillmoonCore/
    Models.swift              # shared value types (Task 1)
    NightWindow.swift         # night window + night key (Task 1)
    SleepReport.swift         # NightReport + SleepReportBuilder (Task 2)
    NightMode.swift           # ClockTime + NightModeResolver (Task 3)
    Progress.swift            # ProgressSummary + ProgressCalculator (Task 4)
    Recommendations.swift     # catalog, feedback, RecommendationEngine (Task 5)
    Signals.swift             # ReferralSignals + SoundGate (Task 6)
    Export.swift              # ExportBundle + ExportWriter (Task 7)
  Tests/StillmoonCoreTests/
    TestSupport.swift         # fixed calendar + date helper (Task 1)
    NightWindowTests.swift
    SleepReportTests.swift
    NightModeTests.swift
    ProgressTests.swift
    RecommendationTests.swift
    SignalsTests.swift
    ExportTests.swift
```

All commands below run from `~/stillmoon/StillmoonCore` unless stated.

---

### Task 1: Package scaffold, shared models, night window

**Files:**
- Create: `StillmoonCore/Package.swift`
- Create: `StillmoonCore/Sources/StillmoonCore/Models.swift`
- Create: `StillmoonCore/Sources/StillmoonCore/NightWindow.swift`
- Create: `StillmoonCore/Tests/StillmoonCoreTests/TestSupport.swift`
- Test: `StillmoonCore/Tests/StillmoonCoreTests/NightWindowTests.swift`
- Create: `.gitignore` (repo root)

**Interfaces:**
- Produces: `SleepStage` (+ `isAsleep`, `isDetailed`), `SleepSample`, `CheckIn`, `SoundLabel`, `SoundCorrection`, `SoundEvent`, `ExerciseCategory`, `ExerciseCompletion`, `Goal`, `NightWindow.forMorning(of:calendar:)`, `NightWindow.nightKey(for:calendar:)`, test helper `T.cal` / `T.d(...)`.

- [ ] **Step 1: Create the package and gitignore**

`.gitignore` (repo root):
```
.DS_Store
.build/
.swiftpm/
DerivedData/
*.xcuserstate
xcuserdata/
```

`StillmoonCore/Package.swift`:
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StillmoonCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "StillmoonCore", targets: ["StillmoonCore"]),
    ],
    targets: [
        .target(name: "StillmoonCore"),
        .testTarget(name: "StillmoonCoreTests", dependencies: ["StillmoonCore"]),
    ]
)
```

- [ ] **Step 2: Write the shared models**

`Sources/StillmoonCore/Models.swift`:
```swift
import Foundation

public enum SleepStage: String, Codable, Sendable, CaseIterable {
    case inBed, awake, core, deep, rem, asleepUnspecified

    /// Stages that count as sleep time.
    public var isAsleep: Bool {
        switch self {
        case .core, .deep, .rem, .asleepUnspecified: true
        case .inBed, .awake: false
        }
    }

    /// Stages only a stage-tracking wearable records.
    public var isDetailed: Bool {
        switch self {
        case .core, .deep, .rem: true
        case .inBed, .awake, .asleepUnspecified: false
        }
    }
}

public struct SleepSample: Codable, Sendable, Hashable {
    public var stage: SleepStage
    public var start: Date
    public var end: Date
    /// HealthKit source name, shown to the user as "Recorded by".
    public var sourceName: String

    public init(stage: SleepStage, start: Date, end: Date, sourceName: String) {
        self.stage = stage
        self.start = start
        self.end = end
        self.sourceName = sourceName
    }
}

public struct CheckIn: Codable, Sendable, Hashable {
    public var id: UUID
    public var date: Date
    /// 1 (not rested) ... 5 (very rested)
    public var restedness: Int
    public var tenseAtBedtime: Bool
    public var wokeDuringNight: Bool
    /// "Trouble sleeping most nights for 3+ weeks"
    public var persistentDifficulty: Bool
    public var note: String?

    public init(id: UUID = UUID(), date: Date, restedness: Int, tenseAtBedtime: Bool = false,
                wokeDuringNight: Bool = false, persistentDifficulty: Bool = false, note: String? = nil) {
        self.id = id
        self.date = date
        self.restedness = restedness
        self.tenseAtBedtime = tenseAtBedtime
        self.wokeDuringNight = wokeDuringNight
        self.persistentDifficulty = persistentDifficulty
        self.note = note
    }
}

public enum SoundLabel: String, Codable, Sendable, CaseIterable {
    case snoringLike, speechLike, coughLike
}

public enum SoundCorrection: String, Codable, Sendable {
    /// Not reviewed by the user.
    case none
    case incorrect
    case someoneElse
    case wasMe
}

public struct SoundEvent: Codable, Sendable, Hashable {
    public var id: UUID
    public var label: SoundLabel
    public var at: Date
    public var confidence: Double
    public var correction: SoundCorrection

    public init(id: UUID = UUID(), label: SoundLabel, at: Date, confidence: Double, correction: SoundCorrection = .none) {
        self.id = id
        self.label = label
        self.at = at
        self.confidence = confidence
        self.correction = correction
    }
}

public enum ExerciseCategory: String, Codable, Sendable, CaseIterable {
    case windDown, awakeAtNight, morningReset, learn
}

public struct ExerciseCompletion: Codable, Sendable, Hashable {
    /// Client-generated; the sync key.
    public var id: UUID
    public var exerciseID: String
    public var category: ExerciseCategory
    public var completedAt: Date

    public init(id: UUID = UUID(), exerciseID: String, category: ExerciseCategory, completedAt: Date) {
        self.id = id
        self.exerciseID = exerciseID
        self.category = category
        self.completedAt = completedAt
    }
}

public enum Goal: String, Codable, Sendable, CaseIterable {
    case unwind, understandSleep, nightWaking, consistency
}
```

- [ ] **Step 3: Write the test helper and failing night-window tests**

`Tests/StillmoonCoreTests/TestSupport.swift`:
```swift
import Foundation

/// Fixed calendar so tests never depend on the machine's time zone.
enum T {
    static let tz = TimeZone(identifier: "America/New_York")!

    static var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        c.firstWeekday = 1 // Sunday
        return c
    }

    static func d(_ y: Int, _ mo: Int, _ day: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: mo, day: day, hour: h, minute: mi))!
    }
}
```

`Tests/StillmoonCoreTests/NightWindowTests.swift`:
```swift
import Foundation
import Testing
@testable import StillmoonCore

struct NightWindowTests {
    @Test func windowRunsFromSixPMToNoon() {
        let w = NightWindow.forMorning(of: T.d(2026, 10, 2, 8), calendar: T.cal)
        #expect(w.start == T.d(2026, 10, 1, 18))
        #expect(w.end == T.d(2026, 10, 2, 12))
        #expect(w.end.timeIntervalSince(w.start) == 18 * 3600)
    }

    @Test func fallBackNightIsNineteenHours() {
        // DST ends 2026-11-01 02:00 in New York.
        let w = NightWindow.forMorning(of: T.d(2026, 11, 1, 9), calendar: T.cal)
        #expect(w.start == T.d(2026, 10, 31, 18))
        #expect(w.end == T.d(2026, 11, 1, 12))
        #expect(w.end.timeIntervalSince(w.start) == 19 * 3600)
    }

    @Test func eveningAndEarlyMorningShareANightKey() {
        let evening = NightWindow.nightKey(for: T.d(2026, 10, 1, 23), calendar: T.cal)
        let early = NightWindow.nightKey(for: T.d(2026, 10, 2, 3), calendar: T.cal)
        let nextEvening = NightWindow.nightKey(for: T.d(2026, 10, 2, 22), calendar: T.cal)
        #expect(evening == early)
        #expect(evening != nextEvening)
    }
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `swift test --filter NightWindowTests`
Expected: build FAILS with "cannot find 'NightWindow' in scope".

- [ ] **Step 5: Implement NightWindow**

`Sources/StillmoonCore/NightWindow.swift`:
```swift
import Foundation

/// The span searched for one night's sleep: 18:00 the previous day to 12:00 on the morning day.
public struct NightWindow: Sendable, Equatable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public static func forMorning(of day: Date, calendar: Calendar) -> NightWindow {
        let morning = calendar.startOfDay(for: day)
        let previous = calendar.date(byAdding: .day, value: -1, to: morning)!
        let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: previous)!
        let end = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: morning)!
        return NightWindow(start: start, end: end)
    }

    /// Identifies which night a moment belongs to: the calendar day the night started on.
    /// Anything before noon belongs to the previous day's night.
    public static func nightKey(for date: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .hour, value: -12, to: date)!)
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --filter NightWindowTests`
Expected: 3 tests PASS.

- [ ] **Step 7: Commit**

```bash
cd ~/stillmoon
git add .gitignore docs StillmoonCore
git commit -m "feat(core): package scaffold, shared models, night window"
```

---

### Task 2: Nightly sleep report

**Files:**
- Create: `StillmoonCore/Sources/StillmoonCore/SleepReport.swift`
- Test: `StillmoonCore/Tests/StillmoonCoreTests/SleepReportTests.swift`

**Interfaces:**
- Consumes: `SleepSample`, `SleepStage.isAsleep/isDetailed`, `NightWindow`.
- Produces: `NightReport` (fields below), `SleepReportBuilder.build(samples:window:) -> NightReport?`, `SleepReportBuilder.minimumGap`, internal `mergeIntervals(_:) -> [DateInterval]`.

Rules (PRD §6 FR-05, §11 "duplicate or conflicting Health data"):
- Samples are clipped to the window; anything fully outside is ignored.
- Exact duplicates are removed.
- When several sources recorded the night, the **primary source** is the one with stage detail; ties go to more asleep time, then alphabetical name. Only the primary source builds the timeline. All sources are listed.
- No asleep samples → `nil` (the UI shows "No sleep recorded").
- `gaps` are holes of at least 15 minutes inside the sleep span with no primary-source sample at all.

- [ ] **Step 1: Write the failing tests**

`Tests/StillmoonCoreTests/SleepReportTests.swift`:
```swift
import Foundation
import Testing
@testable import StillmoonCore

struct SleepReportTests {
    let window = NightWindow.forMorning(of: T.d(2026, 10, 2, 8), calendar: T.cal)
    let watch = "Apple Watch"

    func s(_ stage: SleepStage, _ from: Date, _ to: Date, _ source: String = "Apple Watch") -> SleepSample {
        SleepSample(stage: stage, start: from, end: to, sourceName: source)
    }

    var watchNight: [SleepSample] {
        [
            s(.core, T.d(2026, 10, 1, 23), T.d(2026, 10, 2, 1)),
            s(.deep, T.d(2026, 10, 2, 1), T.d(2026, 10, 2, 2)),
            s(.awake, T.d(2026, 10, 2, 2), T.d(2026, 10, 2, 2, 10)),
            s(.rem, T.d(2026, 10, 2, 2, 10), T.d(2026, 10, 2, 3)),
            s(.core, T.d(2026, 10, 2, 3), T.d(2026, 10, 2, 6, 30)),
        ]
    }

    @Test func noSamplesGivesNoReport() {
        #expect(SleepReportBuilder.build(samples: [], window: window) == nil)
    }

    @Test func inBedOnlyGivesNoReport() {
        let r = SleepReportBuilder.build(samples: [s(.inBed, T.d(2026, 10, 1, 22), T.d(2026, 10, 2, 7))], window: window)
        #expect(r == nil)
    }

    @Test func buildsAWatchNight() throws {
        let r = try #require(SleepReportBuilder.build(samples: watchNight, window: window))
        #expect(r.sleepStart == T.d(2026, 10, 1, 23))
        #expect(r.sleepEnd == T.d(2026, 10, 2, 6, 30))
        #expect(r.estimatedAsleep == 7 * 3600 + 20 * 60)
        #expect(r.stageDurations[.deep] == 3600)
        #expect(r.stageDurations[.awake] == 600)
        #expect(r.hasStageDetail)
        #expect(r.gaps.isEmpty)
        #expect(r.primarySource == watch)
        #expect(r.allSources == [watch])
        #expect(r.timeline.count == 5)
    }

    @Test func duplicatesAreNotDoubleCounted() throws {
        let r = try #require(SleepReportBuilder.build(samples: watchNight + watchNight, window: window))
        #expect(r.estimatedAsleep == 7 * 3600 + 20 * 60)
        #expect(r.timeline.count == 5)
    }

    @Test func prefersTheSourceWithStageDetail() throws {
        let phone = s(.asleepUnspecified, T.d(2026, 10, 1, 22, 30), T.d(2026, 10, 2, 7), "iPhone")
        let r = try #require(SleepReportBuilder.build(samples: watchNight + [phone], window: window))
        #expect(r.primarySource == watch)
        #expect(r.allSources == [watch, "iPhone"])
        #expect(r.estimatedAsleep == 7 * 3600 + 20 * 60)
    }

    @Test func iPhoneOnlyNightHasNoStageDetail() throws {
        let phone = s(.asleepUnspecified, T.d(2026, 10, 1, 23), T.d(2026, 10, 2, 7), "iPhone")
        let r = try #require(SleepReportBuilder.build(samples: [phone], window: window))
        #expect(!r.hasStageDetail)
        #expect(r.estimatedAsleep == 8 * 3600)
    }

    @Test func reportsGapsOfFifteenMinutesOrMore() throws {
        let samples = [
            s(.core, T.d(2026, 10, 1, 23), T.d(2026, 10, 2, 1)),
            s(.core, T.d(2026, 10, 2, 2), T.d(2026, 10, 2, 4)),
            s(.core, T.d(2026, 10, 2, 4, 10), T.d(2026, 10, 2, 6)),
        ]
        let r = try #require(SleepReportBuilder.build(samples: samples, window: window))
        #expect(r.gaps == [DateInterval(start: T.d(2026, 10, 2, 1), end: T.d(2026, 10, 2, 2))])
    }

    @Test func clipsAndIgnoresSamplesOutsideTheWindow() throws {
        let yesterdayMorning = s(.core, T.d(2026, 10, 1, 3), T.d(2026, 10, 1, 6))
        let nap = s(.core, T.d(2026, 10, 1, 17), T.d(2026, 10, 1, 19)) // clipped to 18:00–19:00
        let r = try #require(SleepReportBuilder.build(samples: [yesterdayMorning, nap], window: window))
        #expect(r.sleepStart == T.d(2026, 10, 1, 18))
        #expect(r.estimatedAsleep == 3600)
    }

    @Test func fallBackNightCountsRealElapsedTime() throws {
        let w = NightWindow.forMorning(of: T.d(2026, 11, 1, 9), calendar: T.cal)
        // 23:00 to 07:00 across the 02:00 fall-back is 9 real hours.
        let sample = s(.core, T.d(2026, 10, 31, 23), T.d(2026, 11, 1, 7))
        let r = try #require(SleepReportBuilder.build(samples: [sample], window: w))
        #expect(r.estimatedAsleep == 9 * 3600)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SleepReportTests`
Expected: build FAILS with "cannot find 'SleepReportBuilder' in scope".

- [ ] **Step 3: Implement the builder**

`Sources/StillmoonCore/SleepReport.swift`:
```swift
import Foundation

public struct NightReport: Sendable, Equatable {
    public let sleepStart: Date
    public let sleepEnd: Date
    /// Seconds asleep (core, deep, REM, unspecified), overlaps merged.
    public let estimatedAsleep: TimeInterval
    public let stageDurations: [SleepStage: TimeInterval]
    public let hasStageDetail: Bool
    /// Spans inside the sleep window with no data from the primary source.
    public let gaps: [DateInterval]
    public let primarySource: String
    /// Every source that recorded this night, primary first, then alphabetical.
    public let allSources: [String]
    /// Primary-source samples, deduplicated and sorted by start.
    public let timeline: [SleepSample]
}

public enum SleepReportBuilder {
    public static let minimumGap: TimeInterval = 15 * 60

    public static func build(samples: [SleepSample], window: NightWindow) -> NightReport? {
        let clipped = Set(samples).compactMap { clip($0, to: window) }
        guard clipped.contains(where: { $0.stage.isAsleep }) else { return nil }

        let bySource = Dictionary(grouping: clipped, by: \.sourceName)
        let ranked = bySource.map { name, items in
            (name: name,
             detailed: items.contains { $0.stage.isDetailed },
             asleep: total(merge(items.filter { $0.stage.isAsleep })))
        }.sorted { a, b in
            if a.detailed != b.detailed { return a.detailed }
            if a.asleep != b.asleep { return a.asleep > b.asleep }
            return a.name < b.name
        }
        let primary = ranked[0].name
        let timeline = Set(bySource[primary]!).sorted { ($0.start, $0.end) < ($1.start, $1.end) }

        let asleep = merge(timeline.filter { $0.stage.isAsleep })
        let sleepStart = asleep.first!.start
        let sleepEnd = asleep.last!.end

        var stageDurations: [SleepStage: TimeInterval] = [:]
        for (stage, items) in Dictionary(grouping: timeline, by: \.stage) {
            stageDurations[stage] = total(merge(items))
        }

        return NightReport(
            sleepStart: sleepStart,
            sleepEnd: sleepEnd,
            estimatedAsleep: total(asleep),
            stageDurations: stageDurations,
            hasStageDetail: timeline.contains { $0.stage.isDetailed },
            gaps: gaps(in: merge(timeline), from: sleepStart, to: sleepEnd),
            primarySource: primary,
            allSources: ranked.map(\.name),
            timeline: timeline
        )
    }

    static func clip(_ sample: SleepSample, to window: NightWindow) -> SleepSample? {
        let start = max(sample.start, window.start)
        let end = min(sample.end, window.end)
        guard start < end else { return nil }
        var copy = sample
        copy.start = start
        copy.end = end
        return copy
    }

    static func merge(_ samples: [SleepSample]) -> [DateInterval] {
        mergeIntervals(samples.map { DateInterval(start: $0.start, end: $0.end) })
    }

    static func mergeIntervals(_ intervals: [DateInterval]) -> [DateInterval] {
        var result: [DateInterval] = []
        for next in intervals.sorted(by: { $0.start < $1.start }) {
            if let last = result.last, next.start <= last.end {
                result[result.count - 1] = DateInterval(start: last.start, end: max(last.end, next.end))
            } else {
                result.append(next)
            }
        }
        return result
    }

    static func total(_ intervals: [DateInterval]) -> TimeInterval {
        intervals.reduce(0) { $0 + $1.duration }
    }

    static func gaps(in covered: [DateInterval], from start: Date, to end: Date) -> [DateInterval] {
        var result: [DateInterval] = []
        var cursor = start
        for interval in covered where interval.end > start && interval.start < end {
            if interval.start.timeIntervalSince(cursor) >= minimumGap {
                result.append(DateInterval(start: cursor, end: interval.start))
            }
            cursor = max(cursor, interval.end)
        }
        return result
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SleepReportTests`
Expected: 9 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd ~/stillmoon
git add StillmoonCore
git commit -m "feat(core): nightly sleep report with dedup, source priority and gaps"
```

---

### Task 3: Night mode

**Files:**
- Create: `StillmoonCore/Sources/StillmoonCore/NightMode.swift`
- Test: `StillmoonCore/Tests/StillmoonCoreTests/NightModeTests.swift`

**Interfaces:**
- Produces: `ClockTime(hour:minute:)` with `minutesOfDay` and `minutesSinceSixPM`; `NightModeResolver.defaultBedtime`, `.defaultWake`, `.isNight(at:calendar:bedtime:wake:sessionActive:manualOverride:) -> Bool`.

Rules (PRD §7): manual toggle wins; an active sleep session means night; otherwise night runs from bedtime − 1 h to wake time, defaults 22:00 and 07:00.

- [ ] **Step 1: Write the failing tests**

`Tests/StillmoonCoreTests/NightModeTests.swift`:
```swift
import Foundation
import Testing
@testable import StillmoonCore

struct NightModeTests {
    func night(_ h: Int, _ m: Int = 0, bed: ClockTime? = nil, wake: ClockTime? = nil,
               session: Bool = false, manual: Bool? = nil) -> Bool {
        NightModeResolver.isNight(at: T.d(2026, 10, 2, h, m), calendar: T.cal, bedtime: bed, wake: wake,
                                  sessionActive: session, manualOverride: manual)
    }

    @Test func defaultsOpenAtNinePM() {
        #expect(!night(20, 59))
        #expect(night(21, 0))
        #expect(night(3))
        #expect(night(6, 59))
        #expect(!night(7, 0))
        #expect(!night(14))
    }

    @Test func bedtimeAfterMidnight() {
        let bed = ClockTime(hour: 0, minute: 30), wake = ClockTime(hour: 8, minute: 0)
        #expect(!night(23, 0, bed: bed, wake: wake))
        #expect(night(23, 45, bed: bed, wake: wake))
        #expect(night(7, 59, bed: bed, wake: wake))
        #expect(!night(8, 0, bed: bed, wake: wake))
    }

    @Test func bedtimeAtOneOpensAtMidnight() {
        let bed = ClockTime(hour: 1, minute: 0)
        #expect(night(0, 0, bed: bed))
        #expect(!night(23, 59, bed: bed))
    }

    @Test func activeSessionIsAlwaysNight() {
        #expect(night(14, session: true))
    }

    @Test func manualToggleWins() {
        #expect(!night(14, session: true, manual: false))
        #expect(night(14, manual: true))
    }

    @Test func minutesSinceSixPMWrapsMidnight() {
        #expect(ClockTime(hour: 23, minute: 50).minutesSinceSixPM == 350)
        #expect(ClockTime(hour: 0, minute: 10).minutesSinceSixPM == 370)
        #expect(ClockTime(hour: 18, minute: 0).minutesSinceSixPM == 0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter NightModeTests`
Expected: build FAILS with "cannot find 'NightModeResolver' in scope".

- [ ] **Step 3: Implement**

`Sources/StillmoonCore/NightMode.swift`:
```swift
import Foundation

public struct ClockTime: Codable, Sendable, Hashable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public init(of date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: c.hour!, minute: c.minute!)
    }

    public var minutesOfDay: Int { hour * 60 + minute }

    /// Minutes after 18:00, so evening and after-midnight times sort on one line.
    public var minutesSinceSixPM: Int { (minutesOfDay - 18 * 60 + 1440) % 1440 }
}

public enum NightModeResolver {
    public static let defaultBedtime = ClockTime(hour: 22, minute: 0)
    public static let defaultWake = ClockTime(hour: 7, minute: 0)
    static let leadMinutes = 60

    public static func isNight(at now: Date, calendar: Calendar, bedtime: ClockTime?, wake: ClockTime?,
                               sessionActive: Bool, manualOverride: Bool?) -> Bool {
        if let manualOverride { return manualOverride }
        if sessionActive { return true }

        let start = ((bedtime ?? defaultBedtime).minutesOfDay - leadMinutes + 1440) % 1440
        let end = (wake ?? defaultWake).minutesOfDay
        let m = ClockTime(of: now, calendar: calendar).minutesOfDay
        if start == end { return false }
        return start < end ? (m >= start && m < end) : (m >= start || m < end)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter NightModeTests`
Expected: 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd ~/stillmoon
git add StillmoonCore
git commit -m "feat(core): night mode resolver"
```

---

### Task 4: Weekly goal and journey progress

**Files:**
- Create: `StillmoonCore/Sources/StillmoonCore/Progress.swift`
- Test: `StillmoonCore/Tests/StillmoonCoreTests/ProgressTests.swift`

**Interfaces:**
- Consumes: `ExerciseCompletion`, `ExerciseCategory.windDown`.
- Produces: `ProgressSummary` (`windDownsThisWeek`, `weeklyGoal`, `goalMet`, `totalWindDowns`, `journeyStage`), `ProgressCalculator.stageThresholds`, `ProgressCalculator.summary(completions:weeklyGoal:now:calendar:)`.

Rules (PRD §8): only wind-down completions move the goal and journey; duplicates by `id` count once; week follows the calendar's `firstWeekday`; journey stage is computed from the all-time total so it can never go backward; goal below 1 is treated as 1.

- [ ] **Step 1: Write the failing tests**

`Tests/StillmoonCoreTests/ProgressTests.swift`:
```swift
import Foundation
import Testing
@testable import StillmoonCore

struct ProgressTests {
    // 2026-10-02 is a Friday; the week (Sunday start) began 2026-09-27.
    let now = T.d(2026, 10, 2, 12)

    func wd(_ at: Date, id: UUID = UUID()) -> ExerciseCompletion {
        ExerciseCompletion(id: id, exerciseID: "breathing", category: .windDown, completedAt: at)
    }

    func summary(_ c: [ExerciseCompletion], goal: Int = 3) -> ProgressSummary {
        ProgressCalculator.summary(completions: c, weeklyGoal: goal, now: now, calendar: T.cal)
    }

    @Test func countsOnlyThisWeeksWindDowns() {
        let c = [
            wd(T.d(2026, 9, 26, 22)),      // Saturday, last week
            wd(T.d(2026, 9, 27, 0, 5)),    // Sunday, this week
            wd(T.d(2026, 10, 1, 22)),
            ExerciseCompletion(exerciseID: "reset", category: .morningReset, completedAt: T.d(2026, 10, 1, 7)),
        ]
        let s = summary(c)
        #expect(s.windDownsThisWeek == 2)
        #expect(s.totalWindDowns == 3)
        #expect(!s.goalMet)
    }

    @Test func meetsGoal() {
        let c = (0..<3).map { wd(T.d(2026, 9, 28 + $0, 22)) }
        #expect(summary(c).goalMet)
    }

    @Test func sameEventSyncedTwiceCountsOnce() {
        let id = UUID()
        let s = summary([wd(T.d(2026, 10, 1, 22), id: id), wd(T.d(2026, 10, 1, 22), id: id)])
        #expect(s.windDownsThisWeek == 1)
        #expect(s.totalWindDowns == 1)
    }

    @Test func goalBelowOneIsClamped() {
        let s = summary([wd(T.d(2026, 10, 1, 22))], goal: 0)
        #expect(s.weeklyGoal == 1)
        #expect(s.goalMet)
    }

    @Test(arguments: [(0, 0), (1, 1), (2, 1), (3, 2), (6, 3), (10, 4), (15, 5), (21, 6), (40, 6)])
    func journeyStages(total: Int, stage: Int) {
        let c = (0..<total).map { wd(T.d(2026, 1, 1).addingTimeInterval(Double($0) * 86400)) }
        #expect(summary(c).journeyStage == stage)
    }

    @Test func journeyNeverGoesBackward() {
        var c: [ExerciseCompletion] = []
        var last = 0
        for i in 0..<30 {
            c.append(wd(T.d(2026, 1, 1).addingTimeInterval(Double(i) * 86400)))
            let stage = summary(c).journeyStage
            #expect(stage >= last)
            last = stage
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ProgressTests`
Expected: build FAILS with "cannot find 'ProgressCalculator' in scope".

- [ ] **Step 3: Implement**

`Sources/StillmoonCore/Progress.swift`:
```swift
import Foundation

public struct ProgressSummary: Sendable, Equatable {
    public let windDownsThisWeek: Int
    public let weeklyGoal: Int
    public let goalMet: Bool
    public let totalWindDowns: Int
    /// 0...6, one per illustrated journey stage.
    public let journeyStage: Int
}

public enum ProgressCalculator {
    /// Total wind-downs needed to reach each journey stage.
    public static let stageThresholds = [0, 1, 3, 6, 10, 15, 21]

    public static func summary(completions: [ExerciseCompletion], weeklyGoal: Int,
                               now: Date, calendar: Calendar) -> ProgressSummary {
        var seen = Set<UUID>()
        let windDowns = completions.filter { $0.category == .windDown && seen.insert($0.id).inserted }

        let week = calendar.dateInterval(of: .weekOfYear, for: now)!
        let thisWeek = windDowns.filter { $0.completedAt >= week.start && $0.completedAt < week.end }.count
        let goal = max(1, weeklyGoal)
        let stage = stageThresholds.lastIndex { windDowns.count >= $0 }!

        return ProgressSummary(
            windDownsThisWeek: thisWeek,
            weeklyGoal: goal,
            goalMet: thisWeek >= goal,
            totalWindDowns: windDowns.count,
            journeyStage: stage
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ProgressTests`
Expected: all ProgressTests PASS (6 tests, one parameterised with 9 cases).

- [ ] **Step 5: Commit**

```bash
cd ~/stillmoon
git add StillmoonCore
git commit -m "feat(core): weekly goal and journey progress"
```

---

### Task 5: Recommendation engine

**Files:**
- Create: `StillmoonCore/Sources/StillmoonCore/Recommendations.swift`
- Test: `StillmoonCore/Tests/StillmoonCoreTests/RecommendationTests.swift`

**Interfaces:**
- Consumes: `Goal`, `CheckIn`, `ClockTime(of:calendar:)` and `.minutesSinceSixPM` (Task 3).
- Produces: `ContentTag`, `ContentKind`, `CatalogItem`, `FeedbackRating`, `RecommendationFeedback`, `Recommendation`, `RecommendationInput`, `RecommendationEngine.recommend(_:calendar:) -> [Recommendation]`, `RecommendationEngine.Reason` constants, `RecommendationEngine.bedtimesVary(_:calendar:)`.

Rules (PRD §8 table), in priority order, at most 3, no item twice:
1. Today's check-in `tenseAtBedtime` → first eligible `.relaxation` item, "You mentioned feeling tense before bed."
2. Today's check-in `wokeDuringNight` → first eligible `.awakeAtNight` item, "You mentioned being awake during the night."
3. At least 4 bedtimes in the input and their spread (on the 18:00-based line) is over 90 minutes → first eligible `.routine` item, "Your recorded bedtimes varied this week."
4. Fill remaining slots from the goal's tag, "Based on the goal you chose."

Feedback: any `unwanted` rating removes the item entirely; 2+ `irrelevant` ratings move the item behind every other item with the same tag. Within a tag, catalog order decides.

Goal → tag: unwind → relaxation, understandSleep → sleepData, nightWaking → awakeAtNight, consistency → routine.

- [ ] **Step 1: Write the failing tests**

`Tests/StillmoonCoreTests/RecommendationTests.swift`:
```swift
import Foundation
import Testing
@testable import StillmoonCore

struct RecommendationTests {
    let catalog = [
        CatalogItem(id: "pmr", kind: .exercise, title: "Progressive muscle relaxation", tags: [.relaxation]),
        CatalogItem(id: "breath", kind: .exercise, title: "Gentle breathing", tags: [.relaxation]),
        CatalogItem(id: "awake-5", kind: .exercise, title: "Five quiet minutes", tags: [.awakeAtNight]),
        CatalogItem(id: "timing", kind: .article, title: "Keeping a steady bedtime", tags: [.routine]),
        CatalogItem(id: "stages", kind: .article, title: "What your watch estimates", tags: [.sleepData]),
    ]

    func run(goal: Goal = .unwind, checkIn: CheckIn? = nil, bedtimes: [Date] = [],
             feedback: [RecommendationFeedback] = [], catalog: [CatalogItem]? = nil) -> [Recommendation] {
        RecommendationEngine.recommend(
            RecommendationInput(goal: goal, todayCheckIn: checkIn, recentBedtimes: bedtimes,
                                feedback: feedback, catalog: catalog ?? self.catalog),
            calendar: T.cal)
    }

    func checkIn(tense: Bool = false, woke: Bool = false) -> CheckIn {
        CheckIn(date: T.d(2026, 10, 2, 8), restedness: 3, tenseAtBedtime: tense, wokeDuringNight: woke)
    }

    func fb(_ id: String, _ r: FeedbackRating) -> RecommendationFeedback {
        RecommendationFeedback(itemID: id, rating: r, at: T.d(2026, 10, 1))
    }

    @Test func tenseLeadsWithRelaxation() {
        let r = run(goal: .understandSleep, checkIn: checkIn(tense: true))
        #expect(r.first == Recommendation(itemID: "pmr", reason: RecommendationEngine.Reason.tense))
        #expect(r.first?.reason == "You mentioned feeling tense before bed.")
    }

    @Test func tenseAndWokeGiveBoth() {
        let r = run(goal: .understandSleep, checkIn: checkIn(tense: true, woke: true))
        #expect(r.map(\.itemID) == ["pmr", "awake-5", "stages"])
        #expect(r[1].reason == "You mentioned being awake during the night.")
        #expect(r[2].reason == "Based on the goal you chose.")
    }

    @Test func sparseDataFallsBackToGoal() {
        let r = run(goal: .unwind)
        #expect(r.map(\.itemID) == ["pmr", "breath"])
        #expect(r.allSatisfy { $0.reason == RecommendationEngine.Reason.goal })
    }

    @Test func unwantedIsNeverShown() {
        let r = run(goal: .unwind, checkIn: checkIn(tense: true), feedback: [fb("pmr", .unwanted)])
        #expect(!r.contains { $0.itemID == "pmr" })
        #expect(r.first?.itemID == "breath")
    }

    @Test func dismissedTwiceIsDemoted() {
        let r = run(checkIn: checkIn(tense: true), feedback: [fb("pmr", .irrelevant), fb("pmr", .irrelevant)])
        #expect(r.map(\.itemID) == ["breath", "pmr"])
    }

    @Test func dismissedOnceKeepsItsPlace() {
        let r = run(checkIn: checkIn(tense: true), feedback: [fb("pmr", .irrelevant)])
        #expect(r.first?.itemID == "pmr")
    }

    @Test func neverMoreThanThreeAndNoRepeats() {
        let many = (0..<10).map { CatalogItem(id: "r\($0)", kind: .exercise, title: "R\($0)", tags: [.relaxation]) }
        let r = run(goal: .unwind, checkIn: checkIn(tense: true), catalog: many)
        #expect(r.count == 3)
        #expect(Set(r.map(\.itemID)).count == 3)
    }

    @Test func emptyCatalogGivesNothing() {
        #expect(run(checkIn: checkIn(tense: true), catalog: []).isEmpty)
    }

    @Test func variedBedtimesAcrossMidnightSuggestRoutine() {
        let beds = [T.d(2026, 9, 27, 22), T.d(2026, 9, 28, 23, 45), T.d(2026, 9, 30, 0, 30), T.d(2026, 9, 30, 22, 15)]
        let r = run(goal: .understandSleep, bedtimes: beds)
        #expect(r.first == Recommendation(itemID: "timing", reason: "Your recorded bedtimes varied this week."))
    }

    @Test func steadyBedtimesAroundMidnightAreNotVaried() {
        let beds = [T.d(2026, 9, 27, 23, 50), T.d(2026, 9, 29, 0, 10), T.d(2026, 9, 29, 23, 55), T.d(2026, 10, 1, 0, 5)]
        #expect(!RecommendationEngine.bedtimesVary(beds, calendar: T.cal))
    }

    @Test func fewerThanFourBedtimesAreNotEnough() {
        let beds = [T.d(2026, 9, 27, 21), T.d(2026, 9, 28, 1), T.d(2026, 9, 29, 23)]
        #expect(!RecommendationEngine.bedtimesVary(beds, calendar: T.cal))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter RecommendationTests`
Expected: build FAILS with "cannot find 'CatalogItem' in scope".

- [ ] **Step 3: Implement**

`Sources/StillmoonCore/Recommendations.swift`:
```swift
import Foundation

public enum ContentTag: String, Codable, Sendable, CaseIterable {
    case relaxation, awakeAtNight, routine, sleepData, morning
}

public enum ContentKind: String, Codable, Sendable {
    case exercise, article
}

public struct CatalogItem: Codable, Sendable, Hashable {
    public var id: String
    public var kind: ContentKind
    public var title: String
    public var tags: Set<ContentTag>

    public init(id: String, kind: ContentKind, title: String, tags: Set<ContentTag>) {
        self.id = id
        self.kind = kind
        self.title = title
        self.tags = tags
    }
}

public enum FeedbackRating: String, Codable, Sendable {
    case helpful, irrelevant, unwanted
}

public struct RecommendationFeedback: Codable, Sendable, Hashable {
    public var id: UUID
    public var itemID: String
    public var rating: FeedbackRating
    public var at: Date

    public init(id: UUID = UUID(), itemID: String, rating: FeedbackRating, at: Date) {
        self.id = id
        self.itemID = itemID
        self.rating = rating
        self.at = at
    }
}

public struct Recommendation: Sendable, Equatable {
    public let itemID: String
    public let reason: String

    public init(itemID: String, reason: String) {
        self.itemID = itemID
        self.reason = reason
    }
}

public struct RecommendationInput: Sendable {
    public var goal: Goal
    /// Only today's check-in; pass nil if the user has not checked in today.
    public var todayCheckIn: CheckIn?
    /// Bedtimes from the last 7 nights (journal entries or report sleep starts).
    public var recentBedtimes: [Date]
    public var feedback: [RecommendationFeedback]
    /// In editorial order; earlier items win ties.
    public var catalog: [CatalogItem]

    public init(goal: Goal, todayCheckIn: CheckIn?, recentBedtimes: [Date],
                feedback: [RecommendationFeedback], catalog: [CatalogItem]) {
        self.goal = goal
        self.todayCheckIn = todayCheckIn
        self.recentBedtimes = recentBedtimes
        self.feedback = feedback
        self.catalog = catalog
    }
}

public enum RecommendationEngine {
    public static let maxResults = 3
    static let minimumBedtimes = 4
    static let variedSpreadMinutes = 90
    static let demoteAfterIrrelevant = 2

    public enum Reason {
        public static let tense = "You mentioned feeling tense before bed."
        public static let woke = "You mentioned being awake during the night."
        public static let varied = "Your recorded bedtimes varied this week."
        public static let goal = "Based on the goal you chose."
    }

    public static func recommend(_ input: RecommendationInput, calendar: Calendar) -> [Recommendation] {
        let unwanted = Set(input.feedback.filter { $0.rating == .unwanted }.map(\.itemID))
        let irrelevant = Dictionary(input.feedback.filter { $0.rating == .irrelevant }.map { ($0.itemID, 1) },
                                    uniquingKeysWith: +)
        let eligible = input.catalog.filter { !unwanted.contains($0.id) }

        var results: [Recommendation] = []
        func candidates(_ tag: ContentTag) -> [CatalogItem] {
            let open = eligible.filter { item in
                item.tags.contains(tag) && !results.contains { $0.itemID == item.id }
            }
            let demoted = { (item: CatalogItem) in (irrelevant[item.id] ?? 0) >= demoteAfterIrrelevant }
            return open.filter { !demoted($0) } + open.filter(demoted)
        }
        func add(_ tag: ContentTag, _ reason: String) {
            guard results.count < maxResults, let item = candidates(tag).first else { return }
            results.append(Recommendation(itemID: item.id, reason: reason))
        }

        if input.todayCheckIn?.tenseAtBedtime == true { add(.relaxation, Reason.tense) }
        if input.todayCheckIn?.wokeDuringNight == true { add(.awakeAtNight, Reason.woke) }
        if bedtimesVary(input.recentBedtimes, calendar: calendar) { add(.routine, Reason.varied) }
        for item in candidates(tag(for: input.goal)) where results.count < maxResults {
            results.append(Recommendation(itemID: item.id, reason: Reason.goal))
        }
        return results
    }

    public static func bedtimesVary(_ bedtimes: [Date], calendar: Calendar) -> Bool {
        guard bedtimes.count >= minimumBedtimes else { return false }
        let minutes = bedtimes.map { ClockTime(of: $0, calendar: calendar).minutesSinceSixPM }
        return minutes.max()! - minutes.min()! > variedSpreadMinutes
    }

    static func tag(for goal: Goal) -> ContentTag {
        switch goal {
        case .unwind: .relaxation
        case .understandSleep: .sleepData
        case .nightWaking: .awakeAtNight
        case .consistency: .routine
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter RecommendationTests`
Expected: 11 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd ~/stillmoon
git add StillmoonCore
git commit -m "feat(core): on-device recommendation rules with feedback suppression"
```

---

### Task 6: Referral signals and sound launch gate

**Files:**
- Create: `StillmoonCore/Sources/StillmoonCore/Signals.swift`
- Test: `StillmoonCore/Tests/StillmoonCoreTests/SignalsTests.swift`

**Interfaces:**
- Consumes: `CheckIn`, `SoundEvent`, `SoundLabel`, `SoundCorrection`, `NightWindow.nightKey(for:calendar:)`.
- Produces: `ReferralSignals.showsDifficultyCard(todayCheckIn:) -> Bool`, `ReferralSignals.showsSnoringNote(events:now:calendar:alreadyShown:) -> Bool`, `SoundGate.maxFalseRate`, `SoundGate.falseRate(_:) -> Double?`, `SoundGate.passes(_:) -> Bool`.

Rules (PRD §9, §6): difficulty card only from the structured check-in option; snoring note when "this was me" snoring-like events fall on ≥ 5 distinct nights within the last 7 days and the note has not been shown; sound gate false rate = (incorrect + someoneElse) / reviewed events, where reviewed means correction ≠ none; no reviewed events → no rate → does not pass.

- [ ] **Step 1: Write the failing tests**

`Tests/StillmoonCoreTests/SignalsTests.swift`:
```swift
import Foundation
import Testing
@testable import StillmoonCore

struct SignalsTests {
    let now = T.d(2026, 10, 8, 9)

    func snore(_ at: Date, _ c: SoundCorrection = .wasMe) -> SoundEvent {
        SoundEvent(label: .snoringLike, at: at, confidence: 0.8, correction: c)
    }

    @Test func difficultyCardFollowsTheCheckInOption() {
        let yes = CheckIn(date: now, restedness: 2, persistentDifficulty: true)
        let no = CheckIn(date: now, restedness: 2)
        #expect(ReferralSignals.showsDifficultyCard(todayCheckIn: yes))
        #expect(!ReferralSignals.showsDifficultyCard(todayCheckIn: no))
        #expect(!ReferralSignals.showsDifficultyCard(todayCheckIn: nil))
    }

    @Test func snoringNoteNeedsFiveDistinctNights() {
        let fiveNights = (2...6).map { snore(T.d(2026, 10, $0, 23)) }
        #expect(ReferralSignals.showsSnoringNote(events: fiveNights, now: now, calendar: T.cal, alreadyShown: false))
    }

    @Test func twoEventsInOneNightCountOnce() {
        // Nights of Oct 2..5, plus 03:00 on Oct 6, which still belongs to the night of Oct 5.
        let events = (2...5).map { snore(T.d(2026, 10, $0, 23)) } + [snore(T.d(2026, 10, 6, 3))]
        #expect(!ReferralSignals.showsSnoringNote(events: events, now: now, calendar: T.cal, alreadyShown: false))
    }

    @Test func snoringNoteIgnoresOtherCorrectionsAndOldNights() {
        let others = (2...6).map { snore(T.d(2026, 10, $0, 23), .someoneElse) }
        #expect(!ReferralSignals.showsSnoringNote(events: others, now: now, calendar: T.cal, alreadyShown: false))
        let old = (20...24).map { snore(T.d(2026, 9, $0, 23)) }
        #expect(!ReferralSignals.showsSnoringNote(events: old, now: now, calendar: T.cal, alreadyShown: false))
    }

    @Test func snoringNoteIsShownOnce() {
        let events = (2...6).map { snore(T.d(2026, 10, $0, 23)) }
        #expect(!ReferralSignals.showsSnoringNote(events: events, now: now, calendar: T.cal, alreadyShown: true))
    }

    @Test func gateRateCountsOnlyReviewedEvents() {
        let events = [
            snore(now, .wasMe), snore(now, .wasMe), snore(now, .wasMe), snore(now, .wasMe),
            snore(now, .incorrect),
            snore(now, .none), snore(now, .none),
        ]
        #expect(SoundGate.falseRate(events) == 0.2)
        #expect(!SoundGate.passes(events)) // must be strictly below 1 in 5
    }

    @Test func gatePassesBelowOneInFive() {
        let events = (0..<9).map { _ in snore(now, .wasMe) } + [snore(now, .someoneElse)]
        #expect(SoundGate.passes(events))
    }

    @Test func gateWithNoReviewsDoesNotPass() {
        #expect(SoundGate.falseRate([snore(now, .none)]) == nil)
        #expect(!SoundGate.passes([]))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SignalsTests`
Expected: build FAILS with "cannot find 'ReferralSignals' in scope".

- [ ] **Step 3: Implement**

`Sources/StillmoonCore/Signals.swift`:
```swift
import Foundation

/// Structured signals for the "talk to a professional" messages. Journal text is never read.
public enum ReferralSignals {
    static let snoringNights = 5
    static let lookbackDays = 7

    public static func showsDifficultyCard(todayCheckIn: CheckIn?) -> Bool {
        todayCheckIn?.persistentDifficulty ?? false
    }

    public static func showsSnoringNote(events: [SoundEvent], now: Date, calendar: Calendar,
                                        alreadyShown: Bool) -> Bool {
        guard !alreadyShown else { return false }
        let since = calendar.date(byAdding: .day, value: -lookbackDays, to: now)!
        let nights = Set(events
            .filter { $0.label == .snoringLike && $0.correction == .wasMe && $0.at >= since && $0.at <= now }
            .map { NightWindow.nightKey(for: $0.at, calendar: calendar) })
        return nights.count >= snoringNights
    }
}

/// The internal launch gate for sound detection (PRD §6).
public enum SoundGate {
    public static let maxFalseRate = 0.2

    /// Share of reviewed events the user marked incorrect or someone else; nil if none reviewed.
    public static func falseRate(_ events: [SoundEvent]) -> Double? {
        let reviewed = events.filter { $0.correction != .none }
        guard !reviewed.isEmpty else { return nil }
        let wrong = reviewed.filter { $0.correction == .incorrect || $0.correction == .someoneElse }
        return Double(wrong.count) / Double(reviewed.count)
    }

    public static func passes(_ events: [SoundEvent]) -> Bool {
        guard let rate = falseRate(events) else { return false }
        return rate < maxFalseRate
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SignalsTests`
Expected: 8 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd ~/stillmoon
git add StillmoonCore
git commit -m "feat(core): referral signals and sound launch gate metric"
```

---

### Task 7: Export (JSON + CSV)

**Files:**
- Create: `StillmoonCore/Sources/StillmoonCore/Export.swift`
- Test: `StillmoonCore/Tests/StillmoonCoreTests/ExportTests.swift`

**Interfaces:**
- Consumes: `SleepSample`, `CheckIn`, `SoundEvent`, `ExerciseCompletion`, `RecommendationFeedback`.
- Produces: `NightExport`, `ExportBundle`, `ExportWriter.json(_:) throws -> Data`, `ExportWriter.decode(_:) throws -> ExportBundle`, `ExportWriter.nightsCSV(_:)`, `.checkInsCSV(_:)`, `.soundEventsCSV(_:)`, internal `ExportWriter.field(_:)`. The ZIP wrapper is built in Plan 7.

Rules (PRD §9): JSON is complete (every record); CSV covers nights, check-ins, sound events. Dates are ISO 8601 UTC. CSV fields with comma, quote, CR or LF are quoted with quotes doubled. Lines end with `\n`, with a trailing newline.

- [ ] **Step 1: Write the failing tests**

`Tests/StillmoonCoreTests/ExportTests.swift`:
```swift
import Foundation
import Testing
@testable import StillmoonCore

struct ExportTests {
    let checkIn = CheckIn(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                          date: T.d(2026, 10, 2, 8), restedness: 4, tenseAtBedtime: true,
                          note: "Slept \"ok\", woke at 3\nthen read")

    var bundle: ExportBundle {
        ExportBundle(
            exportedAt: T.d(2026, 10, 2, 9),
            nights: [NightExport(nightOf: T.d(2026, 10, 1), sleepStart: T.d(2026, 10, 1, 23),
                                 sleepEnd: T.d(2026, 10, 2, 6, 30), asleepMinutes: 440,
                                 primarySource: "Apple Watch",
                                 samples: [SleepSample(stage: .core, start: T.d(2026, 10, 1, 23),
                                                       end: T.d(2026, 10, 2, 6, 30), sourceName: "Apple Watch")])],
            checkIns: [checkIn],
            soundEvents: [SoundEvent(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                                     label: .speechLike, at: T.d(2026, 10, 2, 2, 14), confidence: 0.61,
                                     correction: .someoneElse)],
            completions: [ExerciseCompletion(exerciseID: "breath", category: .windDown, completedAt: T.d(2026, 10, 1, 22))],
            feedback: [RecommendationFeedback(itemID: "breath", rating: .helpful, at: T.d(2026, 10, 2, 8))]
        )
    }

    @Test func jsonRoundTrips() throws {
        let original = bundle // computed once: it mints random UUIDs
        let data = try ExportWriter.json(original)
        #expect(try ExportWriter.decode(data) == original)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"exportedAt\" : \"2026-10-02T13:00:00Z\""))
    }

    @Test func checkInCSVEscapesNotes() {
        let csv = ExportWriter.checkInsCSV([checkIn])
        let expected = """
        date,restedness,tense_at_bedtime,woke_during_night,persistent_difficulty,note
        2026-10-02T12:00:00Z,4,true,false,false,"Slept ""ok"", woke at 3
        then read"

        """
        #expect(csv == expected)
    }

    @Test func soundEventsCSV() {
        let csv = ExportWriter.soundEventsCSV(bundle.soundEvents)
        #expect(csv == "time,label,confidence,correction\n2026-10-02T06:14:00Z,speechLike,0.61,someoneElse\n")
    }

    @Test func nightsCSV() {
        let csv = ExportWriter.nightsCSV(bundle.nights)
        #expect(csv == "night_of,sleep_start,sleep_end,asleep_minutes,source\n2026-10-01T04:00:00Z,2026-10-02T03:00:00Z,2026-10-02T10:30:00Z,440,Apple Watch\n")
    }

    @Test func emptyCSVHasHeaderOnly() {
        #expect(ExportWriter.soundEventsCSV([]) == "time,label,confidence,correction\n")
    }

    @Test(arguments: [("plain", "plain"), ("a,b", "\"a,b\""), ("say \"hi\"", "\"say \"\"hi\"\"\""), ("line\rbreak", "\"line\rbreak\""), ("a\r\nb", "\"a\r\nb\"")])
    func fieldEscaping(input: String, output: String) {
        #expect(ExportWriter.field(input) == output)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ExportTests`
Expected: build FAILS with "cannot find 'ExportBundle' in scope".

- [ ] **Step 3: Implement**

`Sources/StillmoonCore/Export.swift`:
```swift
import Foundation

public struct NightExport: Codable, Sendable, Equatable {
    public var nightOf: Date
    public var sleepStart: Date
    public var sleepEnd: Date
    public var asleepMinutes: Int
    public var primarySource: String
    public var samples: [SleepSample]

    public init(nightOf: Date, sleepStart: Date, sleepEnd: Date, asleepMinutes: Int,
                primarySource: String, samples: [SleepSample]) {
        self.nightOf = nightOf
        self.sleepStart = sleepStart
        self.sleepEnd = sleepEnd
        self.asleepMinutes = asleepMinutes
        self.primarySource = primarySource
        self.samples = samples
    }
}

/// Everything one account has, local and server-side, for the user's export.
public struct ExportBundle: Codable, Sendable, Equatable {
    public var exportedAt: Date
    public var nights: [NightExport]
    public var checkIns: [CheckIn]
    public var soundEvents: [SoundEvent]
    public var completions: [ExerciseCompletion]
    public var feedback: [RecommendationFeedback]

    public init(exportedAt: Date, nights: [NightExport], checkIns: [CheckIn], soundEvents: [SoundEvent],
                completions: [ExerciseCompletion], feedback: [RecommendationFeedback]) {
        self.exportedAt = exportedAt
        self.nights = nights
        self.checkIns = checkIns
        self.soundEvents = soundEvents
        self.completions = completions
        self.feedback = feedback
    }
}

public enum ExportWriter {
    public static func json(_ bundle: ExportBundle) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(bundle)
    }

    public static func decode(_ data: Data) throws -> ExportBundle {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ExportBundle.self, from: data)
    }

    public static func nightsCSV(_ nights: [NightExport]) -> String {
        csv(header: ["night_of", "sleep_start", "sleep_end", "asleep_minutes", "source"],
            rows: nights.map { [iso($0.nightOf), iso($0.sleepStart), iso($0.sleepEnd), String($0.asleepMinutes), $0.primarySource] })
    }

    public static func checkInsCSV(_ checkIns: [CheckIn]) -> String {
        csv(header: ["date", "restedness", "tense_at_bedtime", "woke_during_night", "persistent_difficulty", "note"],
            rows: checkIns.map { [iso($0.date), String($0.restedness), String($0.tenseAtBedtime),
                                  String($0.wokeDuringNight), String($0.persistentDifficulty), $0.note ?? ""] })
    }

    public static func soundEventsCSV(_ events: [SoundEvent]) -> String {
        csv(header: ["time", "label", "confidence", "correction"],
            rows: events.map { [iso($0.at), $0.label.rawValue, String($0.confidence), $0.correction.rawValue] })
    }

    static func csv(header: [String], rows: [[String]]) -> String {
        ([header] + rows).map { $0.map(field).joined(separator: ",") + "\n" }.joined()
    }

    static func field(_ value: String) -> String {
        // Unicode scalars, not Characters: "\r\n" is one Character and would match neither "\r" nor "\n".
        let needsQuotes = value.unicodeScalars.contains { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }
        guard needsQuotes else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func iso(_ date: Date) -> String {
        date.formatted(.iso8601)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ExportTests`
Expected: all ExportTests PASS (5 tests + 5 parameterised cases).

- [ ] **Step 5: Run the whole suite**

Run: `swift test`
Expected: every test in all 7 suites PASSES, no warnings about Sendable or concurrency.

- [ ] **Step 6: Commit**

```bash
cd ~/stillmoon
git add StillmoonCore
git commit -m "feat(core): JSON and CSV export"
```
