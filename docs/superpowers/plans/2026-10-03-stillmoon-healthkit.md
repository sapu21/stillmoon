# Stillmoon HealthKit Implementation Plan (Plan 3 of 7)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Read sleep from Apple Health into the nightly report (Sleep tab history, night detail with a stage timeline, Today's last-night card, recommendation inputs) and write completed exercises to Apple Health as Mindful Minutes, with Health access offered in onboarding and Settings.

**Architecture:** A `HealthDataSource` protocol with a real `HealthKitService` (HKHealthStore, async queries) and a `FakeHealthSource` used by unit tests and by UI tests via the `-fake-health` launch argument. Health samples are never copied into SwiftData: each screen queries Health and builds reports with `StillmoonCore.SleepReportBuilder`. Health access is a per-owner setting (`healthConnected`).

**Tech Stack:** HealthKit (`HKSampleQueryDescriptor`, `HKCategoryValueSleepAnalysis`, mindful sessions), Swift Charts, SwiftUI, Swift Testing, XCTest UI tests. Builds on Plan 1 (`StillmoonCore`) and Plan 2 (app shell), both merged.

**Spec:** `docs/PRD-v1.2.md` (§4, §5 onboarding step 5, FR-04, FR-05, FR-16, §7 Sleep screen, §9 safety language).

## Global Constraints

- Everything in Plan 2's constraints still applies: iOS 17.0, iPhone only, `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor` on app and unit tests, no third-party dependencies, every test file starts with `import Foundation`, `Stillmoon.xcodeproj` generated from `project.yml`.
- HealthKit permissions: read `HKCategoryType(.sleepAnalysis)`; share (write) `HKCategoryType(.mindfulSession)` only. Never read mindful sessions (FR-16).
- Usage strings (verbatim): `NSHealthShareUsageDescription` = "Stillmoon reads your sleep from Apple Health to show your nights and suggest a next step. Your sleep data stays on this iPhone." `NSHealthUpdateUsageDescription` = "Stillmoon saves completed exercises to Apple Health as Mindful Minutes."
- Health samples are not stored in SwiftData and never leave the device.
- Device estimates are labelled with their source and as estimates: "<source> estimated …", "Stages are estimates from your device, not measurements." A source without stage detail says "<source> recorded time asleep without stages." Never imply the iPhone measured sleep stages (PRD §5 users).
- User-entered data stays visually separate and labelled "You recorded…" / "You felt…".
- New `AppSettings` keys must be added to `CodingKeys` and to the tolerant `init(from:)` with `decodeIfPresent ?? default` (Plan 2 fix).
- Unit tests: `scripts/test-app.sh -only-testing:StillmoonTests`; full (unit + UI): `scripts/test-app.sh`.

## Review Focus

1. **Health read fails or is not connected:** the Sleep tab still shows journal nights and a plain message; nothing crashes or empties silently. Pinned in Task 2 (`readFailureKeepsJournalRows`, `notConnectedShowsNoReports`).
2. **A night with both a journal entry and a Health report** shows both, separately labelled, as one row. Pinned in Task 2 (`journalAndHealthMergeIntoOneRow`).
3. **iPhone-only source** (no stages) never shows a stage chart or stage durations. Pinned in Task 3 (`stageRowsEmptyWithoutDetail`).
4. **Mindful Minutes written once per finished exercise**, never for an exercise ended early, and only when Health is connected. Pinned in Task 5 (`onFinishCalledOnceWithInterval`, `onFinishNotCalledWhenEndedEarly`) and the UI flow.
5. **Bedtime variety from Health nights** feeds recommendations without double-counting a night that also has a journal entry. Pinned in Task 4 (`healthAndJournalBedtimesDedupedPerNight`).

---

## File Structure

```
App/Stillmoon/Stillmoon.entitlements              # HealthKit entitlement (Task 1)
App/Stillmoon/Health/HealthDataSource.swift       # protocol, HealthError, SleepStage.title (Task 1)
App/Stillmoon/Health/HealthKitService.swift       # real HealthKit + SleepStageMapping (Task 1)
App/Stillmoon/Health/FakeHealthSource.swift       # tests and -fake-health (Task 1)
App/Stillmoon/Features/Sleep/SleepModel.swift     # rewritten: merged night rows (Task 2)
App/Stillmoon/Features/Sleep/SleepView.swift      # updated rows (Task 3)
App/Stillmoon/Features/Sleep/NightDetailView.swift# report detail + StageChart (Task 3)
App/Stillmoon/Features/Today/TodayModel.swift     # last-night report, health bedtimes (Task 4)
App/Stillmoon/Features/Today/TodayView.swift      # last-night card (Task 4)
App/Stillmoon/Features/Exercises/PlayerModel.swift# onFinish interval (Task 5)
App/Stillmoon/Features/Exercises/PlayerView.swift # passes onFinish (Task 5)
App/Stillmoon/Features/Onboarding/*               # health step (Task 5)
App/Stillmoon/Features/Settings/SettingsView.swift# Apple Health section (Task 5)
App/Stillmoon/Root/RootView.swift                 # wiring (Tasks 2, 4, 5)
```

---

### Task 1: Health data source

**Files:**
- Create: `App/Stillmoon/Stillmoon.entitlements`, `App/Stillmoon/Health/HealthDataSource.swift`, `App/Stillmoon/Health/HealthKitService.swift`, `App/Stillmoon/Health/FakeHealthSource.swift`
- Modify: `project.yml` (Stillmoon target settings), `App/Stillmoon/Settings/SettingsStore.swift` (`healthConnected`), `App/Stillmoon/Content/AppEnvironment.swift` (`health`, `connectHealth()`, `-fake-health`)
- Test: `App/StillmoonTests/HealthSourceTests.swift`

**Interfaces:**
- Produces:
  - `enum HealthError: Error, Equatable { case unavailable }`
  - `protocol HealthDataSource: AnyObject { var isAvailable: Bool { get }; func requestAuthorization() async throws; func sleepSamples(from: Date, to: Date) async throws -> [SleepSample]; func saveMindfulSession(start: Date, end: Date) async throws }`
  - `final class HealthKitService: HealthDataSource`, `enum SleepStageMapping { static func stage(forHealthKitValue: Int) -> SleepStage? }`
  - `final class FakeHealthSource: HealthDataSource { init(samples: [SleepSample] = []); var isAvailable; var samples; var failReads; authorizationRequested; mindfulSessions: [DateInterval]; static func sampleNight(endingOn: Date, calendar: Calendar, source: String = "Apple Watch") -> [SleepSample] }`
  - `extension SleepStage { var title: String }`
  - `AppSettings.healthConnected: Bool = false`
  - `AppEnvironment.health: HealthDataSource`, `init(store:settings:catalog:health: HealthDataSource = FakeHealthSource())`, `func connectHealth() async -> Bool`

- [ ] **Step 1: Write the failing tests**

`App/StillmoonTests/HealthSourceTests.swift`:
```swift
import Foundation
import HealthKit
import Testing
import StillmoonCore
@testable import Stillmoon

struct HealthSourceTests {
    @Test func mapsEverySleepValue() {
        #expect(SleepStageMapping.stage(forHealthKitValue: HKCategoryValueSleepAnalysis.inBed.rawValue) == .inBed)
        #expect(SleepStageMapping.stage(forHealthKitValue: HKCategoryValueSleepAnalysis.awake.rawValue) == .awake)
        #expect(SleepStageMapping.stage(forHealthKitValue: HKCategoryValueSleepAnalysis.asleepCore.rawValue) == .core)
        #expect(SleepStageMapping.stage(forHealthKitValue: HKCategoryValueSleepAnalysis.asleepDeep.rawValue) == .deep)
        #expect(SleepStageMapping.stage(forHealthKitValue: HKCategoryValueSleepAnalysis.asleepREM.rawValue) == .rem)
        #expect(SleepStageMapping.stage(forHealthKitValue: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue) == .asleepUnspecified)
        #expect(SleepStageMapping.stage(forHealthKitValue: 999) == nil)
    }

    @Test func stageTitles() {
        #expect(SleepStage.rem.title == "REM")
        #expect(SleepStage.asleepUnspecified.title == "Asleep")
        #expect(SleepStage.inBed.title == "In bed")
    }

    @Test func sampleNightIsAStagedNight() {
        let samples = FakeHealthSource.sampleNight(endingOn: TestEnv.d(2026, 10, 2, 9), calendar: TestEnv.cal)
        let report = SleepReportBuilder.build(samples: samples,
                                              window: NightWindow.forMorning(of: TestEnv.d(2026, 10, 2, 9), calendar: TestEnv.cal))
        #expect(report?.primarySource == "Apple Watch")
        #expect(report?.estimatedAsleep == 7 * 3600 + 20 * 60)
        #expect(report?.hasStageDetail == true)
    }

    @Test func fakeFiltersByRangeAndCanFail() async throws {
        let fake = FakeHealthSource(samples: FakeHealthSource.sampleNight(endingOn: TestEnv.d(2026, 10, 2, 9), calendar: TestEnv.cal))
        #expect(try await fake.sleepSamples(from: TestEnv.d(2026, 10, 2, 12), to: TestEnv.d(2026, 10, 2, 20)).isEmpty)
        #expect(try await fake.sleepSamples(from: TestEnv.d(2026, 10, 1, 18), to: TestEnv.d(2026, 10, 2, 12)).count == 5)
        fake.failReads = true
        await #expect(throws: HealthError.unavailable) {
            try await fake.sleepSamples(from: TestEnv.d(2026, 10, 1, 18), to: TestEnv.d(2026, 10, 2, 12))
        }
    }

    @Test func connectHealthSetsSettingOnlyWhenAvailable() async throws {
        let fake = FakeHealthSource()
        let env = AppEnvironment(store: try TestEnv.store(), settings: TestEnv.settings(), catalog: TestEnv.catalog, health: fake)
        #expect(await env.connectHealth())
        #expect(fake.authorizationRequested)
        #expect(env.settings.settings.healthConnected)

        let offline = FakeHealthSource()
        offline.isAvailable = false
        let env2 = AppEnvironment(store: try TestEnv.store(), settings: TestEnv.settings(), catalog: TestEnv.catalog, health: offline)
        #expect(await env2.connectHealth() == false)
        #expect(!env2.settings.settings.healthConnected)
    }

    @Test func healthConnectedDecodesFromOlderPayload() throws {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        defaults.set(Data(#"{"hasOnboarded":true}"#.utf8), forKey: SettingsStore.keyPrefix + LocalOwner.id)
        #expect(SettingsStore(defaults: defaults).settings.healthConnected == false)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/HealthSourceTests`
Expected: build FAILS with "cannot find 'SleepStageMapping' in scope".

- [ ] **Step 3: Add the capability**

`App/Stillmoon/Stillmoon.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array/>
</dict>
</plist>
```

In `project.yml`, add to `targets.Stillmoon.settings.base`:
```yaml
        CODE_SIGN_ENTITLEMENTS: App/Stillmoon/Stillmoon.entitlements
        INFOPLIST_KEY_NSHealthShareUsageDescription: "Stillmoon reads your sleep from Apple Health to show your nights and suggest a next step. Your sleep data stays on this iPhone."
        INFOPLIST_KEY_NSHealthUpdateUsageDescription: "Stillmoon saves completed exercises to Apple Health as Mindful Minutes."
```
(A spike confirmed this builds, signs ad hoc and reports `.shouldRequest` on the iOS 26.3 simulator without a development team.)

- [ ] **Step 4: Implement the sources**

`App/Stillmoon/Health/HealthDataSource.swift`:
```swift
import Foundation
import StillmoonCore

enum HealthError: Error, Equatable {
    case unavailable
}

/// Where sleep estimates come from. Samples are read on demand and never stored by Stillmoon.
protocol HealthDataSource: AnyObject {
    var isAvailable: Bool { get }
    func requestAuthorization() async throws
    /// Samples overlapping [start, end), from every source.
    func sleepSamples(from start: Date, to end: Date) async throws -> [SleepSample]
    func saveMindfulSession(start: Date, end: Date) async throws
}

extension SleepStage {
    var title: String {
        switch self {
        case .inBed: "In bed"
        case .awake: "Awake"
        case .core: "Core"
        case .deep: "Deep"
        case .rem: "REM"
        case .asleepUnspecified: "Asleep"
        }
    }
}
```

`App/Stillmoon/Health/HealthKitService.swift`:
```swift
import Foundation
import HealthKit
import StillmoonCore

enum SleepStageMapping {
    static func stage(forHealthKitValue value: Int) -> SleepStage? {
        switch HKCategoryValueSleepAnalysis(rawValue: value) {
        case .inBed: .inBed
        case .awake: .awake
        case .asleepCore: .core
        case .asleepDeep: .deep
        case .asleepREM: .rem
        case .asleepUnspecified: .asleepUnspecified
        default: nil
        }
    }
}

final class HealthKitService: HealthDataSource {
    private let store = HKHealthStore()
    private let sleepType = HKCategoryType(.sleepAnalysis)
    private let mindfulType = HKCategoryType(.mindfulSession)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthError.unavailable }
        try await store.requestAuthorization(toShare: [mindfulType], read: [sleepType])
    }

    func sleepSamples(from start: Date, to end: Date) async throws -> [SleepSample] {
        guard isAvailable else { throw HealthError.unavailable }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)])
        let samples = try await descriptor.result(for: store)
        return samples.compactMap { sample in
            guard let stage = SleepStageMapping.stage(forHealthKitValue: sample.value) else { return nil }
            return SleepSample(stage: stage, start: sample.startDate, end: sample.endDate,
                               sourceName: sample.sourceRevision.source.name)
        }
    }

    func saveMindfulSession(start: Date, end: Date) async throws {
        guard isAvailable else { throw HealthError.unavailable }
        let sample = HKCategorySample(type: mindfulType, value: HKCategoryValue.notApplicable.rawValue,
                                      start: start, end: end)
        try await store.save(sample)
    }
}
```
If Swift 6 rejects passing `HKCategorySample` results across isolation, keep the query inside a `nonisolated` helper that maps to `[SleepSample]` (which is `Sendable`) before returning, and note it in the report.

`App/Stillmoon/Health/FakeHealthSource.swift`:
```swift
import Foundation
import StillmoonCore

/// In-memory Health for unit tests and for UI tests launched with `-fake-health`.
final class FakeHealthSource: HealthDataSource {
    var isAvailable = true
    var samples: [SleepSample]
    var failReads = false
    private(set) var authorizationRequested = false
    private(set) var mindfulSessions: [DateInterval] = []

    init(samples: [SleepSample] = []) {
        self.samples = samples
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthError.unavailable }
        authorizationRequested = true
    }

    func sleepSamples(from start: Date, to end: Date) async throws -> [SleepSample] {
        if failReads || !isAvailable { throw HealthError.unavailable }
        return samples.filter { $0.end > start && $0.start < end }
    }

    func saveMindfulSession(start: Date, end: Date) async throws {
        guard isAvailable else { throw HealthError.unavailable }
        mindfulSessions.append(DateInterval(start: start, end: end))
    }

    /// A staged night: 23:00 the evening before `morning` to 06:30 on it (7 h 20 m asleep).
    static func sampleNight(endingOn morning: Date, calendar: Calendar, source: String = "Apple Watch") -> [SleepSample] {
        let day = calendar.startOfDay(for: morning)
        let evening = calendar.date(byAdding: .day, value: -1, to: day)!
        func at(_ base: Date, _ h: Int, _ m: Int = 0) -> Date {
            calendar.date(bySettingHour: h, minute: m, second: 0, of: base)!
        }
        return [
            SleepSample(stage: .core, start: at(evening, 23), end: at(day, 1), sourceName: source),
            SleepSample(stage: .deep, start: at(day, 1), end: at(day, 2), sourceName: source),
            SleepSample(stage: .awake, start: at(day, 2), end: at(day, 2, 10), sourceName: source),
            SleepSample(stage: .rem, start: at(day, 2, 10), end: at(day, 3), sourceName: source),
            SleepSample(stage: .core, start: at(day, 3), end: at(day, 6, 30), sourceName: source),
        ]
    }
}
```

In `SettingsStore.swift`: add `var healthConnected = false` to `AppSettings`, add `healthConnected` to `CodingKeys`, and in `init(from:)` add `healthConnected = try c.decodeIfPresent(Bool.self, forKey: .healthConnected) ?? false` (use the same container variable name the file already uses).

In `AppEnvironment.swift`:
- add `let health: HealthDataSource`;
- change the initializer to `init(store: LocalStore, settings: SettingsStore, catalog: ContentCatalog, health: HealthDataSource = FakeHealthSource())` and assign it;
- in `live(arguments:)`, choose `let health: HealthDataSource = arguments.contains("-fake-health") ? FakeHealthSource(samples: FakeHealthSource.sampleNight(endingOn: .now, calendar: .current)) : HealthKitService()` and pass it;
- add:
```swift
    /// Asks for Health access. HealthKit never says whether read access was granted,
    /// so "connected" means the user went through the prompt.
    func connectHealth() async -> Bool {
        guard health.isAvailable else { return false }
        do {
            try await health.requestAuthorization()
            settings.settings.healthConnected = true
            return true
        } catch {
            return false
        }
    }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `scripts/test-app.sh -only-testing:StillmoonTests`
Expected: `HealthSourceTests` (6) pass; all earlier suites pass.

- [ ] **Step 6: Commit**

```bash
git add project.yml App
git commit -m "feat(health): HealthKit data source, fake source and connect flow"
```

---

### Task 2: Night history model

**Files:**
- Modify: `StillmoonCore/Sources/StillmoonCore/SleepReport.swift` (`NightReport` conforms to `Hashable` as well as `Equatable`; all its fields are Hashable) — run `cd StillmoonCore && swift test` after the change
- Modify (rewrite): `App/Stillmoon/Features/Sleep/SleepModel.swift`
- Modify: `App/Stillmoon/Features/Sleep/SleepView.swift` (call sites only: `model.rows` element type, async refresh/save/delete), `App/Stillmoon/Root/RootView.swift` (SleepModel init)
- Modify (rewrite): `App/StillmoonTests/SleepModelTests.swift`

**Interfaces:**
- Consumes: `HealthDataSource`, `FakeHealthSource.sampleNight`, `SettingsStore.settings.healthConnected`, Core `SleepReportBuilder`, `NightWindow`, `NightReport`.
- Produces:
  - `struct NightRow: Identifiable, Hashable { let morning: Date; let report: NightReport?; let entry: JournalEntry?; let checkIn: CheckIn?; var id: Date }`
  - `@Observable final class SleepModel { static let historyDays = 14; init(store:health:settings:now:calendar:); rows: [NightRow]; healthError: Bool; isHealthConnected: Bool; refresh() async; save(_:) async; deleteEntry(of:) async }`

- [ ] **Step 1: Write the failing tests**

Replace `App/StillmoonTests/SleepModelTests.swift`:
```swift
import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct SleepModelTests {
    let now = TestEnv.d(2026, 10, 2, 9)

    func make(connected: Bool = true, samples: [SleepSample]? = nil) throws -> (SleepModel, LocalStore, FakeHealthSource) {
        let store = try TestEnv.store()
        let settings = TestEnv.settings()
        settings.settings.healthConnected = connected
        let health = FakeHealthSource(samples: samples ?? FakeHealthSource.sampleNight(endingOn: now, calendar: TestEnv.cal))
        let model = SleepModel(store: store, health: health, settings: settings, now: { now }, calendar: TestEnv.cal)
        return (model, store, health)
    }

    func entry(_ day: Int) -> JournalEntry {
        JournalEntry(bedtime: TestEnv.d(2026, 10, day - 1, 23), wakeTime: TestEnv.d(2026, 10, day, 7))
    }

    @Test func healthNightBecomesARow() async throws {
        let (m, _, _) = try make()
        await m.refresh()
        #expect(m.rows.count == 1)
        #expect(m.rows[0].morning == TestEnv.d(2026, 10, 2))
        #expect(m.rows[0].report?.estimatedAsleep == 7 * 3600 + 20 * 60)
        #expect(m.rows[0].entry == nil)
    }

    @Test func journalAndHealthMergeIntoOneRow() async throws {
        let (m, store, _) = try make()
        store.saveJournalEntry(entry(2))
        store.saveJournalEntry(entry(1))
        store.saveCheckIn(CheckIn(date: TestEnv.d(2026, 10, 2, 8), restedness: 4))
        await m.refresh()
        #expect(m.rows.map(\.morning) == [TestEnv.d(2026, 10, 2), TestEnv.d(2026, 10, 1)])
        #expect(m.rows[0].report != nil)
        #expect(m.rows[0].entry != nil)
        #expect(m.rows[0].checkIn?.restedness == 4)
        #expect(m.rows[1].report == nil)
        #expect(m.rows[1].entry != nil)
    }

    @Test func notConnectedShowsNoReports() async throws {
        let (m, store, _) = try make(connected: false)
        store.saveJournalEntry(entry(2))
        await m.refresh()
        #expect(m.rows.count == 1)
        #expect(m.rows[0].report == nil)
        #expect(!m.isHealthConnected)
        #expect(!m.healthError)
    }

    @Test func readFailureKeepsJournalRows() async throws {
        let (m, store, health) = try make()
        health.failReads = true
        store.saveJournalEntry(entry(2))
        await m.refresh()
        #expect(m.healthError)
        #expect(m.rows.count == 1)
        #expect(m.rows[0].entry != nil)
        #expect(m.rows[0].report == nil)
    }

    @Test func deletingRemovesOnlyTheJournalEntry() async throws {
        let (m, store, _) = try make()
        store.saveJournalEntry(entry(2))
        await m.refresh()
        await m.deleteEntry(of: m.rows[0])
        #expect(store.journalEntries().isEmpty)
        #expect(m.rows.count == 1)
        #expect(m.rows[0].report != nil)
    }

    @Test func historyIsLimitedToFourteenNights() async throws {
        let old = FakeHealthSource.sampleNight(endingOn: TestEnv.d(2026, 9, 1, 9), calendar: TestEnv.cal)
        let recent = FakeHealthSource.sampleNight(endingOn: now, calendar: TestEnv.cal)
        let (m, _, _) = try make(samples: old + recent)
        await m.refresh()
        #expect(m.rows.map(\.morning) == [TestEnv.d(2026, 10, 2)])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/SleepModelTests`
Expected: build FAILS ("extra argument 'health' in call" or similar).

- [ ] **Step 3: Rewrite the model**

`App/Stillmoon/Features/Sleep/SleepModel.swift`:
```swift
import Foundation
import Observation
import StillmoonCore

/// One morning: what a device estimated (report), what the user recorded (entry) and how they felt (checkIn).
struct NightRow: Identifiable, Hashable {
    let morning: Date
    let report: NightReport?
    let entry: JournalEntry?
    let checkIn: CheckIn?
    var id: Date { morning }
}

@Observable final class SleepModel {
    static let historyDays = 14

    @ObservationIgnored private let store: LocalStore
    @ObservationIgnored private let health: HealthDataSource
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let calendar: Calendar

    private(set) var rows: [NightRow] = []
    private(set) var healthError = false

    init(store: LocalStore, health: HealthDataSource, settings: SettingsStore,
         now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.store = store
        self.health = health
        self.settings = settings
        self.clock = now
        self.calendar = calendar
    }

    var isHealthConnected: Bool { settings.settings.healthConnected }

    func refresh() async {
        let now = clock()
        let today = calendar.startOfDay(for: now)
        var reports: [Date: NightReport] = [:]
        healthError = false

        if isHealthConnected {
            let oldestMorning = calendar.date(byAdding: .day, value: -(Self.historyDays - 1), to: today)!
            let from = NightWindow.forMorning(of: oldestMorning, calendar: calendar).start
            do {
                let samples = try await health.sleepSamples(from: from, to: now)
                for offset in 0..<Self.historyDays {
                    let morning = calendar.date(byAdding: .day, value: -offset, to: today)!
                    let window = NightWindow.forMorning(of: morning, calendar: calendar)
                    if let report = SleepReportBuilder.build(samples: samples, window: window) {
                        reports[morning] = report
                    }
                }
            } catch {
                healthError = true
            }
        }

        let entriesByMorning = Dictionary(grouping: store.journalEntries()) { calendar.startOfDay(for: $0.wakeTime) }
        let checkIns = store.checkIns()
        let mornings = Set(reports.keys).union(entriesByMorning.keys)
        rows = mornings.sorted(by: >).map { morning in
            NightRow(morning: morning,
                     report: reports[morning],
                     entry: entriesByMorning[morning]?.first,
                     checkIn: checkIns.first { calendar.isDate($0.date, inSameDayAs: morning) })
        }
    }

    func save(_ entry: JournalEntry) async {
        store.saveJournalEntry(entry)
        await refresh()
    }

    /// Health data is managed in the Health app; only the user's own entry is deleted here.
    func deleteEntry(of row: NightRow) async {
        if let entry = row.entry { store.deleteJournalEntry(id: entry.id) }
        await refresh()
    }
}
```

- [ ] **Step 4: Keep the app compiling**

In `SleepView.swift`: replace `.onAppear { model.refresh() }` with `.task { await model.refresh() }`; the sheet's save becomes `JournalEntryForm { entry in Task { await model.save(entry) } }`; `.onDelete` becomes:
```swift
            .onDelete { offsets in
                let rows = offsets.map { model.rows[$0] }
                Task { for row in rows { await model.deleteEntry(of: row) } }
            }
```
and add `.deleteDisabled(row.entry == nil)` on each row. `NightRowView` keeps compiling by reading `row.entry` optionally — for this task, make its body show the entry lines only `if let entry = row.entry` (Task 3 redesigns the row).
In `RootView.swift` `MainTabs.init`: `SleepModel(store: env.store, health: env.health, settings: env.settings)`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `scripts/test-app.sh -only-testing:StillmoonTests`
Expected: `SleepModelTests` (6) pass; all other suites pass.

- [ ] **Step 6: Commit**

```bash
git add App
git commit -m "feat(health): night history merges Health reports with journal entries"
```

---

### Task 3: Sleep tab rows and night detail

**Files:**
- Create: `App/Stillmoon/Features/Sleep/NightDetailView.swift`
- Modify: `App/Stillmoon/Features/Sleep/SleepView.swift`
- Test: `App/StillmoonTests/NightDetailTests.swift`

**Interfaces:**
- Consumes: `NightRow`, `NightReport`, `SleepStage.title`, `Format.duration`, `Theme`, `Card`.
- Produces: `enum NightSummary { static let stageOrder: [SleepStage]; static func stageRows(_ report: NightReport) -> [(stage: SleepStage, seconds: TimeInterval)]; static func estimateLine(_ report: NightReport) -> String; static func gapLine(_ gap: DateInterval) -> String }`, `NightDetailView(row:)`, `StageChart(timeline:)`.

- [ ] **Step 1: Write the failing tests**

`App/StillmoonTests/NightDetailTests.swift`:
```swift
import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct NightDetailTests {
    let morning = TestEnv.d(2026, 10, 2, 9)

    func report(source: String = "Apple Watch", samples: [SleepSample]? = nil) -> NightReport {
        SleepReportBuilder.build(samples: samples ?? FakeHealthSource.sampleNight(endingOn: morning, calendar: TestEnv.cal, source: source),
                                 window: NightWindow.forMorning(of: morning, calendar: TestEnv.cal))!
    }

    @Test func stageRowsInDisplayOrder() {
        let rows = NightSummary.stageRows(report())
        #expect(rows.map(\.stage) == [.awake, .rem, .core, .deep])
        #expect(rows.first { $0.stage == .deep }?.seconds == 3600)
    }

    @Test func stageRowsEmptyWithoutDetail() {
        let phone = [SleepSample(stage: .asleepUnspecified, start: TestEnv.d(2026, 10, 1, 23), end: TestEnv.d(2026, 10, 2, 7), sourceName: "iPhone")]
        #expect(NightSummary.stageRows(report(samples: phone)).isEmpty)
        #expect(NightSummary.estimateLine(report(samples: phone)) == "iPhone estimated 8 h asleep")
    }

    @Test func estimateLineNamesTheSource() {
        #expect(NightSummary.estimateLine(report()) == "Apple Watch estimated 7 h 20 m asleep")
    }

    @Test func gapLineIsPlain() {
        let gap = DateInterval(start: TestEnv.d(2026, 10, 2, 1), end: TestEnv.d(2026, 10, 2, 2))
        let line = NightSummary.gapLine(gap)
        #expect(line.hasPrefix("No data from "))
        #expect(!line.contains("error"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/NightDetailTests`
Expected: build FAILS with "cannot find 'NightSummary' in scope".

- [ ] **Step 3: Implement the detail view**

`App/Stillmoon/Features/Sleep/NightDetailView.swift`:
```swift
import Charts
import SwiftUI
import StillmoonCore

enum NightSummary {
    /// Top to bottom on the chart and in the list.
    static let stageOrder: [SleepStage] = [.awake, .rem, .core, .deep]

    /// Stage durations, only when the source recorded stages.
    static func stageRows(_ report: NightReport) -> [(stage: SleepStage, seconds: TimeInterval)] {
        guard report.hasStageDetail else { return [] }
        return stageOrder.compactMap { stage in
            report.stageDurations[stage].map { (stage, $0) }
        }
    }

    static func estimateLine(_ report: NightReport) -> String {
        "\(report.primarySource) estimated \(Format.duration(minutes: Int(report.estimatedAsleep / 60))) asleep"
    }

    static func gapLine(_ gap: DateInterval) -> String {
        "No data from \(gap.start.formatted(date: .omitted, time: .shortened)) to \(gap.end.formatted(date: .omitted, time: .shortened))."
    }
}

struct NightDetailView: View {
    @Environment(\.theme) private var theme
    let row: NightRow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(row.morning, format: .dateTime.weekday(.wide).month().day())
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                if let report = row.report {
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("What your device estimated").font(.headline)
                            Text(NightSummary.estimateLine(report)).font(.title3)
                            Text("\(report.sleepStart.formatted(date: .omitted, time: .shortened)) to \(report.sleepEnd.formatted(date: .omitted, time: .shortened))")
                                .foregroundStyle(theme.secondaryText)
                            if report.hasStageDetail {
                                StageChart(timeline: report.timeline)
                                ForEach(NightSummary.stageRows(report), id: \.stage) { item in
                                    HStack {
                                        Text(item.stage.title)
                                        Spacer()
                                        Text(Format.duration(minutes: Int(item.seconds / 60)))
                                            .foregroundStyle(theme.secondaryText)
                                    }
                                }
                                Text("Stages are estimates from your device, not measurements.")
                                    .font(.footnote)
                                    .foregroundStyle(theme.secondaryText)
                            } else {
                                Text("\(report.primarySource) recorded time asleep without stages.")
                                    .font(.footnote)
                                    .foregroundStyle(theme.secondaryText)
                            }
                            ForEach(report.gaps, id: \.self) { gap in
                                Text(NightSummary.gapLine(gap))
                                    .font(.footnote)
                                    .foregroundStyle(theme.secondaryText)
                            }
                            if report.allSources.count > 1 {
                                Text("Also recorded by: \(report.allSources.dropFirst().joined(separator: ", "))")
                                    .font(.footnote)
                                    .foregroundStyle(theme.secondaryText)
                            }
                        }
                    }
                }
                if let entry = row.entry {
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("You recorded").font(.headline)
                            Text("\(entry.bedtime.formatted(date: .omitted, time: .shortened)) to \(entry.wakeTime.formatted(date: .omitted, time: .shortened)), \(Format.duration(minutes: entry.inBedMinutes)) in bed")
                            if let note = entry.note, !note.isEmpty {
                                Text(note).foregroundStyle(theme.secondaryText)
                            }
                        }
                    }
                }
                if let checkIn = row.checkIn {
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("You felt \(checkIn.restedness) of 5 rested").font(.headline)
                            if checkIn.tenseAtBedtime { Text("You felt tense at bedtime") }
                            if checkIn.wokeDuringNight { Text("You were awake during the night") }
                        }
                    }
                }
            }
            .foregroundStyle(theme.text)
            .padding()
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Night")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Stage timeline: one bar per sample, stages as rows.
struct StageChart: View {
    @Environment(\.theme) private var theme
    let timeline: [SleepSample]

    var body: some View {
        let staged = timeline.filter { NightSummary.stageOrder.contains($0.stage) }
        Chart(staged, id: \.self) { sample in
            BarMark(xStart: .value("Start", sample.start),
                    xEnd: .value("End", sample.end),
                    y: .value("Stage", sample.stage.title))
                .foregroundStyle(theme.accent)
        }
        .chartYScale(domain: NightSummary.stageOrder.map(\.title))
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .frame(height: 160)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sleep stage timeline")
        .accessibilityValue("Estimated stages from \(staged.first?.sourceName ?? "your device"), listed below")
    }
}
```

- [ ] **Step 4: Update the list rows**

In `SleepView.swift`, wrap each row in navigation and redesign `NightRowView` (keep the combined accessibility element from Plan 2):
```swift
            ForEach(model.rows) { row in
                NavigationLink(value: row) {
                    NightRowView(row: row)
                }
                .listRowBackground(theme.surface)
                .deleteDisabled(row.entry == nil)
            }
```
add `.navigationDestination(for: NightRow.self) { NightDetailView(row: $0) }` on the List, and above the rows:
```swift
            if !model.isHealthConnected {
                Text("Connect Apple Health in Settings to see estimates from your watch or other devices.")
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryText)
                    .listRowBackground(Color.clear)
            } else if model.healthError {
                Text("Apple Health couldn't be read right now. Your own entries are below.")
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryText)
                    .listRowBackground(Color.clear)
            }
```
`NightRowView` body:
```swift
        VStack(alignment: .leading, spacing: 6) {
            Text(row.morning, format: .dateTime.weekday(.wide).month().day())
                .font(.headline)
            if let report = row.report {
                Text(NightSummary.estimateLine(report))
                    .font(.subheadline)
            }
            if let entry = row.entry {
                Text("You recorded \(Format.duration(minutes: entry.inBedMinutes)) in bed")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }
            if let checkIn = row.checkIn {
                Text("You felt \(checkIn.restedness) of 5 rested")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .foregroundStyle(theme.text)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
```
Update the empty-state text to "Add a night with the + button, or connect Apple Health in Settings."

- [ ] **Step 5: Run tests to verify they pass**

Run: `scripts/test-app.sh -only-testing:StillmoonTests`
Expected: `NightDetailTests` (4) pass; all other suites pass.

- [ ] **Step 6: Commit**

```bash
git add App
git commit -m "feat(health): nightly report detail with stage timeline and source labels"
```

---

### Task 4: Today uses Health

**Files:**
- Modify: `App/Stillmoon/Features/Today/TodayModel.swift`, `App/Stillmoon/Features/Today/TodayView.swift`, `App/Stillmoon/Root/RootView.swift`
- Modify: `App/StillmoonTests/TodayModelTests.swift` (construction helper gains `health`; add tests)

**Interfaces:**
- Consumes: `HealthDataSource`, `FakeHealthSource`, `NightSummary.estimateLine`, Core `SleepReportBuilder`, `NightWindow.nightKey`.
- Produces: `TodayModel.init(store:settings:catalog:health:now:calendar:)` (`health` defaults to `FakeHealthSource()` so existing call sites keep compiling only if you choose; MainTabs passes `env.health`), `lastNightReport: NightReport?`, `refreshHealth() async`, `static func combinedBedtimes(journal: [Date], health: [Date], calendar: Calendar) -> [Date]`.

- [ ] **Step 1: Write the failing tests**

In `App/StillmoonTests/TodayModelTests.swift`, change `make(goal:)` to also accept `connected: Bool = false` and `samples: [SleepSample] = []`, create `let health = FakeHealthSource(samples: samples)`, set `settings.settings.healthConnected = connected`, and pass `health: health` to `TodayModel`. Then add:
```swift
    @Test func lastNightReportWhenConnected() async throws {
        let (m, _) = try make(connected: true, samples: FakeHealthSource.sampleNight(endingOn: now, calendar: TestEnv.cal))
        await m.refreshHealth()
        #expect(m.lastNightReport?.primarySource == "Apple Watch")
    }

    @Test func noReportWhenNotConnected() async throws {
        let (m, _) = try make(connected: false, samples: FakeHealthSource.sampleNight(endingOn: now, calendar: TestEnv.cal))
        await m.refreshHealth()
        #expect(m.lastNightReport == nil)
    }

    @Test func variedHealthBedtimesSuggestRoutine() async throws {
        // Four nights, bed at 22:00, 23:45, 00:30 and 22:15 (spread 150 min); now is 2026-10-02 09:00.
        let starts = [TestEnv.d(2026, 9, 28, 22), TestEnv.d(2026, 9, 29, 23, 45),
                      TestEnv.d(2026, 10, 1, 0, 30), TestEnv.d(2026, 10, 1, 22, 15)]
        let samples = starts.map { SleepSample(stage: .core, start: $0, end: $0.addingTimeInterval(7 * 3600), sourceName: "Apple Watch") }
        let (m, _) = try make(goal: .understandSleep, connected: true, samples: samples)
        await m.refreshHealth()
        #expect(m.recommendations.first?.reason == "Your recorded bedtimes varied this week.")
    }

    @Test func healthAndJournalBedtimesDedupedPerNight() {
        let journal = [TestEnv.d(2026, 10, 1, 23)]
        let health = [TestEnv.d(2026, 10, 1, 23, 20), TestEnv.d(2026, 9, 30, 22)]
        let combined = TodayModel.combinedBedtimes(journal: journal, health: health, calendar: TestEnv.cal)
        #expect(combined.sorted() == [TestEnv.d(2026, 9, 30, 22), TestEnv.d(2026, 10, 1, 23, 20)])
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/TodayModelTests`
Expected: build FAILS ("extra argument 'health'" / "no member 'refreshHealth'").

- [ ] **Step 3: Implement**

In `TodayModel`:
- add `@ObservationIgnored private let health: HealthDataSource`, init parameter `health: HealthDataSource = FakeHealthSource()` (after `catalog:`), stored;
- add `private(set) var lastNightReport: NightReport?` and `@ObservationIgnored private var healthBedtimes: [Date] = []`;
- add:
```swift
    /// Bedtimes for recommendations: one per night, a Health estimate replacing the journal entry for the same night.
    static func combinedBedtimes(journal: [Date], health: [Date], calendar: Calendar) -> [Date] {
        var byNight: [Date: Date] = [:]
        for bedtime in journal { byNight[NightWindow.nightKey(for: bedtime, calendar: calendar)] = bedtime }
        for bedtime in health { byNight[NightWindow.nightKey(for: bedtime, calendar: calendar)] = bedtime }
        return Array(byNight.values)
    }

    /// Reads the last 7 nights from Health (when connected), then recomputes everything.
    func refreshHealth() async {
        let now = clock()
        lastNightReport = nil
        healthBedtimes = []
        if settings.settings.healthConnected {
            let today = calendar.startOfDay(for: now)
            let oldest = calendar.date(byAdding: .day, value: -6, to: today)!
            if let samples = try? await health.sleepSamples(from: NightWindow.forMorning(of: oldest, calendar: calendar).start, to: now) {
                for offset in 0..<7 {
                    let morning = calendar.date(byAdding: .day, value: -offset, to: today)!
                    guard let report = SleepReportBuilder.build(samples: samples, window: NightWindow.forMorning(of: morning, calendar: calendar)) else { continue }
                    if offset == 0 { lastNightReport = report }
                    healthBedtimes.append(report.sleepStart)
                }
            }
        }
        refresh()
    }
```
- in `refresh()`, build `recentBedtimes` with `Self.combinedBedtimes(journal: <journal bedtimes in the last 7 days>, health: healthBedtimes, calendar: calendar).filter { $0 >= weekAgo && $0 <= now }`.

In `TodayView`:
- replace `.onAppear { model.refresh() }` with `.task { await model.refreshHealth() }`; in the scenePhase `.active` handler call `Task { await model.refreshHealth() }`; sheet `onDismiss` handlers may keep `model.refresh`.
- `lastNightCard`: if `model.lastNightReport` is set, show `Text(NightSummary.estimateLine(report)).font(.title3)` and the `sleepStart`–`sleepEnd` line; then, if `model.lastNight` (journal) is also set, a secondary line `"You recorded \(Format.duration(minutes: entry.inBedMinutes)) in bed"`; if neither, keep the existing "Nothing recorded…" + "Add last night".

In `RootView.swift` `MainTabs.init`: pass `health: env.health` to `TodayModel`; in the player cover's `onDismiss`, call `Task { await today.refreshHealth() }` instead of `today.refresh()`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `scripts/test-app.sh -only-testing:StillmoonTests`
Expected: all `TodayModelTests` (existing + 4 new) pass; all other suites pass.

- [ ] **Step 5: Commit**

```bash
git add App
git commit -m "feat(health): Today shows last night's estimate and uses Health bedtimes"
```

---

### Task 5: Mindful Minutes, onboarding and Settings

**Files:**
- Modify: `App/Stillmoon/Features/Exercises/PlayerModel.swift`, `PlayerView.swift`, `App/Stillmoon/Root/RootView.swift`, `App/Stillmoon/Features/Onboarding/OnboardingModel.swift`, `OnboardingView.swift`, `App/Stillmoon/Features/Settings/SettingsView.swift`
- Modify tests: `App/StillmoonTests/PlayerModelTests.swift`, `App/StillmoonTests/OnboardingModelTests.swift`, `App/StillmoonUITests/LaunchTests.swift`

**Interfaces:**
- Consumes: `AppEnvironment.connectHealth()`, `AppEnvironment.health`, `SettingsStore.settings.healthConnected`.
- Produces: `PlayerModel.init(exercise:store:now:onFinish: ((DateInterval) -> Void)? = nil)`, `PlayerModel.startedAt: Date?`; `PlayerView.init(exercise:store:onFinish:)`; `OnboardingModel.Step` gains `.health` between `.schedule` and `.privacy`.

- [ ] **Step 1: Write the failing tests**

Add to `App/StillmoonTests/PlayerModelTests.swift`:
```swift
    @Test func onFinishCalledOnceWithInterval() throws {
        var finished: [DateInterval] = []
        var clock = TestEnv.d(2026, 10, 2, 22)
        let m = PlayerModel(exercise: TestEnv.catalog.exercises[0], store: try TestEnv.store(),
                            now: { clock }, onFinish: { finished.append($0) })
        m.play()
        clock = TestEnv.d(2026, 10, 2, 22, 5)
        m.skipStep()
        m.skipStep()
        m.finish()
        #expect(finished == [DateInterval(start: TestEnv.d(2026, 10, 2, 22), end: TestEnv.d(2026, 10, 2, 22, 5))])
    }

    @Test func onFinishNotCalledWhenEndedEarly() throws {
        var calls = 0
        let m = PlayerModel(exercise: TestEnv.catalog.exercises[0], store: try TestEnv.store(),
                            now: { TestEnv.d(2026, 10, 2, 22) }, onFinish: { _ in calls += 1 })
        m.play()
        m.tick()
        m.pause()
        #expect(calls == 0)
    }
```
In `App/StillmoonTests/OnboardingModelTests.swift`, update `fullPathSavesGoalAndSchedule` so that after the schedule `next()` it expects `.health`, then calls `m.next()` and expects `.privacy`; update `skippingScheduleLeavesDefaults` to expect `.health` after `skipSchedule()`; `backMovesOneStepAndStopsAtWelcome` is unchanged.

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test-app.sh -only-testing:StillmoonTests`
Expected: build FAILS ("extra argument 'onFinish'") / onboarding expectations fail.

- [ ] **Step 3: Implement the player change**

In `PlayerModel`: add `@ObservationIgnored private let onFinish: ((DateInterval) -> Void)?` and `private(set) var startedAt: Date?`; init gains `onFinish: ((DateInterval) -> Void)? = nil`; `play()` sets `if startedAt == nil { startedAt = now() }` before `isPlaying = true`; `finish()` after recording the completion:
```swift
        let end = now()
        let start = startedAt ?? end.addingTimeInterval(-Double(exercise.durationSeconds))
        onFinish?(DateInterval(start: min(start, end), end: end))
```
`PlayerView.init(exercise:store:onFinish: ((DateInterval) -> Void)? = nil)` passes it through. In `MainTabs`' cover:
```swift
                PlayerView(exercise: exercise, store: env.store) { interval in
                    guard env.settings.settings.healthConnected else { return }
                    Task { try? await env.health.saveMindfulSession(start: interval.start, end: interval.end) }
                }
```

- [ ] **Step 4: Onboarding step and Settings section**

`OnboardingModel.Step`: `case welcome, goal, schedule, health, privacy, firstExercise`.
`OnboardingView` gains:
```swift
            case .health:
                Text("Add your watch's estimates?").font(.title.weight(.semibold))
                Text("Stillmoon can read sleep from Apple Health and save finished exercises as Mindful Minutes. Your sleep data stays on this iPhone.")
                    .foregroundStyle(theme.secondaryText)
                primary("Connect Apple Health") {
                    Task {
                        _ = await env.connectHealth()
                        model.next()
                    }
                }
                Button("Not now") { model.next() }
```
`SettingsView` gains a section after "Your goal":
```swift
                Section {
                    if env.settings.settings.healthConnected {
                        LabeledContent("Apple Health", value: "Connected")
                        Button("Stop reading Apple Health") { env.settings.settings.healthConnected = false }
                    } else {
                        Button("Connect Apple Health") { Task { _ = await env.connectHealth() } }
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("To change what Stillmoon can read or write, open the Health app, then Sharing, Apps, Stillmoon.")
                }
```

- [ ] **Step 5: UI tests**

In `LaunchTests.swift`, both existing tests add `app.buttons["Not now"].tap()` after "Skip for now" (the new health step). Add:
```swift
    @MainActor
    func testFakeHealthNightShowsEstimateAndDetail() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-fake-health"]
        app.launch()

        app.buttons["Get started"].tap()
        app.buttons["Unwind before bed"].tap()
        app.buttons["Skip for now"].tap()
        app.buttons["Connect Apple Health"].tap()
        app.buttons["Continue"].tap()
        app.buttons["Go to Today"].tap()

        app.tabBars.buttons["Sleep"].tap()
        let estimate = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Apple Watch estimated")).firstMatch
        XCTAssertTrue(estimate.waitForExistence(timeout: 5))
        estimate.tap()
        XCTAssertTrue(app.staticTexts["Stages are estimates from your device, not measurements."].waitForExistence(timeout: 5))
    }
```
(Rows combine accessibility children; if `staticTexts` doesn't match the combined row, query `app.buttons` with the same predicate and say so in the report.)

- [ ] **Step 6: Run everything**

Run: `scripts/test-app.sh`
Expected: all unit suites pass (2 new PlayerModel tests); all 3 UI tests pass; `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add App
git commit -m "feat(health): Mindful Minutes on finish, Health step in onboarding and Settings"
```
