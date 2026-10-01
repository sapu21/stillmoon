# Stillmoon App Shell Implementation Plan (Plan 2 of 7)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A runnable SwiftUI iPhone app with onboarding, four tabs (Today, Sleep, Exercises, Journey), a manual sleep journal and morning check-in, an exercise library with a dim exercise player, articles, on-device recommendations, weekly progress, settings, and day/night theming, all on local SwiftData storage.

**Architecture:** An XcodeGen-generated Xcode project (`project.yml`) with an app target that depends on the local `StillmoonCore` package from Plan 1. The app target defaults to main-actor isolation. Each screen has an `@Observable` model with injected `LocalStore`, `SettingsStore`, `ContentCatalog`, clock and calendar, so the logic is unit-tested with Swift Testing on an in-memory SwiftData container. Views are thin. One `AppEnvironment` object is passed through the SwiftUI environment.

**Tech Stack:** Swift 6.2, SwiftUI, SwiftData, Observation, Swift Testing (unit), XCTest (one UI smoke test), XcodeGen 2.46, iOS 17.0 deployment target, iOS 26.3 Simulator (iPhone 17 Pro).

**Spec:** `docs/PRD-v1.2.md`. Core logic API: `StillmoonCore/Sources/StillmoonCore/*.swift` (Plan 1, merged).

## Global Constraints

- Deployment target iOS 17.0; iPhone only (`TARGETED_DEVICE_FAMILY: "1"`); portrait.
- App and unit-test targets: `SWIFT_VERSION: "6.0"`, `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor`. UI-test target: default isolation.
- No third-party dependencies. The only package dependency is the local `StillmoonCore`.
- Every test file starts with `import Foundation` (the test target does not get it implicitly).
- `Stillmoon.xcodeproj` is generated and git-ignored; `project.yml` is the source of truth.
- SwiftData models must stay CloudKit-compatible for Plan 7: every stored property has a default value or is optional, no `@Attribute(.unique)`, no required relationships. `ModelConfiguration` uses `cloudKitDatabase: .none` in this plan.
- Every local record stores `ownerID: String`; all fetches filter by the store's `ownerID`. Until Plan 5 the owner is `LocalOwner.id = "local"`.
- Copy rules (PRD §1, §14): never "bad sleep", never claims about anxiety or disorders; user-entered data is labelled "You recorded…" / "You felt…"; reasons come from `RecommendationEngine.Reason` verbatim.
- Night interaction (PRD §2, §7): night theme is low-brightness navy/plum, minimal text, large controls, no celebratory animation. The exercise player always uses the night theme.
- Night mode: `SettingsStore.isNight(at:calendar:sessionActive:)` wraps `NightModeResolver`; the UI re-evaluates every 60 seconds.
- Day palette hex: background `FAF7F2`, surface `FFFFFF`, text `1E1B2E`, secondary text `5C5870`, accent (lavender) `8E7CC3`, accent2 (coral) `E8907E`. Night palette: background `12142B`, surface `2A2140`, text `D9D4EE`, secondary text `9A93B8`, accent `A99BE0`, accent2 `C98B80`.
- Unit test command: `scripts/test-app.sh -only-testing:StillmoonTests` (or `-only-testing:StillmoonTests/<SuiteName>`). Full command including UI test: `scripts/test-app.sh`.

## Review Focus

1. **Owner isolation:** records written by one owner must never appear for another (Plan 5 adds real accounts on a shared phone). Pinned in Task 2 (`ownersAreIsolated`, `deleteAllOnlyRemovesOwnersData`).
2. **Check-in twice on one day** must update, not duplicate, and recommendations must follow the latest answers. Pinned in Task 8 (`secondCheckInSameDayUpdates`).
3. **Impossible journal entries** (wake before bed, more than 16 h): Save stays disabled with a plain message. Pinned in Task 2 (`JournalEntryTests`).
4. **Ending an exercise early** must not count as a completion; finishing must count exactly once. Pinned in Task 6 (`endingEarlyRecordsNothing`, `finishRecordsOnce`).
5. **Night-mode boundary** at bedtime − 1 h and the manual override: pinned in Task 3 (`nightModeFollowsScheduleAndOverride`).

---

## File Structure

```
project.yml                                  # XcodeGen spec (Task 1)
scripts/test-app.sh                          # generate + xcodebuild test (Task 1)
App/Stillmoon/
  StillmoonApp.swift                         # @main (Task 1, replaced Task 9)
  Persistence/Records.swift                  # SwiftData @Model records (Task 2)
  Persistence/LocalStore.swift               # owner-scoped repository + schema (Task 2)
  Persistence/JournalEntry.swift             # manual journal value type (Task 2)
  Settings/SettingsStore.swift               # AppSettings + store (Task 3)
  Design/Theme.swift                         # palettes, Color(hex:), Card, theme env (Task 3)
  Design/Format.swift                        # duration/clock text, display names (Task 3)
  Content/Content.swift                      # Exercise, Article, ContentCatalog, ContentStore (Task 4)
  Content/AppEnvironment.swift               # shared app object (Task 4)
  Resources/catalog.json                     # launch content placeholder set (Task 4)
  Features/Sleep/SleepModel.swift            # (Task 5)
  Features/Sleep/SleepView.swift             # list + NightRowView (Task 5)
  Features/Sleep/JournalEntryForm.swift      # (Task 5)
  Features/Sleep/CheckInSheet.swift          # (Task 5)
  Features/Exercises/ExercisesModel.swift    # (Task 6)
  Features/Exercises/PlayerModel.swift       # (Task 6)
  Features/Exercises/Route.swift             # Route + RouteDestination (Task 6)
  Features/Exercises/ExercisesView.swift     # library list + rows (Task 6)
  Features/Exercises/ExerciseDetailView.swift# (Task 6)
  Features/Exercises/ArticleView.swift       # (Task 6)
  Features/Exercises/PlayerView.swift        # (Task 6)
  Features/Journey/JourneyModel.swift        # (Task 7)
  Features/Journey/JourneyView.swift         # (Task 7)
  Features/Settings/SettingsView.swift       # (Task 7)
  Features/Today/TodayModel.swift            # (Task 8)
  Features/Today/TodayView.swift             # (Task 8)
  Features/Onboarding/OnboardingModel.swift  # (Task 9)
  Features/Onboarding/OnboardingView.swift   # (Task 9)
  Root/RootView.swift                        # RootView + MainTabs (Task 9)
App/StillmoonTests/
  TestEnv.swift                              # shared fixtures (Task 2, extended Task 4)
  SmokeTests.swift, LocalStoreTests.swift, JournalEntryTests.swift, SettingsTests.swift,
  FormatTests.swift, ContentTests.swift, SleepModelTests.swift, ExercisesModelTests.swift,
  PlayerModelTests.swift, JourneyModelTests.swift, TodayModelTests.swift, OnboardingModelTests.swift
App/StillmoonUITests/LaunchTests.swift       # (Task 1, extended Task 9)
```

All commands run from `~/stillmoon`.

---

### Task 1: Project scaffold

**Files:**
- Create: `project.yml`, `scripts/test-app.sh`, `App/Stillmoon/StillmoonApp.swift`, `App/StillmoonTests/SmokeTests.swift`, `App/StillmoonUITests/LaunchTests.swift`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: `StillmoonCore` package at `StillmoonCore/` (`NightModeResolver.defaultBedtime`).
- Produces: targets `Stillmoon`, `StillmoonTests`, `StillmoonUITests`; scheme `Stillmoon`; `scripts/test-app.sh [xcodebuild args…]`.

- [ ] **Step 1: Write the project spec**

`project.yml`:
```yaml
name: Stillmoon
options:
  bundleIdPrefix: app.stillmoon
  deploymentTarget:
    iOS: "17.0"
  createIntermediateGroups: true
packages:
  StillmoonCore:
    path: StillmoonCore
settings:
  base:
    SWIFT_VERSION: "6.0"
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
targets:
  Stillmoon:
    type: application
    platform: iOS
    sources:
      - path: App/Stillmoon
    dependencies:
      - package: StillmoonCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: app.stillmoon.ios
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: Stillmoon
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES
        INFOPLIST_KEY_UISupportedInterfaceOrientations: UIInterfaceOrientationPortrait
        TARGETED_DEVICE_FAMILY: "1"
        SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor
  StillmoonTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: App/StillmoonTests
    dependencies:
      - target: Stillmoon
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor
  StillmoonUITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - path: App/StillmoonUITests
    dependencies:
      - target: Stillmoon
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
schemes:
  Stillmoon:
    build:
      targets:
        Stillmoon: all
    test:
      targets:
        - StillmoonTests
        - StillmoonUITests
```

`scripts/test-app.sh`:
```bash
#!/bin/bash
# Regenerates the Xcode project and runs tests on the iPhone 17 Pro simulator.
# Extra arguments go to xcodebuild, e.g. -only-testing:StillmoonTests/LocalStoreTests
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate --quiet
set +e
xcodebuild test -project Stillmoon.xcodeproj -scheme Stillmoon \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' "$@" 2>&1 \
  | tee /tmp/stillmoon-test.log \
  | grep -E 'error:|✘|✔ Test run|Test Suite .*(passed|failed)|Executed [0-9]+ test|\*\* TEST (SUCCEEDED|FAILED) \*\*'
status=${PIPESTATUS[0]}
exit $status
```
Run `chmod +x scripts/test-app.sh`.

Append to `.gitignore`:
```
Stillmoon.xcodeproj/
*.xcresult
```

- [ ] **Step 2: Minimal app and tests**

`App/Stillmoon/StillmoonApp.swift`:
```swift
import SwiftUI

@main
struct StillmoonApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Stillmoon")
        }
    }
}
```

`App/StillmoonTests/SmokeTests.swift`:
```swift
import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct SmokeTests {
    @Test func coreIsLinked() {
        #expect(NightModeResolver.defaultBedtime.hour == 22)
    }
}
```

`App/StillmoonUITests/LaunchTests.swift`:
```swift
import XCTest

final class LaunchTests: XCTestCase {
    @MainActor
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}
```

- [ ] **Step 3: Run all tests**

Run: `scripts/test-app.sh`
Expected: `✔ Test run with 1 test … passed`, `Executed 1 test, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add project.yml scripts/test-app.sh .gitignore App
git commit -m "feat(app): XcodeGen project scaffold with core package and test targets"
```

---

### Task 2: Local persistence

**Files:**
- Create: `App/Stillmoon/Persistence/JournalEntry.swift`, `App/Stillmoon/Persistence/Records.swift`, `App/Stillmoon/Persistence/LocalStore.swift`
- Create: `App/StillmoonTests/TestEnv.swift`
- Test: `App/StillmoonTests/LocalStoreTests.swift`, `App/StillmoonTests/JournalEntryTests.swift`

**Interfaces:**
- Consumes: Core `CheckIn`, `ExerciseCompletion`, `ExerciseCategory`, `RecommendationFeedback`, `FeedbackRating`.
- Produces:
  - `struct JournalEntry: Identifiable, Hashable { id: UUID; bedtime: Date; wakeTime: Date; note: String?; asleepMinutes: Int; func validationMessage() -> String?; static func defaultEntry(now: Date, calendar: Calendar) -> JournalEntry }`
  - `enum StillmoonSchema { static func makeContainer(inMemory: Bool) throws -> ModelContainer }`
  - `enum LocalOwner { static let id = "local" }`
  - `final class LocalStore` with `init(container: ModelContainer, ownerID: String)`, `ownerID`, and: `checkIns() -> [CheckIn]` (newest first), `todayCheckIn(now:calendar:) -> CheckIn?`, `saveCheckIn(_:)` (upsert by id), `journalEntries() -> [JournalEntry]` (newest wake first), `saveJournalEntry(_:)` (upsert), `deleteJournalEntry(id:)`, `completions() -> [ExerciseCompletion]`, `addCompletion(_:)`, `feedback() -> [RecommendationFeedback]`, `addFeedback(_:)`, `savedItemIDs() -> Set<String>`, `setSaved(_ itemID: String, _ saved: Bool, at: Date)`, `deleteAllData()`.
  - Test fixture `TestEnv` with `tz`, `cal`, `d(y,mo,day,h,mi)`, `container()`, `store(owner:container:)`.

- [ ] **Step 1: Write the test fixture and failing tests**

`App/StillmoonTests/TestEnv.swift`:
```swift
import Foundation
import SwiftData
import StillmoonCore
@testable import Stillmoon

enum TestEnv {
    static let tz = TimeZone(identifier: "America/New_York")!

    static var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        c.firstWeekday = 1
        return c
    }

    static func d(_ y: Int, _ mo: Int, _ day: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: mo, day: day, hour: h, minute: mi))!
    }

    static func container() throws -> ModelContainer {
        try StillmoonSchema.makeContainer(inMemory: true)
    }

    static func store(owner: String = "user-a", container: ModelContainer? = nil) throws -> LocalStore {
        LocalStore(container: try container ?? Self.container(), ownerID: owner)
    }
}
```

`App/StillmoonTests/JournalEntryTests.swift`:
```swift
import Foundation
import Testing
@testable import Stillmoon

struct JournalEntryTests {
    @Test func validEntryHasNoMessage() {
        let e = JournalEntry(bedtime: TestEnv.d(2026, 10, 1, 23), wakeTime: TestEnv.d(2026, 10, 2, 7))
        #expect(e.validationMessage() == nil)
        #expect(e.asleepMinutes == 480)
    }

    @Test func wakeBeforeBedIsRejected() {
        let e = JournalEntry(bedtime: TestEnv.d(2026, 10, 2, 7), wakeTime: TestEnv.d(2026, 10, 1, 23))
        #expect(e.validationMessage() == "Wake time needs to be after bedtime.")
    }

    @Test func moreThanSixteenHoursIsRejected() {
        let e = JournalEntry(bedtime: TestEnv.d(2026, 10, 1, 13), wakeTime: TestEnv.d(2026, 10, 2, 7))
        #expect(e.validationMessage() == "That's more than 16 hours. Check the dates.")
    }

    @Test func defaultEntryIsLastNightElevenToSeven() {
        let e = JournalEntry.defaultEntry(now: TestEnv.d(2026, 10, 2, 9), calendar: TestEnv.cal)
        #expect(e.bedtime == TestEnv.d(2026, 10, 1, 23))
        #expect(e.wakeTime == TestEnv.d(2026, 10, 2, 7))
    }
}
```

`App/StillmoonTests/LocalStoreTests.swift`:
```swift
import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct LocalStoreTests {
    @Test func checkInsComeBackNewestFirst() throws {
        let store = try TestEnv.store()
        store.saveCheckIn(CheckIn(date: TestEnv.d(2026, 10, 1, 8), restedness: 2))
        store.saveCheckIn(CheckIn(date: TestEnv.d(2026, 10, 2, 8), restedness: 4))
        #expect(store.checkIns().map(\.restedness) == [4, 2])
    }

    @Test func savingSameCheckInIdUpdates() throws {
        let store = try TestEnv.store()
        var c = CheckIn(date: TestEnv.d(2026, 10, 2, 8), restedness: 2)
        store.saveCheckIn(c)
        c.restedness = 5
        c.note = "better"
        store.saveCheckIn(c)
        #expect(store.checkIns().count == 1)
        #expect(store.checkIns().first?.restedness == 5)
        #expect(store.checkIns().first?.note == "better")
    }

    @Test func todayCheckInMatchesCalendarDay() throws {
        let store = try TestEnv.store()
        store.saveCheckIn(CheckIn(date: TestEnv.d(2026, 10, 1, 8), restedness: 2))
        #expect(store.todayCheckIn(now: TestEnv.d(2026, 10, 2, 9), calendar: TestEnv.cal) == nil)
        store.saveCheckIn(CheckIn(date: TestEnv.d(2026, 10, 2, 7), restedness: 3))
        #expect(store.todayCheckIn(now: TestEnv.d(2026, 10, 2, 9), calendar: TestEnv.cal)?.restedness == 3)
    }

    @Test func ownersAreIsolated() throws {
        let container = try TestEnv.container()
        let a = try TestEnv.store(owner: "user-a", container: container)
        let b = try TestEnv.store(owner: "user-b", container: container)
        a.saveCheckIn(CheckIn(date: TestEnv.d(2026, 10, 2, 8), restedness: 4))
        a.saveJournalEntry(JournalEntry(bedtime: TestEnv.d(2026, 10, 1, 23), wakeTime: TestEnv.d(2026, 10, 2, 7)))
        a.addCompletion(ExerciseCompletion(exerciseID: "breath", category: .windDown, completedAt: TestEnv.d(2026, 10, 1, 22)))
        a.addFeedback(RecommendationFeedback(itemID: "breath", rating: .helpful, at: TestEnv.d(2026, 10, 2, 8)))
        a.setSaved("breath", true, at: TestEnv.d(2026, 10, 2, 8))
        #expect(b.checkIns().isEmpty)
        #expect(b.journalEntries().isEmpty)
        #expect(b.completions().isEmpty)
        #expect(b.feedback().isEmpty)
        #expect(b.savedItemIDs().isEmpty)
    }

    @Test func deleteAllOnlyRemovesOwnersData() throws {
        let container = try TestEnv.container()
        let a = try TestEnv.store(owner: "user-a", container: container)
        let b = try TestEnv.store(owner: "user-b", container: container)
        for s in [a, b] {
            s.saveCheckIn(CheckIn(date: TestEnv.d(2026, 10, 2, 8), restedness: 4))
            s.addCompletion(ExerciseCompletion(exerciseID: "breath", category: .windDown, completedAt: TestEnv.d(2026, 10, 1, 22)))
            s.setSaved("breath", true, at: TestEnv.d(2026, 10, 2, 8))
        }
        a.deleteAllData()
        #expect(a.checkIns().isEmpty)
        #expect(a.completions().isEmpty)
        #expect(a.savedItemIDs().isEmpty)
        #expect(b.checkIns().count == 1)
        #expect(b.completions().count == 1)
        #expect(b.savedItemIDs() == ["breath"])
    }

    @Test func completionsKeepCategoryAndId() throws {
        let store = try TestEnv.store()
        let c = ExerciseCompletion(exerciseID: "awake", category: .awakeAtNight, completedAt: TestEnv.d(2026, 10, 2, 3))
        store.addCompletion(c)
        store.addCompletion(c) // same event delivered twice is stored once
        #expect(store.completions() == [c])
    }

    @Test func journalSaveUpdateDelete() throws {
        let store = try TestEnv.store()
        var e = JournalEntry(bedtime: TestEnv.d(2026, 10, 1, 23), wakeTime: TestEnv.d(2026, 10, 2, 7))
        store.saveJournalEntry(e)
        e.note = "woke once"
        store.saveJournalEntry(e)
        #expect(store.journalEntries() == [e])
        store.deleteJournalEntry(id: e.id)
        #expect(store.journalEntries().isEmpty)
    }

    @Test func savedItemsToggle() throws {
        let store = try TestEnv.store()
        store.setSaved("breath", true, at: TestEnv.d(2026, 10, 2, 8))
        store.setSaved("scan", true, at: TestEnv.d(2026, 10, 2, 8))
        store.setSaved("breath", false, at: TestEnv.d(2026, 10, 2, 9))
        #expect(store.savedItemIDs() == ["scan"])
    }

    @Test func feedbackRoundTrips() throws {
        let store = try TestEnv.store()
        let f = RecommendationFeedback(itemID: "breath", rating: .unwanted, at: TestEnv.d(2026, 10, 2, 8))
        store.addFeedback(f)
        #expect(store.feedback() == [f])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test-app.sh -only-testing:StillmoonTests`
Expected: build FAILS with "cannot find 'JournalEntry' in scope" / "cannot find 'StillmoonSchema' in scope".

- [ ] **Step 3: Implement**

`App/Stillmoon/Persistence/JournalEntry.swift`:
```swift
import Foundation

/// A night the user recorded by hand (FR-03). Always shown as user-entered, never as a measurement.
struct JournalEntry: Identifiable, Hashable {
    var id: UUID = UUID()
    var bedtime: Date
    var wakeTime: Date
    var note: String?

    var asleepMinutes: Int { Int(wakeTime.timeIntervalSince(bedtime) / 60) }

    /// nil when the entry can be saved, otherwise a message for the form.
    func validationMessage() -> String? {
        let hours = wakeTime.timeIntervalSince(bedtime) / 3600
        if hours <= 0 { return "Wake time needs to be after bedtime." }
        if hours > 16 { return "That's more than 16 hours. Check the dates." }
        return nil
    }

    /// Yesterday 23:00 to today 07:00, as a starting point for the form.
    static func defaultEntry(now: Date, calendar: Calendar) -> JournalEntry {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        return JournalEntry(
            bedtime: calendar.date(bySettingHour: 23, minute: 0, second: 0, of: yesterday)!,
            wakeTime: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: today)!
        )
    }
}
```

`App/Stillmoon/Persistence/Records.swift`:
```swift
import Foundation
import SwiftData
import StillmoonCore

// CloudKit-compatible: every property has a default, no unique constraints (Plan 7 turns on sync).

@Model final class CheckInRecord {
    var id: UUID = UUID()
    var ownerID: String = ""
    var date: Date = Date.distantPast
    var restedness: Int = 3
    var tenseAtBedtime: Bool = false
    var wokeDuringNight: Bool = false
    var persistentDifficulty: Bool = false
    var note: String?

    init(ownerID: String, checkIn: CheckIn) {
        self.ownerID = ownerID
        update(from: checkIn)
    }

    func update(from c: CheckIn) {
        id = c.id
        date = c.date
        restedness = c.restedness
        tenseAtBedtime = c.tenseAtBedtime
        wokeDuringNight = c.wokeDuringNight
        persistentDifficulty = c.persistentDifficulty
        note = c.note
    }

    var value: CheckIn {
        CheckIn(id: id, date: date, restedness: restedness, tenseAtBedtime: tenseAtBedtime,
                wokeDuringNight: wokeDuringNight, persistentDifficulty: persistentDifficulty, note: note)
    }
}

@Model final class JournalEntryRecord {
    var id: UUID = UUID()
    var ownerID: String = ""
    var bedtime: Date = Date.distantPast
    var wakeTime: Date = Date.distantPast
    var note: String?

    init(ownerID: String, entry: JournalEntry) {
        self.ownerID = ownerID
        update(from: entry)
    }

    func update(from e: JournalEntry) {
        id = e.id
        bedtime = e.bedtime
        wakeTime = e.wakeTime
        note = e.note
    }

    var value: JournalEntry { JournalEntry(id: id, bedtime: bedtime, wakeTime: wakeTime, note: note) }
}

@Model final class CompletionRecord {
    var id: UUID = UUID()
    var ownerID: String = ""
    var exerciseID: String = ""
    var categoryRaw: String = ExerciseCategory.windDown.rawValue
    var completedAt: Date = Date.distantPast
    /// Set by the sync service in Plan 5.
    var syncedAt: Date?

    init(ownerID: String, completion: ExerciseCompletion) {
        self.ownerID = ownerID
        id = completion.id
        exerciseID = completion.exerciseID
        categoryRaw = completion.category.rawValue
        completedAt = completion.completedAt
    }

    var value: ExerciseCompletion {
        ExerciseCompletion(id: id, exerciseID: exerciseID,
                           category: ExerciseCategory(rawValue: categoryRaw) ?? .windDown,
                           completedAt: completedAt)
    }
}

@Model final class FeedbackRecord {
    var id: UUID = UUID()
    var ownerID: String = ""
    var itemID: String = ""
    var ratingRaw: String = FeedbackRating.helpful.rawValue
    var at: Date = Date.distantPast
    var syncedAt: Date?

    init(ownerID: String, feedback: RecommendationFeedback) {
        self.ownerID = ownerID
        id = feedback.id
        itemID = feedback.itemID
        ratingRaw = feedback.rating.rawValue
        at = feedback.at
    }

    var value: RecommendationFeedback {
        RecommendationFeedback(id: id, itemID: itemID, rating: FeedbackRating(rawValue: ratingRaw) ?? .helpful, at: at)
    }
}

@Model final class SavedItemRecord {
    var id: UUID = UUID()
    var ownerID: String = ""
    var itemID: String = ""
    /// Kept as a flag (not deleted) so last-write-wins sync in Plan 5 can carry "unsaved".
    var isSaved: Bool = false
    var updatedAt: Date = Date.distantPast

    init(ownerID: String, itemID: String, isSaved: Bool, updatedAt: Date) {
        self.ownerID = ownerID
        self.itemID = itemID
        self.isSaved = isSaved
        self.updatedAt = updatedAt
    }
}
```

`App/Stillmoon/Persistence/LocalStore.swift`:
```swift
import Foundation
import SwiftData
import StillmoonCore

enum StillmoonSchema {
    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let schema = Schema([CheckInRecord.self, JournalEntryRecord.self, CompletionRecord.self,
                             FeedbackRecord.self, SavedItemRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: config)
    }
}

enum LocalOwner {
    /// Placeholder owner until Plan 5 signs users in.
    static let id = "local"
}

/// Owner-scoped access to everything stored on this iPhone.
final class LocalStore {
    let container: ModelContainer
    let ownerID: String
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer, ownerID: String) {
        self.container = container
        self.ownerID = ownerID
    }

    // MARK: Check-ins

    func checkIns() -> [CheckIn] {
        let owner = ownerID
        let descriptor = FetchDescriptor<CheckInRecord>(
            predicate: #Predicate { $0.ownerID == owner },
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        return fetch(descriptor).map(\.value)
    }

    func todayCheckIn(now: Date, calendar: Calendar) -> CheckIn? {
        checkIns().first { calendar.isDate($0.date, inSameDayAs: now) }
    }

    func saveCheckIn(_ checkIn: CheckIn) {
        let owner = ownerID, id = checkIn.id
        let existing = fetch(FetchDescriptor<CheckInRecord>(predicate: #Predicate { $0.ownerID == owner && $0.id == id })).first
        if let existing { existing.update(from: checkIn) } else { context.insert(CheckInRecord(ownerID: owner, checkIn: checkIn)) }
        save()
    }

    // MARK: Journal

    func journalEntries() -> [JournalEntry] {
        let owner = ownerID
        let descriptor = FetchDescriptor<JournalEntryRecord>(
            predicate: #Predicate { $0.ownerID == owner },
            sortBy: [SortDescriptor(\.wakeTime, order: .reverse)])
        return fetch(descriptor).map(\.value)
    }

    func saveJournalEntry(_ entry: JournalEntry) {
        let owner = ownerID, id = entry.id
        let existing = fetch(FetchDescriptor<JournalEntryRecord>(predicate: #Predicate { $0.ownerID == owner && $0.id == id })).first
        if let existing { existing.update(from: entry) } else { context.insert(JournalEntryRecord(ownerID: owner, entry: entry)) }
        save()
    }

    func deleteJournalEntry(id: UUID) {
        let owner = ownerID
        for record in fetch(FetchDescriptor<JournalEntryRecord>(predicate: #Predicate { $0.ownerID == owner && $0.id == id })) {
            context.delete(record)
        }
        save()
    }

    // MARK: Completions and feedback (append-only events)

    func completions() -> [ExerciseCompletion] {
        let owner = ownerID
        let descriptor = FetchDescriptor<CompletionRecord>(
            predicate: #Predicate { $0.ownerID == owner },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
        return fetch(descriptor).map(\.value)
    }

    func addCompletion(_ completion: ExerciseCompletion) {
        let owner = ownerID, id = completion.id
        guard fetch(FetchDescriptor<CompletionRecord>(predicate: #Predicate { $0.ownerID == owner && $0.id == id })).isEmpty else { return }
        context.insert(CompletionRecord(ownerID: owner, completion: completion))
        save()
    }

    func feedback() -> [RecommendationFeedback] {
        let owner = ownerID
        let descriptor = FetchDescriptor<FeedbackRecord>(
            predicate: #Predicate { $0.ownerID == owner },
            sortBy: [SortDescriptor(\.at)])
        return fetch(descriptor).map(\.value)
    }

    func addFeedback(_ feedback: RecommendationFeedback) {
        let owner = ownerID, id = feedback.id
        guard fetch(FetchDescriptor<FeedbackRecord>(predicate: #Predicate { $0.ownerID == owner && $0.id == id })).isEmpty else { return }
        context.insert(FeedbackRecord(ownerID: owner, feedback: feedback))
        save()
    }

    // MARK: Saved items

    func savedItemIDs() -> Set<String> {
        let owner = ownerID
        let records = fetch(FetchDescriptor<SavedItemRecord>(predicate: #Predicate { $0.ownerID == owner && $0.isSaved == true }))
        return Set(records.map(\.itemID))
    }

    func setSaved(_ itemID: String, _ saved: Bool, at date: Date) {
        let owner = ownerID
        if let existing = fetch(FetchDescriptor<SavedItemRecord>(predicate: #Predicate { $0.ownerID == owner && $0.itemID == itemID })).first {
            existing.isSaved = saved
            existing.updatedAt = date
        } else {
            context.insert(SavedItemRecord(ownerID: owner, itemID: itemID, isSaved: saved, updatedAt: date))
        }
        save()
    }

    // MARK: Deletion

    /// Removes this owner's records only.
    func deleteAllData() {
        let owner = ownerID
        do {
            try context.delete(model: CheckInRecord.self, where: #Predicate { $0.ownerID == owner })
            try context.delete(model: JournalEntryRecord.self, where: #Predicate { $0.ownerID == owner })
            try context.delete(model: CompletionRecord.self, where: #Predicate { $0.ownerID == owner })
            try context.delete(model: FeedbackRecord.self, where: #Predicate { $0.ownerID == owner })
            try context.delete(model: SavedItemRecord.self, where: #Predicate { $0.ownerID == owner })
        } catch {
            assertionFailure("Delete failed: \(error)")
        }
        save()
    }

    // MARK: Helpers

    private func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
        do { return try context.fetch(descriptor) } catch {
            assertionFailure("Fetch failed: \(error)")
            return []
        }
    }

    private func save() {
        do { try context.save() } catch { assertionFailure("Save failed: \(error)") }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `scripts/test-app.sh -only-testing:StillmoonTests`
Expected: all `JournalEntryTests` (4) and `LocalStoreTests` (9) pass, plus `SmokeTests`.

- [ ] **Step 5: Commit**

```bash
git add App
git commit -m "feat(app): owner-scoped SwiftData store and manual journal entries"
```

---

### Task 3: Settings, theme and formatting

**Files:**
- Create: `App/Stillmoon/Settings/SettingsStore.swift`, `App/Stillmoon/Design/Theme.swift`, `App/Stillmoon/Design/Format.swift`
- Test: `App/StillmoonTests/SettingsTests.swift`, `App/StillmoonTests/FormatTests.swift`

**Interfaces:**
- Consumes: Core `Goal`, `ClockTime`, `NightModeResolver`, `ExerciseCategory`.
- Produces:
  - `enum NightModeOverride: String, Codable, CaseIterable { automatic, on, off }`
  - `struct AppSettings: Codable, Equatable { goal: Goal = .unwind; bedtime: ClockTime?; wakeTime: ClockTime?; weeklyGoal = 3; hasOnboarded = false; hideProgress = false; nightModeOverride = .automatic; snoringNoteShown = false }`
  - `@Observable final class SettingsStore { init(defaults: UserDefaults = .standard); var settings: AppSettings; var manualOverride: Bool?; func isNight(at:calendar:sessionActive:) -> Bool; func reset() }`
  - `struct Theme: Equatable { background, surface, text, secondaryText, accent, accent2: Color; isNight: Bool; static let day, night }`, `EnvironmentValues.theme`, `Color(hex:)`, `struct Card<Content: View>: View`
  - `extension ClockTime { func date(on: Date, calendar: Calendar) -> Date }`
  - `enum Format { static func duration(minutes:) -> String; static func exerciseLength(seconds:) -> String; static func clock(seconds:) -> String }`
  - `ExerciseCategory.title`, `Goal.title`

- [ ] **Step 1: Write the failing tests**

`App/StillmoonTests/SettingsTests.swift`:
```swift
import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct SettingsTests {
    func freshDefaults() -> UserDefaults { UserDefaults(suiteName: "test-\(UUID().uuidString)")! }

    @Test func defaultsMatchThePRD() {
        let s = SettingsStore(defaults: freshDefaults()).settings
        #expect(s.goal == .unwind)
        #expect(s.bedtime == nil)
        #expect(s.weeklyGoal == 3)
        #expect(!s.hasOnboarded)
        #expect(s.nightModeOverride == .automatic)
    }

    @Test func settingsPersistAcrossInstances() {
        let defaults = freshDefaults()
        let first = SettingsStore(defaults: defaults)
        first.settings.goal = .nightWaking
        first.settings.bedtime = ClockTime(hour: 23, minute: 15)
        first.settings.hasOnboarded = true
        let second = SettingsStore(defaults: defaults)
        #expect(second.settings == first.settings)
    }

    @Test func nightModeFollowsScheduleAndOverride() {
        let store = SettingsStore(defaults: freshDefaults())
        store.settings.bedtime = ClockTime(hour: 23, minute: 0)
        store.settings.wakeTime = ClockTime(hour: 7, minute: 0)
        #expect(!store.isNight(at: TestEnv.d(2026, 10, 2, 21, 59), calendar: TestEnv.cal, sessionActive: false))
        #expect(store.isNight(at: TestEnv.d(2026, 10, 2, 22, 0), calendar: TestEnv.cal, sessionActive: false))
        store.settings.nightModeOverride = .off
        #expect(!store.isNight(at: TestEnv.d(2026, 10, 2, 23, 30), calendar: TestEnv.cal, sessionActive: true))
        store.settings.nightModeOverride = .on
        #expect(store.isNight(at: TestEnv.d(2026, 10, 2, 14), calendar: TestEnv.cal, sessionActive: false))
    }

    @Test func resetRestoresDefaults() {
        let store = SettingsStore(defaults: freshDefaults())
        store.settings.weeklyGoal = 6
        store.reset()
        #expect(store.settings == AppSettings())
    }

    @Test func clockTimeBecomesDateOnDay() {
        let date = ClockTime(hour: 22, minute: 30).date(on: TestEnv.d(2026, 10, 2, 9), calendar: TestEnv.cal)
        #expect(date == TestEnv.d(2026, 10, 2, 22, 30))
    }
}
```

`App/StillmoonTests/FormatTests.swift`:
```swift
import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct FormatTests {
    @Test(arguments: [(45, "45 m"), (60, "1 h"), (440, "7 h 20 m"), (0, "0 m")])
    func duration(minutes: Int, text: String) {
        #expect(Format.duration(minutes: minutes) == text)
    }

    @Test(arguments: [(300, "5 min"), (30, "1 min"), (90, "2 min"), (600, "10 min")])
    func exerciseLength(seconds: Int, text: String) {
        #expect(Format.exerciseLength(seconds: seconds) == text)
    }

    @Test(arguments: [(245, "4:05"), (0, "0:00"), (59, "0:59"), (600, "10:00")])
    func clock(seconds: Int, text: String) {
        #expect(Format.clock(seconds: seconds) == text)
    }

    @Test func displayNames() {
        #expect(ExerciseCategory.awakeAtNight.title == "Awake at Night")
        #expect(Goal.consistency.title == "Build a steady routine")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test-app.sh -only-testing:StillmoonTests`
Expected: build FAILS with "cannot find 'SettingsStore' in scope".

- [ ] **Step 3: Implement**

`App/Stillmoon/Settings/SettingsStore.swift`:
```swift
import Foundation
import Observation
import StillmoonCore

enum NightModeOverride: String, Codable, CaseIterable {
    case automatic, on, off
}

struct AppSettings: Codable, Equatable {
    var goal: Goal = .unwind
    var bedtime: ClockTime?
    var wakeTime: ClockTime?
    var weeklyGoal: Int = 3
    var hasOnboarded = false
    var hideProgress = false
    var nightModeOverride: NightModeOverride = .automatic
    var snoringNoteShown = false
}

@Observable final class SettingsStore {
    static let key = "settings.v1"
    @ObservationIgnored private let defaults: UserDefaults

    var settings: AppSettings {
        didSet { persist() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let stored = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = stored
        } else {
            settings = AppSettings()
        }
    }

    var manualOverride: Bool? {
        switch settings.nightModeOverride {
        case .automatic: nil
        case .on: true
        case .off: false
        }
    }

    func isNight(at now: Date, calendar: Calendar, sessionActive: Bool) -> Bool {
        NightModeResolver.isNight(at: now, calendar: calendar, bedtime: settings.bedtime, wake: settings.wakeTime,
                                  sessionActive: sessionActive, manualOverride: manualOverride)
    }

    func reset() {
        settings = AppSettings()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

extension ClockTime {
    func date(on day: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }
}
```

`App/Stillmoon/Design/Theme.swift`:
```swift
import SwiftUI

extension Color {
    init(hex: UInt32) {
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
    let accent: Color
    let accent2: Color
    let isNight: Bool

    static let day = Theme(background: Color(hex: 0xFAF7F2), surface: Color(hex: 0xFFFFFF),
                           text: Color(hex: 0x1E1B2E), secondaryText: Color(hex: 0x5C5870),
                           accent: Color(hex: 0x8E7CC3), accent2: Color(hex: 0xE8907E), isNight: false)

    static let night = Theme(background: Color(hex: 0x12142B), surface: Color(hex: 0x2A2140),
                             text: Color(hex: 0xD9D4EE), secondaryText: Color(hex: 0x9A93B8),
                             accent: Color(hex: 0xA99BE0), accent2: Color(hex: 0xC98B80), isNight: true)
}

extension EnvironmentValues {
    @Entry var theme: Theme = .day
}

/// Rounded, spacious card (PRD §2 "Cards").
struct Card<Content: View>: View {
    @Environment(\.theme) private var theme
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .foregroundStyle(theme.text)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
```

`App/Stillmoon/Design/Format.swift`:
```swift
import Foundation
import StillmoonCore

enum Format {
    /// "45 m", "1 h", "7 h 20 m"
    static func duration(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) m" }
        if m == 0 { return "\(h) h" }
        return "\(h) h \(m) m"
    }

    /// Rounded minutes, at least 1: "5 min"
    static func exerciseLength(seconds: Int) -> String {
        "\(max(1, Int((Double(seconds) / 60).rounded()))) min"
    }

    /// "4:05"
    static func clock(seconds: Int) -> String {
        String(format: "%ld:%02ld", seconds / 60, seconds % 60)
    }
}

extension ExerciseCategory {
    var title: String {
        switch self {
        case .windDown: "Wind Down"
        case .awakeAtNight: "Awake at Night"
        case .morningReset: "Morning Reset"
        case .learn: "Learn"
        }
    }
}

extension Goal {
    var title: String {
        switch self {
        case .unwind: "Unwind before bed"
        case .understandSleep: "Understand my sleep"
        case .nightWaking: "Handle waking at night"
        case .consistency: "Build a steady routine"
        }
    }
}
```
Note: `(Double(90) / 60).rounded()` is 1.5 → 2 (schoolbook rounding), matching the `(90, "2 min")` case.

- [ ] **Step 4: Run tests to verify they pass**

Run: `scripts/test-app.sh -only-testing:StillmoonTests`
Expected: all `SettingsTests` (5) and `FormatTests` (4 tests, 12 cases) pass; earlier suites still pass.

- [ ] **Step 5: Commit**

```bash
git add App
git commit -m "feat(app): settings store, day/night theme and formatting"
```

---

### Task 4: Content catalog and app environment

**Files:**
- Create: `App/Stillmoon/Content/Content.swift`, `App/Stillmoon/Content/AppEnvironment.swift`, `App/Stillmoon/Resources/catalog.json`
- Modify: `App/StillmoonTests/TestEnv.swift` (add `catalog` and `settings()`)
- Test: `App/StillmoonTests/ContentTests.swift`

**Interfaces:**
- Consumes: Core `ExerciseCategory`, `ContentTag`, `ContentKind`, `CatalogItem`; Task 2 `LocalStore`, `StillmoonSchema`, `LocalOwner`; Task 3 `SettingsStore`.
- Produces:
  - `enum ExerciseFormat: String, Codable { text, audio }`, `enum ContentTier: String, Codable { free, premium }`
  - `struct ExerciseStep: Codable, Hashable { text: String; seconds: Int }`
  - `struct Exercise: Codable, Identifiable, Hashable { id, title, summary: String; category: ExerciseCategory; format: ExerciseFormat; tags: Set<ContentTag>; steps: [ExerciseStep]; audioFile: String?; tier: ContentTier; techniqueSource: String; licence: String; durationSeconds: Int (computed) }`
  - `struct SourceLink: Codable, Hashable { title: String; url: URL }`
  - `struct Article: Codable, Identifiable, Hashable { id, title, summary, body: String; tags: Set<ContentTag>; sources: [SourceLink]; reviewedOn: String; nextReview: String; tier: ContentTier; paragraphs: [String] (computed) }`
  - `struct ContentCatalog: Codable, Hashable { exercises: [Exercise]; articles: [Article]; static let empty; catalogItems: [CatalogItem]; exercise(id:) -> Exercise?; article(id:) -> Article?; title(for:) -> String? }`
  - `enum ContentStore { static func load(from: Data) throws -> ContentCatalog; static func loadBundled(bundle: Bundle = .main) throws -> ContentCatalog }`
  - `struct PlayerRequest: Identifiable, Hashable { exerciseID: String; id }`
  - `@Observable final class AppEnvironment { store: LocalStore; settings: SettingsStore; catalog: ContentCatalog; sessionActive: Bool; playerRequest: PlayerRequest?; init(store:settings:catalog:); static func live(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppEnvironment }`
  - `TestEnv.catalog`, `TestEnv.settings()`

- [ ] **Step 1: Extend the fixture and write failing tests**

Add to `App/StillmoonTests/TestEnv.swift` inside `enum TestEnv`:
```swift
    static func settings() -> SettingsStore {
        SettingsStore(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
    }

    static func exercise(_ id: String, _ title: String, _ category: ExerciseCategory, _ tags: Set<ContentTag>,
                         steps: [ExerciseStep] = [ExerciseStep(text: "Breathe in", seconds: 3), ExerciseStep(text: "Breathe out", seconds: 2)]) -> Exercise {
        Exercise(id: id, title: title, summary: "\(title) summary.", category: category, format: .text, tags: tags,
                 steps: steps, audioFile: nil, tier: .free, techniqueSource: "Test technique", licence: "Original")
    }

    static func article(_ id: String, _ title: String, _ tags: Set<ContentTag>) -> Article {
        Article(id: id, title: title, summary: "\(title) summary.", body: "First paragraph.\n\nSecond paragraph.",
                tags: tags, sources: [SourceLink(title: "CDC", url: URL(string: "https://www.cdc.gov/sleep/about/")!)],
                reviewedOn: "2026-10-02", nextReview: "2027-04-02", tier: .free)
    }

    static let catalog = ContentCatalog(
        exercises: [
            exercise("breath", "Gentle breathing", .windDown, [.relaxation]),
            exercise("scan", "Body scan", .windDown, [.relaxation]),
            exercise("awake", "Five quiet minutes", .awakeAtNight, [.awakeAtNight]),
            exercise("morning", "Morning reflection", .morningReset, [.morning]),
        ],
        articles: [
            article("steady-bedtime", "Keeping a steady bedtime", [.routine]),
            article("talk-to-a-doctor", "When to talk to a doctor", [.sleepData]),
        ])
```
(The file already imports `StillmoonCore`.)

`App/StillmoonTests/ContentTests.swift`:
```swift
import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct ContentTests {
    @Test func bundledCatalogLoads() throws {
        let catalog = try ContentStore.loadBundled()
        #expect(catalog.exercises.count >= 4)
        #expect(catalog.articles.count >= 3)
    }

    @Test func bundledCatalogIsWellFormed() throws {
        let catalog = try ContentStore.loadBundled()
        let ids = catalog.exercises.map(\.id) + catalog.articles.map(\.id)
        #expect(Set(ids).count == ids.count, "ids must be unique")
        for e in catalog.exercises {
            #expect(!e.steps.isEmpty, "\(e.id) needs steps")
            #expect(e.steps.allSatisfy { $0.seconds > 0 }, "\(e.id) step seconds")
            #expect(!e.tags.isEmpty, "\(e.id) needs tags")
            #expect(!e.techniqueSource.isEmpty && !e.licence.isEmpty, "\(e.id) needs provenance")
        }
        for a in catalog.articles {
            #expect(!a.sources.isEmpty, "\(a.id) needs sources")
        }
        #expect(catalog.exercise(id: "gentle-breathing") != nil)
        #expect(catalog.article(id: "talk-to-a-doctor") != nil)
        #expect(catalog.exercises.contains { $0.category == .awakeAtNight })
    }

    @Test func catalogItemsCoverExercisesThenArticles() {
        let items = TestEnv.catalog.catalogItems
        #expect(items.map(\.id) == ["breath", "scan", "awake", "morning", "steady-bedtime", "talk-to-a-doctor"])
        #expect(items[0].kind == .exercise)
        #expect(items[4].kind == .article)
        #expect(TestEnv.catalog.title(for: "steady-bedtime") == "Keeping a steady bedtime")
        #expect(TestEnv.catalog.title(for: "missing") == nil)
    }

    @Test func durationAndParagraphs() {
        #expect(TestEnv.catalog.exercises[0].durationSeconds == 5)
        #expect(TestEnv.catalog.articles[0].paragraphs == ["First paragraph.", "Second paragraph."])
    }

    @Test func uiTestingEnvironmentStartsEmpty() {
        let env = AppEnvironment.live(arguments: ["-ui-testing"])
        #expect(!env.settings.settings.hasOnboarded)
        #expect(env.store.checkIns().isEmpty)
        #expect(!env.catalog.exercises.isEmpty)
        #expect(env.store.ownerID == LocalOwner.id)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test-app.sh -only-testing:StillmoonTests`
Expected: build FAILS with "cannot find type 'ExerciseStep' in scope".

- [ ] **Step 3: Implement**

`App/Stillmoon/Content/Content.swift`:
```swift
import Foundation
import StillmoonCore

enum ExerciseFormat: String, Codable { case text, audio }
enum ContentTier: String, Codable { case free, premium }

struct ExerciseStep: Codable, Hashable {
    var text: String
    var seconds: Int
}

struct Exercise: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var summary: String
    var category: ExerciseCategory
    var format: ExerciseFormat
    var tags: Set<ContentTag>
    var steps: [ExerciseStep]
    var audioFile: String?
    var tier: ContentTier
    /// Where the technique comes from (PRD §8), shown as "Based on".
    var techniqueSource: String
    var licence: String

    var durationSeconds: Int { steps.reduce(0) { $0 + $1.seconds } }
}

struct SourceLink: Codable, Hashable {
    var title: String
    var url: URL
}

struct Article: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var summary: String
    /// Paragraphs separated by a blank line; inline Markdown allowed.
    var body: String
    var tags: Set<ContentTag>
    var sources: [SourceLink]
    var reviewedOn: String
    var nextReview: String
    var tier: ContentTier

    var paragraphs: [String] {
        body.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct ContentCatalog: Codable, Hashable {
    var exercises: [Exercise]
    var articles: [Article]

    static let empty = ContentCatalog(exercises: [], articles: [])

    /// Exercises first, then articles, each in editorial order (recommendation tie-break order).
    var catalogItems: [CatalogItem] {
        exercises.map { CatalogItem(id: $0.id, kind: .exercise, title: $0.title, tags: $0.tags) }
            + articles.map { CatalogItem(id: $0.id, kind: .article, title: $0.title, tags: $0.tags) }
    }

    func exercise(id: String) -> Exercise? { exercises.first { $0.id == id } }
    func article(id: String) -> Article? { articles.first { $0.id == id } }
    func title(for id: String) -> String? { exercise(id: id)?.title ?? article(id: id)?.title }
}

enum ContentStore {
    static func load(from data: Data) throws -> ContentCatalog {
        try JSONDecoder().decode(ContentCatalog.self, from: data)
    }

    static func loadBundled(bundle: Bundle = .main) throws -> ContentCatalog {
        guard let url = bundle.url(forResource: "catalog", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try load(from: Data(contentsOf: url))
    }
}
```

`App/Stillmoon/Content/AppEnvironment.swift`:
```swift
import Foundation
import Observation
import SwiftData

struct PlayerRequest: Identifiable, Hashable {
    let exerciseID: String
    var id: String { exerciseID }
}

/// The app's shared objects, passed through the SwiftUI environment.
@Observable final class AppEnvironment {
    let store: LocalStore
    let settings: SettingsStore
    let catalog: ContentCatalog
    /// True while a sound-detection session runs (Plan 4).
    var sessionActive = false
    /// Set to open the exercise player full screen from anywhere.
    var playerRequest: PlayerRequest?

    init(store: LocalStore, settings: SettingsStore, catalog: ContentCatalog) {
        self.store = store
        self.settings = settings
        self.catalog = catalog
    }

    /// `-ui-testing` gives an in-memory store and fresh settings.
    static func live(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppEnvironment {
        let uiTesting = arguments.contains("-ui-testing")
        let container: ModelContainer
        do {
            container = try StillmoonSchema.makeContainer(inMemory: uiTesting)
        } catch {
            fatalError("Could not open the local store: \(error)")
        }
        let defaults: UserDefaults
        if uiTesting {
            let suite = "ui-testing"
            UserDefaults().removePersistentDomain(forName: suite)
            defaults = UserDefaults(suiteName: suite)!
        } else {
            defaults = .standard
        }
        let catalog = (try? ContentStore.loadBundled()) ?? .empty
        return AppEnvironment(store: LocalStore(container: container, ownerID: LocalOwner.id),
                              settings: SettingsStore(defaults: defaults), catalog: catalog)
    }
}
```

`App/Stillmoon/Resources/catalog.json` (launch placeholder set; Plan 6 replaces the copy and adds audio):
```json
{
  "exercises": [
    {
      "id": "gentle-breathing",
      "title": "Gentle breathing",
      "summary": "Slow your breathing to a comfortable, steady rhythm.",
      "category": "windDown",
      "format": "text",
      "tags": ["relaxation"],
      "steps": [
        { "text": "Settle into a comfortable position. Let your shoulders drop.", "seconds": 40 },
        { "text": "Breathe in through your nose for a count of four.", "seconds": 50 },
        { "text": "Breathe out slowly for a count of six. Let the out-breath be longer.", "seconds": 60 },
        { "text": "Keep this rhythm. If your mind wanders, return to counting.", "seconds": 90 },
        { "text": "Let your breathing return to its own pace. Notice how you feel.", "seconds": 60 }
      ],
      "audioFile": null,
      "tier": "free",
      "techniqueSource": "Paced breathing with a longer exhale (NCCIH relaxation techniques)",
      "licence": "Original script"
    },
    {
      "id": "body-scan",
      "title": "Body scan",
      "summary": "Move your attention slowly from your feet to your head.",
      "category": "windDown",
      "format": "text",
      "tags": ["relaxation"],
      "steps": [
        { "text": "Lie down and let the bed take your weight.", "seconds": 45 },
        { "text": "Notice your feet and ankles. Let them soften.", "seconds": 75 },
        { "text": "Move your attention to your legs and hips.", "seconds": 75 },
        { "text": "Notice your belly and chest rising and falling.", "seconds": 75 },
        { "text": "Soften your hands, arms and shoulders.", "seconds": 75 },
        { "text": "Relax your jaw, your eyes and your forehead.", "seconds": 75 },
        { "text": "Rest here, aware of your whole body.", "seconds": 60 }
      ],
      "audioFile": null,
      "tier": "free",
      "techniqueSource": "Body scan (VA Whole Health mindfulness practice)",
      "licence": "Original script"
    },
    {
      "id": "five-quiet-minutes",
      "title": "Five quiet minutes",
      "summary": "For when you wake in the night. No need to fall asleep; just rest.",
      "category": "awakeAtNight",
      "format": "text",
      "tags": ["awakeAtNight", "relaxation"],
      "steps": [
        { "text": "You're awake, and that's okay. There's nothing you need to do.", "seconds": 45 },
        { "text": "Breathe out slowly, a little longer than you breathe in.", "seconds": 75 },
        { "text": "Notice three things you can feel: the pillow, the blanket, your breath.", "seconds": 75 },
        { "text": "If thoughts come, let them pass like clouds.", "seconds": 60 },
        { "text": "Rest your eyes. Resting is enough.", "seconds": 45 }
      ],
      "audioFile": null,
      "tier": "free",
      "techniqueSource": "Grounding and paced breathing (NCCIH relaxation techniques)",
      "licence": "Original script"
    },
    {
      "id": "morning-reflection",
      "title": "Morning reflection",
      "summary": "A short check-in with yourself to start the day gently.",
      "category": "morningReset",
      "format": "text",
      "tags": ["morning"],
      "steps": [
        { "text": "Before you reach for your phone's other apps, take three slow breaths.", "seconds": 30 },
        { "text": "Notice how your body feels right now, without judging it.", "seconds": 45 },
        { "text": "Pick one small thing you'd like to do for yourself today.", "seconds": 45 },
        { "text": "Open a curtain or step outside for a minute of daylight if you can.", "seconds": 60 }
      ],
      "audioFile": null,
      "tier": "free",
      "techniqueSource": "Morning light and brief reflection (CDC sleep guidance)",
      "licence": "Original script"
    }
  ],
  "articles": [
    {
      "id": "steady-bedtime",
      "title": "Why a steady bedtime helps",
      "summary": "Going to bed and getting up at similar times can make sleep feel easier.",
      "body": "Your body keeps an internal clock. When bedtimes and wake times move around a lot, that clock has to keep adjusting.\n\nTry keeping your wake time within about an hour each day, including weekends. A steady morning tends to make evenings steadier too.\n\nIf a night goes badly, you don't need to make it up by sleeping in. Get up at your usual time and be gentle with yourself.",
      "tags": ["routine"],
      "sources": [{ "title": "CDC: About Sleep", "url": "https://www.cdc.gov/sleep/about/" }],
      "reviewedOn": "2026-10-02",
      "nextReview": "2027-04-02",
      "tier": "free"
    },
    {
      "id": "what-your-watch-estimates",
      "title": "What your watch is estimating",
      "summary": "Sleep stages from a wearable are estimates, not measurements.",
      "body": "Watches and rings estimate sleep stages from movement and heart rate. They are useful for spotting patterns over many nights, but a single night's numbers can be off.\n\nHow you feel in the morning matters as much as any chart. Stillmoon always shows your own check-in next to what a device estimated.",
      "tags": ["sleepData"],
      "sources": [{ "title": "NHLBI: Stages of Sleep", "url": "https://www.nhlbi.nih.gov/health/sleep/stages-of-sleep" }],
      "reviewedOn": "2026-10-02",
      "nextReview": "2027-04-02",
      "tier": "free"
    },
    {
      "id": "talk-to-a-doctor",
      "title": "When to talk to a doctor",
      "summary": "Some sleep difficulties are worth mentioning to a healthcare professional.",
      "body": "If you've had trouble falling or staying asleep most nights for several weeks, it can help to talk with a doctor or another qualified healthcare professional.\n\nIt's also worth mentioning loud, frequent snoring, or feeling very sleepy during the day even after a full night in bed.\n\nStillmoon can't diagnose sleep conditions. A professional can look at the whole picture with you.",
      "tags": ["sleepData"],
      "sources": [{ "title": "NHLBI: Insomnia", "url": "https://www.nhlbi.nih.gov/health/insomnia" }],
      "reviewedOn": "2026-10-02",
      "nextReview": "2027-04-02",
      "tier": "free"
    }
  ]
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `scripts/test-app.sh -only-testing:StillmoonTests`
Expected: all `ContentTests` (5) pass; earlier suites still pass.

- [ ] **Step 5: Commit**

```bash
git add App
git commit -m "feat(app): content catalog, bundled launch content and app environment"
```

---

### Task 5: Sleep journal and morning check-in

**Files:**
- Create: `App/Stillmoon/Features/Sleep/SleepModel.swift`, `SleepView.swift`, `JournalEntryForm.swift`, `CheckInSheet.swift` (all under `App/Stillmoon/Features/Sleep/`)
- Test: `App/StillmoonTests/SleepModelTests.swift`

**Interfaces:**
- Consumes: `LocalStore` (Task 2), `JournalEntry` (Task 2), `Theme`, `Format` (Task 3), Core `CheckIn`.
- Produces:
  - `struct NightRow: Identifiable, Hashable { entry: JournalEntry; checkIn: CheckIn?; id: UUID }`
  - `@Observable final class SleepModel { init(store: LocalStore, calendar: Calendar = .current); rows: [NightRow]; refresh(); save(_ entry: JournalEntry); delete(_ row: NightRow) }`
  - `struct SleepView: View { let model: SleepModel }`
  - `struct JournalEntryForm: View { init(entry: JournalEntry? = nil, now: Date = .now, calendar: Calendar = .current, onSave: @escaping (JournalEntry) -> Void) }`
  - `struct CheckInSheet: View { init(existing: CheckIn?, onSave: @escaping (CheckIn) -> Void) }`

- [ ] **Step 1: Write the failing tests**

`App/StillmoonTests/SleepModelTests.swift`:
```swift
import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct SleepModelTests {
    func entry(_ day: Int) -> JournalEntry {
        JournalEntry(bedtime: TestEnv.d(2026, 10, day - 1, 23), wakeTime: TestEnv.d(2026, 10, day, 7))
    }

    @Test func rowsAreNewestFirstWithMatchingCheckIn() throws {
        let store = try TestEnv.store()
        store.saveJournalEntry(entry(1))
        store.saveJournalEntry(entry(2))
        store.saveCheckIn(CheckIn(date: TestEnv.d(2026, 10, 2, 8), restedness: 4))
        let model = SleepModel(store: store, calendar: TestEnv.cal)
        model.refresh()
        #expect(model.rows.map(\.entry.wakeTime) == [TestEnv.d(2026, 10, 2, 7), TestEnv.d(2026, 10, 1, 7)])
        #expect(model.rows[0].checkIn?.restedness == 4)
        #expect(model.rows[1].checkIn == nil)
    }

    @Test func saveAndDeleteRefreshRows() throws {
        let model = SleepModel(store: try TestEnv.store(), calendar: TestEnv.cal)
        model.save(entry(2))
        #expect(model.rows.count == 1)
        model.delete(model.rows[0])
        #expect(model.rows.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/SleepModelTests`
Expected: build FAILS with "cannot find 'SleepModel' in scope".

- [ ] **Step 3: Implement the model and views**

`App/Stillmoon/Features/Sleep/SleepModel.swift`:
```swift
import Foundation
import Observation
import StillmoonCore

struct NightRow: Identifiable, Hashable {
    let entry: JournalEntry
    /// The check-in made on the morning of the wake time, if any.
    let checkIn: CheckIn?
    var id: UUID { entry.id }
}

@Observable final class SleepModel {
    @ObservationIgnored private let store: LocalStore
    @ObservationIgnored private let calendar: Calendar
    private(set) var rows: [NightRow] = []

    init(store: LocalStore, calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
    }

    func refresh() {
        let checkIns = store.checkIns()
        rows = store.journalEntries().map { entry in
            NightRow(entry: entry, checkIn: checkIns.first { calendar.isDate($0.date, inSameDayAs: entry.wakeTime) })
        }
    }

    func save(_ entry: JournalEntry) {
        store.saveJournalEntry(entry)
        refresh()
    }

    func delete(_ row: NightRow) {
        store.deleteJournalEntry(id: row.entry.id)
        refresh()
    }
}
```

`App/Stillmoon/Features/Sleep/SleepView.swift`:
```swift
import SwiftUI

struct SleepView: View {
    @Environment(\.theme) private var theme
    let model: SleepModel
    @State private var addingEntry = false

    var body: some View {
        List {
            if model.rows.isEmpty {
                ContentUnavailableView("No nights yet", systemImage: "moon.zzz",
                                       description: Text("Add last night with the + button."))
                    .listRowBackground(Color.clear)
            }
            ForEach(model.rows) { row in
                NightRowView(row: row)
                    .listRowBackground(theme.surface)
            }
            .onDelete { offsets in
                let rows = offsets.map { model.rows[$0] }
                rows.forEach { model.delete($0) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Sleep")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { addingEntry = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add a night")
            }
        }
        .sheet(isPresented: $addingEntry) {
            JournalEntryForm { model.save($0) }
        }
        .onAppear { model.refresh() }
    }
}

struct NightRowView: View {
    @Environment(\.theme) private var theme
    let row: NightRow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.entry.wakeTime, format: .dateTime.weekday(.wide).month().day())
                .font(.headline)
            Text("You recorded \(row.entry.bedtime.formatted(date: .omitted, time: .shortened)) to \(row.entry.wakeTime.formatted(date: .omitted, time: .shortened)) · \(Format.duration(minutes: row.entry.asleepMinutes)) in bed")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
            if let checkIn = row.checkIn {
                Text("You felt \(checkIn.restedness) of 5 rested")
                    .font(.subheadline)
            }
            if let note = row.entry.note, !note.isEmpty {
                Text(note)
                    .font(.callout)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .foregroundStyle(theme.text)
        .padding(.vertical, 4)
    }
}
```

`App/Stillmoon/Features/Sleep/JournalEntryForm.swift`:
```swift
import SwiftUI

struct JournalEntryForm: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entry: JournalEntry
    private let onSave: (JournalEntry) -> Void

    init(entry: JournalEntry? = nil, now: Date = .now, calendar: Calendar = .current,
         onSave: @escaping (JournalEntry) -> Void) {
        self.onSave = onSave
        _entry = State(initialValue: entry ?? JournalEntry.defaultEntry(now: now, calendar: calendar))
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Went to bed", selection: $entry.bedtime)
                DatePicker("Woke up", selection: $entry.wakeTime)
                TextField("Anything to note? (optional)",
                          text: Binding(get: { entry.note ?? "" }, set: { entry.note = $0.isEmpty ? nil : $0 }),
                          axis: .vertical)
                    .lineLimit(3...6)
                if let message = entry.validationMessage() {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Your night")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(entry)
                        dismiss()
                    }
                    .disabled(entry.validationMessage() != nil)
                }
            }
        }
    }
}
```

`App/Stillmoon/Features/Sleep/CheckInSheet.swift`:
```swift
import SwiftUI
import StillmoonCore

struct CheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let existing: CheckIn?
    private let onSave: (CheckIn) -> Void
    @State private var restedness: Int
    @State private var tense: Bool
    @State private var woke: Bool
    @State private var persistent: Bool
    @State private var note: String

    init(existing: CheckIn?, onSave: @escaping (CheckIn) -> Void) {
        self.existing = existing
        self.onSave = onSave
        _restedness = State(initialValue: existing?.restedness ?? 3)
        _tense = State(initialValue: existing?.tenseAtBedtime ?? false)
        _woke = State(initialValue: existing?.wokeDuringNight ?? false)
        _persistent = State(initialValue: existing?.persistentDifficulty ?? false)
        _note = State(initialValue: existing?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("How rested do you feel?") {
                    Picker("Rested", selection: $restedness) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Text("Not at all")
                        Spacer()
                        Text("Very")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Section {
                    Toggle("I felt tense at bedtime", isOn: $tense)
                    Toggle("I was awake during the night", isOn: $woke)
                    Toggle("Trouble sleeping most nights for 3+ weeks", isOn: $persistent)
                }
                Section("Note") {
                    TextField("Optional", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("How do you feel?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(CheckIn(id: existing?.id ?? UUID(), date: existing?.date ?? .now,
                                       restedness: restedness, tenseAtBedtime: tense, wokeDuringNight: woke,
                                       persistentDifficulty: persistent, note: note.isEmpty ? nil : note))
                        dismiss()
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `scripts/test-app.sh -only-testing:StillmoonTests`
Expected: `SleepModelTests` (2) pass; all earlier suites pass; the app target builds (views compile).

- [ ] **Step 5: Commit**

```bash
git add App
git commit -m "feat(app): sleep journal list, entry form and morning check-in"
```

---

### Task 6: Exercise library, articles and player

**Files:**
- Create under `App/Stillmoon/Features/Exercises/`: `ExercisesModel.swift`, `PlayerModel.swift`, `Route.swift`, `ExercisesView.swift`, `ExerciseDetailView.swift`, `ArticleView.swift`, `PlayerView.swift`
- Test: `App/StillmoonTests/ExercisesModelTests.swift`, `App/StillmoonTests/PlayerModelTests.swift`

**Interfaces:**
- Consumes: `LocalStore`, `ContentCatalog`, `Exercise`, `Article`, `ExerciseStep`, `AppEnvironment` (`store`, `catalog`), `Theme`, `Card`, `Format`, `ExerciseCategory.title`; Core `ExerciseCompletion`, `ContentKind`.
- Produces:
  - `enum LibraryFilter: Hashable { all, category(ExerciseCategory), saved }`
  - `@Observable final class ExercisesModel { init(store:catalog:now: @escaping () -> Date = Date.init); query: String; filter: LibraryFilter; savedIDs: Set<String>; exercises: [Exercise]; articles: [Article]; refresh(); isSaved(_:) -> Bool; toggleSaved(_:) }`
  - `@Observable final class PlayerModel { init(exercise:store:now: @escaping () -> Date = Date.init); exercise; stepIndex; elapsedInStep; isPlaying; isComplete; currentStep; remainingSeconds; play(); pause(); togglePlay(); tick(); skipStep(); finish() }`
  - `enum Route: Hashable { exercise(String), article(String) }`, `struct RouteDestination: View { let route: Route }`
  - `struct ExercisesView: View { @Bindable var model: ExercisesModel }`, `ExerciseDetailView(exercise:)`, `ArticleView(article:)`, `PlayerView(model:)`

- [ ] **Step 1: Write the failing tests**

`App/StillmoonTests/ExercisesModelTests.swift`:
```swift
import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct ExercisesModelTests {
    func model() throws -> ExercisesModel {
        let m = ExercisesModel(store: try TestEnv.store(), catalog: TestEnv.catalog, now: { TestEnv.d(2026, 10, 2, 9) })
        m.refresh()
        return m
    }

    @Test func allShowsEverything() throws {
        let m = try model()
        #expect(m.exercises.count == 4)
        #expect(m.articles.count == 2)
    }

    @Test func categoryFilters() throws {
        let m = try model()
        m.filter = .category(.windDown)
        #expect(m.exercises.map(\.id) == ["breath", "scan"])
        #expect(m.articles.isEmpty)
        m.filter = .category(.learn)
        #expect(m.exercises.isEmpty)
        #expect(m.articles.count == 2)
    }

    @Test func searchIgnoresCase() throws {
        let m = try model()
        m.query = "BREATH"
        #expect(m.exercises.map(\.id) == ["breath"])
        #expect(m.articles.isEmpty)
        m.query = "doctor"
        #expect(m.articles.map(\.id) == ["talk-to-a-doctor"])
    }

    @Test func savedFilterAndToggle() throws {
        let m = try model()
        m.toggleSaved("scan")
        m.toggleSaved("steady-bedtime")
        m.filter = .saved
        #expect(m.exercises.map(\.id) == ["scan"])
        #expect(m.articles.map(\.id) == ["steady-bedtime"])
        m.toggleSaved("scan")
        #expect(!m.isSaved("scan"))
        #expect(m.exercises.isEmpty)
    }
}
```

`App/StillmoonTests/PlayerModelTests.swift`:
```swift
import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct PlayerModelTests {
    // TestEnv "breath": steps of 3 s and 2 s.
    func make() throws -> (PlayerModel, LocalStore) {
        let store = try TestEnv.store()
        let model = PlayerModel(exercise: TestEnv.catalog.exercises[0], store: store, now: { TestEnv.d(2026, 10, 2, 22) })
        return (model, store)
    }

    @Test func ticksMoveThroughStepsAndFinish() throws {
        let (m, store) = try make()
        m.play()
        #expect(m.remainingSeconds == 5)
        for _ in 0..<3 { m.tick() }
        #expect(m.stepIndex == 1)
        #expect(m.remainingSeconds == 2)
        for _ in 0..<2 { m.tick() }
        #expect(m.isComplete)
        #expect(!m.isPlaying)
        #expect(m.remainingSeconds == 0)
        #expect(store.completions().map(\.exerciseID) == ["breath"])
        #expect(store.completions().first?.category == .windDown)
    }

    @Test func pausedTicksDoNothing() throws {
        let (m, _) = try make()
        m.tick()
        #expect(m.elapsedInStep == 0)
        m.play()
        m.tick()
        m.pause()
        m.tick()
        #expect(m.elapsedInStep == 1)
    }

    @Test func skipAdvancesAndLastSkipFinishes() throws {
        let (m, store) = try make()
        m.skipStep()
        #expect(m.stepIndex == 1)
        #expect(m.elapsedInStep == 0)
        m.skipStep()
        #expect(m.isComplete)
        #expect(store.completions().count == 1)
    }

    @Test func finishRecordsOnce() throws {
        let (m, store) = try make()
        m.finish()
        m.finish()
        m.skipStep()
        #expect(store.completions().count == 1)
    }

    @Test func endingEarlyRecordsNothing() throws {
        let (m, store) = try make()
        m.play()
        m.tick()
        m.pause()
        #expect(store.completions().isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test-app.sh -only-testing:StillmoonTests`
Expected: build FAILS with "cannot find 'ExercisesModel' in scope".

- [ ] **Step 3: Implement the models**

`App/Stillmoon/Features/Exercises/ExercisesModel.swift`:
```swift
import Foundation
import Observation
import StillmoonCore

enum LibraryFilter: Hashable {
    case all
    case category(ExerciseCategory)
    case saved
}

@Observable final class ExercisesModel {
    @ObservationIgnored private let store: LocalStore
    @ObservationIgnored let catalog: ContentCatalog
    @ObservationIgnored private let now: () -> Date
    var query = ""
    var filter: LibraryFilter = .all
    private(set) var savedIDs: Set<String> = []

    init(store: LocalStore, catalog: ContentCatalog, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.catalog = catalog
        self.now = now
    }

    func refresh() {
        savedIDs = store.savedItemIDs()
    }

    var exercises: [Exercise] {
        catalog.exercises.filter { exercise in
            switch filter {
            case .all: true
            case .category(let category): exercise.category == category
            case .saved: savedIDs.contains(exercise.id)
            }
        }
        .filter { matches($0.title, $0.summary) }
    }

    /// Articles live under Learn.
    var articles: [Article] {
        catalog.articles.filter { article in
            switch filter {
            case .all, .category(.learn): true
            case .category: false
            case .saved: savedIDs.contains(article.id)
            }
        }
        .filter { matches($0.title, $0.summary) }
    }

    func isSaved(_ id: String) -> Bool { savedIDs.contains(id) }

    func toggleSaved(_ id: String) {
        store.setSaved(id, !isSaved(id), at: now())
        refresh()
    }

    private func matches(_ texts: String...) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty || texts.contains { $0.localizedStandardContains(q) }
    }
}
```

`App/Stillmoon/Features/Exercises/PlayerModel.swift`:
```swift
import Foundation
import Observation
import StillmoonCore

/// Drives a step-by-step exercise. The view calls `tick()` once a second.
@Observable final class PlayerModel {
    let exercise: Exercise
    @ObservationIgnored private let store: LocalStore
    @ObservationIgnored private let now: () -> Date
    private(set) var stepIndex = 0
    private(set) var elapsedInStep = 0
    private(set) var isPlaying = false
    private(set) var isComplete = false

    init(exercise: Exercise, store: LocalStore, now: @escaping () -> Date = Date.init) {
        precondition(!exercise.steps.isEmpty, "Exercise \(exercise.id) has no steps")
        self.exercise = exercise
        self.store = store
        self.now = now
    }

    var currentStep: ExerciseStep { exercise.steps[stepIndex] }

    var remainingSeconds: Int {
        guard !isComplete else { return 0 }
        let later = exercise.steps.dropFirst(stepIndex + 1).reduce(0) { $0 + $1.seconds }
        return max(0, currentStep.seconds - elapsedInStep) + later
    }

    func play() {
        guard !isComplete else { return }
        isPlaying = true
    }

    func pause() { isPlaying = false }

    func togglePlay() { isPlaying ? pause() : play() }

    func tick() {
        guard isPlaying, !isComplete else { return }
        elapsedInStep += 1
        if elapsedInStep >= currentStep.seconds { advance() }
    }

    func skipStep() {
        guard !isComplete else { return }
        advance()
    }

    /// Records the completion exactly once. Leaving early never calls this.
    func finish() {
        guard !isComplete else { return }
        isComplete = true
        isPlaying = false
        store.addCompletion(ExerciseCompletion(exerciseID: exercise.id, category: exercise.category, completedAt: now()))
    }

    private func advance() {
        if stepIndex + 1 < exercise.steps.count {
            stepIndex += 1
            elapsedInStep = 0
        } else {
            finish()
        }
    }
}
```

- [ ] **Step 4: Implement routing and views**

`App/Stillmoon/Features/Exercises/Route.swift`:
```swift
import SwiftUI

enum Route: Hashable {
    case exercise(String)
    case article(String)
}

struct RouteDestination: View {
    @Environment(AppEnvironment.self) private var env
    let route: Route

    var body: some View {
        switch route {
        case .exercise(let id):
            if let exercise = env.catalog.exercise(id: id) {
                ExerciseDetailView(exercise: exercise)
            } else {
                ContentUnavailableView("Not available", systemImage: "questionmark.circle")
            }
        case .article(let id):
            if let article = env.catalog.article(id: id) {
                ArticleView(article: article)
            } else {
                ContentUnavailableView("Not available", systemImage: "questionmark.circle")
            }
        }
    }
}
```

`App/Stillmoon/Features/Exercises/ExercisesView.swift`:
```swift
import SwiftUI
import StillmoonCore

struct ExercisesView: View {
    @Environment(\.theme) private var theme
    @Bindable var model: ExercisesModel

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        chip("All", .all)
                        ForEach(ExerciseCategory.allCases, id: \.self) { chip($0.title, .category($0)) }
                        chip("Saved", .saved)
                    }
                    .padding(.horizontal)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            if !model.exercises.isEmpty {
                Section("Exercises") {
                    ForEach(model.exercises) { exercise in
                        NavigationLink(value: Route.exercise(exercise.id)) {
                            ExerciseRow(exercise: exercise, isSaved: model.isSaved(exercise.id))
                        }
                        .listRowBackground(theme.surface)
                    }
                }
            }
            if !model.articles.isEmpty {
                Section("Articles") {
                    ForEach(model.articles) { article in
                        NavigationLink(value: Route.article(article.id)) {
                            ArticleRow(article: article)
                        }
                        .listRowBackground(theme.surface)
                    }
                }
            }
            if model.exercises.isEmpty && model.articles.isEmpty {
                ContentUnavailableView.search(text: model.query)
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
        .searchable(text: $model.query, prompt: "Search exercises and articles")
        .navigationTitle("Exercises")
        .onAppear { model.refresh() }
    }

    private func chip(_ title: String, _ filter: LibraryFilter) -> some View {
        Button(title) { model.filter = filter }
            .buttonStyle(.bordered)
            .tint(model.filter == filter ? theme.accent : theme.secondaryText)
            .accessibilityAddTraits(model.filter == filter ? .isSelected : [])
    }
}

struct ExerciseRow: View {
    @Environment(\.theme) private var theme
    let exercise: Exercise
    let isSaved: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.title).font(.headline)
                Text("\(exercise.category.title) · \(Format.exerciseLength(seconds: exercise.durationSeconds)) · \(exercise.format == .audio ? "Audio" : "Text")")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer()
            if isSaved {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(theme.accent)
                    .accessibilityLabel("Saved")
            }
        }
        .foregroundStyle(theme.text)
    }
}

struct ArticleRow: View {
    @Environment(\.theme) private var theme
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(article.title).font(.headline)
            Text(article.summary)
                .font(.subheadline)
                .lineLimit(2)
                .foregroundStyle(theme.secondaryText)
            Text("Reviewed \(article.reviewedOn)")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
        }
        .foregroundStyle(theme.text)
    }
}
```

`App/Stillmoon/Features/Exercises/ExerciseDetailView.swift`:
```swift
import SwiftUI

struct ExerciseDetailView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    let exercise: Exercise
    @State private var isSaved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(exercise.title)
                    .font(.largeTitle.weight(.semibold))
                Text("\(exercise.category.title) · \(Format.exerciseLength(seconds: exercise.durationSeconds))")
                    .foregroundStyle(theme.secondaryText)
                Text(exercise.summary)
                Button {
                    env.playerRequest = PlayerRequest(exerciseID: exercise.id)
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(theme.accent)
                Text("Based on: \(exercise.techniqueSource)")
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryText)
            }
            .foregroundStyle(theme.text)
            .padding()
        }
        .background(theme.background.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    env.store.setSaved(exercise.id, !isSaved, at: .now)
                    isSaved.toggle()
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(isSaved ? "Remove from saved" : "Save")
            }
        }
        .onAppear { isSaved = env.store.savedItemIDs().contains(exercise.id) }
    }
}
```

`App/Stillmoon/Features/Exercises/ArticleView.swift`:
```swift
import SwiftUI

struct ArticleView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    let article: Article
    @State private var isSaved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title)
                    .font(.largeTitle.weight(.semibold))
                Text(article.summary)
                    .font(.title3)
                    .foregroundStyle(theme.secondaryText)
                ForEach(Array(article.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(LocalizedStringKey(paragraph))
                }
                Divider()
                Text("Sources").font(.headline)
                ForEach(article.sources, id: \.url) { source in
                    Link(source.title, destination: source.url)
                }
                Text("Reviewed \(article.reviewedOn)")
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryText)
            }
            .foregroundStyle(theme.text)
            .padding()
        }
        .background(theme.background.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    env.store.setSaved(article.id, !isSaved, at: .now)
                    isSaved.toggle()
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(isSaved ? "Remove from saved" : "Save")
            }
        }
        .onAppear { isSaved = env.store.savedItemIDs().contains(article.id) }
    }
}
```

`App/Stillmoon/Features/Exercises/PlayerView.swift`:
```swift
import SwiftUI
import UIKit

/// Always dim (PRD §2 night interaction): large controls, minimal text, no reward animation.
struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: PlayerModel
    private let theme = Theme.night

    init(model: PlayerModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        VStack(spacing: 32) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(model.isComplete ? "Close" : "End exercise")
                Spacer()
            }
            Spacer()
            if model.isComplete {
                Text("Well done. Rest now.")
                    .font(.title.weight(.medium))
                    .multilineTextAlignment(.center)
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            } else {
                Text(model.exercise.title)
                    .font(.headline)
                    .foregroundStyle(theme.secondaryText)
                Text(model.currentStep.text)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 120)
                Text(Format.clock(seconds: model.remainingSeconds))
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(theme.secondaryText)
                    .accessibilityLabel("\(Format.exerciseLength(seconds: model.remainingSeconds)) left")
                HStack(spacing: 40) {
                    Button { model.togglePlay() } label: {
                        Image(systemName: model.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 88))
                    }
                    .accessibilityLabel(model.isPlaying ? "Pause" : "Play")
                    Button { model.skipStep() } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.title)
                            .frame(width: 44, height: 44)
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
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                model.tick()
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            model.play()
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `scripts/test-app.sh -only-testing:StillmoonTests`
Expected: `ExercisesModelTests` (4) and `PlayerModelTests` (5) pass; earlier suites pass.

- [ ] **Step 6: Commit**

```bash
git add App
git commit -m "feat(app): exercise library, articles and dim exercise player"
```

---

### Task 7: Journey and Settings

**Files:**
- Create: `App/Stillmoon/Features/Journey/JourneyModel.swift`, `App/Stillmoon/Features/Journey/JourneyView.swift`, `App/Stillmoon/Features/Settings/SettingsView.swift`
- Modify: `App/Stillmoon/Content/AppEnvironment.swift` (add `deleteAllLocalData()`)
- Test: `App/StillmoonTests/JourneyModelTests.swift`

**Interfaces:**
- Consumes: `LocalStore`, `SettingsStore`, `ContentCatalog`, `AppEnvironment`, `Theme`, `Card`, `Goal.title`, `NightModeOverride`, `ClockTime.date(on:calendar:)`; Core `ProgressCalculator`, `ProgressSummary` (public init from Plan 1).
- Produces:
  - `struct RecentCompletion: Identifiable, Hashable { id: UUID; title: String; completedAt: Date }`
  - `@Observable final class JourneyModel { init(store:settings:catalog:now:calendar:); summary: ProgressSummary; recent: [RecentCompletion]; isHidden: Bool; stageName: String; refresh(); static let stageNames: [String] }`
  - `JourneyView(model:)`, `SettingsView()`, `AppEnvironment.deleteAllLocalData()`

- [ ] **Step 1: Write the failing tests**

`App/StillmoonTests/JourneyModelTests.swift`:
```swift
import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct JourneyModelTests {
    let now = TestEnv.d(2026, 10, 2, 12) // Friday; week began Sunday 2026-09-27

    @Test func summarisesWeekAndRecent() throws {
        let store = try TestEnv.store()
        store.addCompletion(ExerciseCompletion(exerciseID: "breath", category: .windDown, completedAt: TestEnv.d(2026, 9, 28, 22)))
        store.addCompletion(ExerciseCompletion(exerciseID: "scan", category: .windDown, completedAt: TestEnv.d(2026, 10, 1, 22)))
        store.addCompletion(ExerciseCompletion(exerciseID: "gone", category: .windDown, completedAt: TestEnv.d(2026, 9, 20, 22)))
        let model = JourneyModel(store: store, settings: TestEnv.settings(), catalog: TestEnv.catalog,
                                 now: { now }, calendar: TestEnv.cal)
        model.refresh()
        #expect(model.summary.windDownsThisWeek == 2)
        #expect(model.summary.totalWindDowns == 3)
        #expect(model.summary.journeyStage == 2)
        #expect(model.stageName == "Quiet meadow")
        #expect(model.recent.map(\.title) == ["Body scan", "Gentle breathing"]) // unknown ids are skipped
    }

    @Test func respectsWeeklyGoalAndHide() throws {
        let settings = TestEnv.settings()
        settings.settings.weeklyGoal = 5
        settings.settings.hideProgress = true
        let model = JourneyModel(store: try TestEnv.store(), settings: settings, catalog: TestEnv.catalog,
                                 now: { now }, calendar: TestEnv.cal)
        model.refresh()
        #expect(model.summary.weeklyGoal == 5)
        #expect(model.isHidden)
        #expect(model.stageName == "The path begins")
    }

    @Test func deleteAllLocalDataKeepsOnboarding() throws {
        let settings = TestEnv.settings()
        settings.settings.hasOnboarded = true
        settings.settings.weeklyGoal = 6
        let store = try TestEnv.store()
        store.addCompletion(ExerciseCompletion(exerciseID: "breath", category: .windDown, completedAt: now))
        let env = AppEnvironment(store: store, settings: settings, catalog: TestEnv.catalog)
        env.deleteAllLocalData()
        #expect(store.completions().isEmpty)
        #expect(settings.settings.hasOnboarded)
        #expect(settings.settings.weeklyGoal == 3)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/JourneyModelTests`
Expected: build FAILS with "cannot find 'JourneyModel' in scope".

- [ ] **Step 3: Implement**

`App/Stillmoon/Features/Journey/JourneyModel.swift`:
```swift
import Foundation
import Observation
import StillmoonCore

struct RecentCompletion: Identifiable, Hashable {
    let id: UUID
    let title: String
    let completedAt: Date
}

@Observable final class JourneyModel {
    /// Stage 0 is the empty path; 1...6 are the illustrated stages (PRD §2).
    static let stageNames = ["The path begins", "First light", "Quiet meadow", "Willow bend",
                             "Still lake", "Hilltop", "Moonrise"]
    static let recentLimit = 10

    @ObservationIgnored private let store: LocalStore
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let catalog: ContentCatalog
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: Calendar

    private(set) var summary = ProgressSummary(windDownsThisWeek: 0, weeklyGoal: 3, goalMet: false,
                                               totalWindDowns: 0, journeyStage: 0)
    private(set) var recent: [RecentCompletion] = []

    init(store: LocalStore, settings: SettingsStore, catalog: ContentCatalog,
         now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.store = store
        self.settings = settings
        self.catalog = catalog
        self.now = now
        self.calendar = calendar
    }

    var isHidden: Bool { settings.settings.hideProgress }
    var stageName: String { Self.stageNames[summary.journeyStage] }

    func refresh() {
        let completions = store.completions()
        summary = ProgressCalculator.summary(completions: completions, weeklyGoal: settings.settings.weeklyGoal,
                                             now: now(), calendar: calendar)
        recent = completions.prefix(Self.recentLimit).compactMap { c in
            catalog.title(for: c.exerciseID).map { RecentCompletion(id: c.id, title: $0, completedAt: c.completedAt) }
        }
    }
}
```

`App/Stillmoon/Features/Journey/JourneyView.swift`:
```swift
import SwiftUI

struct JourneyView: View {
    @Environment(\.theme) private var theme
    let model: JourneyModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if model.isHidden {
                    Card {
                        Text("Progress is hidden. You can show it again in Settings.")
                            .foregroundStyle(theme.secondaryText)
                    }
                } else {
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("This week").font(.headline)
                            Text("\(model.summary.windDownsThisWeek) of \(model.summary.weeklyGoal) wind-downs")
                                .font(.title2.weight(.semibold))
                            ProgressView(value: Double(min(model.summary.windDownsThisWeek, model.summary.weeklyGoal)),
                                         total: Double(model.summary.weeklyGoal))
                                .tint(theme.accent)
                            Text("Missed days are fine. Your path only moves forward.")
                                .font(.footnote)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(model.stageName).font(.headline)
                            JourneyPath(stage: model.summary.journeyStage)
                            Text("\(model.summary.totalWindDowns) wind-downs so far")
                                .font(.footnote)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                    if !model.recent.isEmpty {
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recently").font(.headline)
                                ForEach(model.recent) { item in
                                    HStack {
                                        Text(item.title)
                                        Spacer()
                                        Text(item.completedAt, format: .dateTime.month().day())
                                            .foregroundStyle(theme.secondaryText)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Journey")
        .onAppear { model.refresh() }
    }
}

struct JourneyPath: View {
    @Environment(\.theme) private var theme
    let stage: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                Circle()
                    .fill(i <= stage ? theme.accent : theme.accent.opacity(0.2))
                    .frame(width: 18, height: 18)
                if i < 6 {
                    Rectangle()
                        .fill(i < stage ? theme.accent : theme.accent.opacity(0.2))
                        .frame(height: 3)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Journey stage \(stage) of 6")
    }
}
```

`App/Stillmoon/Features/Settings/SettingsView.swift`:
```swift
import SwiftUI
import StillmoonCore

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    var body: some View {
        @Bindable var settings = env.settings
        NavigationStack {
            Form {
                Section("Your goal") {
                    Picker("Goal", selection: $settings.settings.goal) {
                        ForEach(Goal.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                }
                Section {
                    Toggle("Use my bedtime and wake time", isOn: Binding(
                        get: { settings.settings.bedtime != nil },
                        set: { on in
                            settings.settings.bedtime = on ? ClockTime(hour: 22, minute: 30) : nil
                            settings.settings.wakeTime = on ? ClockTime(hour: 7, minute: 0) : nil
                        }))
                    if let bedtime = settings.settings.bedtime, let wake = settings.settings.wakeTime {
                        DatePicker("Bedtime", selection: clockBinding(bedtime) { settings.settings.bedtime = $0 },
                                   displayedComponents: .hourAndMinute)
                        DatePicker("Wake time", selection: clockBinding(wake) { settings.settings.wakeTime = $0 },
                                   displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Schedule")
                } footer: {
                    Text("Night mode starts an hour before bedtime. Without times, it runs from 9pm to 7am.")
                }
                Section("Progress") {
                    Stepper("Weekly goal: \(settings.settings.weeklyGoal) wind-downs",
                            value: $settings.settings.weeklyGoal, in: 1...7)
                    Toggle("Hide progress", isOn: $settings.settings.hideProgress)
                }
                Section("Night mode") {
                    Picker("Night mode", selection: $settings.settings.nightModeOverride) {
                        Text("Automatic").tag(NightModeOverride.automatic)
                        Text("Always on").tag(NightModeOverride.on)
                        Text("Off").tag(NightModeOverride.off)
                    }
                }
                Section {
                    Button("Delete all my data on this iPhone", role: .destructive) { confirmingDelete = true }
                } footer: {
                    Text("Removes your nights, check-ins, saved items and progress from this iPhone.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete all your data on this iPhone?", isPresented: $confirmingDelete,
                                titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) { env.deleteAllLocalData() }
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    private func clockBinding(_ value: ClockTime, set: @escaping (ClockTime) -> Void) -> Binding<Date> {
        Binding(get: { value.date(on: .now, calendar: .current) },
                set: { set(ClockTime(of: $0, calendar: .current)) })
    }
}
```

Add to `AppEnvironment` (in `AppEnvironment.swift`):
```swift
    /// Deletes this owner's local records and resets preferences, keeping onboarding done.
    func deleteAllLocalData() {
        store.deleteAllData()
        settings.reset()
        settings.settings.hasOnboarded = true
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `scripts/test-app.sh -only-testing:StillmoonTests`
Expected: `JourneyModelTests` (3) pass; earlier suites pass.

- [ ] **Step 5: Commit**

```bash
git add App
git commit -m "feat(app): journey progress and settings"
```

---

### Task 8: Today

**Files:**
- Create: `App/Stillmoon/Features/Today/TodayModel.swift`, `App/Stillmoon/Features/Today/TodayView.swift`
- Test: `App/StillmoonTests/TodayModelTests.swift`

**Interfaces:**
- Consumes: `LocalStore`, `SettingsStore`, `ContentCatalog`, `JournalEntry`, `AppEnvironment` (`settings`, `sessionActive`, `playerRequest`), `Route`, `CheckInSheet`, `JournalEntryForm`, `SettingsView`, `Card`, `Theme`, `Format`; Core `RecommendationEngine`, `RecommendationInput`, `ProgressCalculator`, `ReferralSignals`, `CheckIn`, `FeedbackRating`, `RecommendationFeedback`, `ContentKind`.
- Produces:
  - `struct ResolvedRecommendation: Identifiable, Hashable { itemID: String; kind: ContentKind; title: String; reason: String; id: String; route: Route }`
  - `@Observable final class TodayModel { init(store:settings:catalog:now:calendar:); greeting; todayCheckIn; lastNight: JournalEntry?; recommendations: [ResolvedRecommendation]; progress: ProgressSummary; showsDifficultyCard: Bool; awakeAtNightExercise: Exercise?; hideProgress: Bool; refresh(); saveCheckIn(_:); saveJournalEntry(_:); rate(_:_:); static func greeting(hour:) -> String; static let doctorArticleID = "talk-to-a-doctor" }`
  - `TodayView(model:)`

- [ ] **Step 1: Write the failing tests**

`App/StillmoonTests/TodayModelTests.swift`:
```swift
import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct TodayModelTests {
    let now = TestEnv.d(2026, 10, 2, 9)

    func make(goal: Goal = .unwind) throws -> (TodayModel, LocalStore) {
        let store = try TestEnv.store()
        let settings = TestEnv.settings()
        settings.settings.goal = goal
        let model = TodayModel(store: store, settings: settings, catalog: TestEnv.catalog,
                               now: { now }, calendar: TestEnv.cal)
        return (model, store)
    }

    @Test(arguments: [(6, "Good morning"), (13, "Good afternoon"), (19, "Good evening"), (23, "It's late. Go gently."), (3, "It's late. Go gently.")])
    func greeting(hour: Int, text: String) {
        #expect(TodayModel.greeting(hour: hour) == text)
    }

    @Test func noDataGivesGoalBasedSuggestions() throws {
        let (m, _) = try make(goal: .unwind)
        m.refresh()
        #expect(m.recommendations.map(\.itemID) == ["breath", "scan"])
        #expect(m.recommendations.allSatisfy { $0.reason == RecommendationEngine.Reason.goal })
        #expect(m.recommendations.first?.title == "Gentle breathing")
        #expect(m.recommendations.first?.route == .exercise("breath"))
        #expect(m.lastNight == nil)
        #expect(m.todayCheckIn == nil)
    }

    @Test func wokeCheckInLeadsWithAwakeExercise() throws {
        let (m, _) = try make(goal: .consistency)
        m.saveCheckIn(CheckIn(date: now, restedness: 2, wokeDuringNight: true))
        #expect(m.recommendations.first?.itemID == "awake")
        #expect(m.recommendations.first?.reason == "You mentioned being awake during the night.")
        #expect(m.recommendations.dropFirst().first?.route == .article("steady-bedtime"))
    }

    @Test func secondCheckInSameDayUpdates() throws {
        let (m, store) = try make()
        m.saveCheckIn(CheckIn(date: now, restedness: 2, tenseAtBedtime: true))
        m.saveCheckIn(CheckIn(date: now.addingTimeInterval(600), restedness: 4))
        #expect(store.checkIns().count == 1)
        #expect(m.todayCheckIn?.restedness == 4)
        #expect(m.recommendations.first?.reason == RecommendationEngine.Reason.goal)
    }

    @Test func unwantedSuggestionDisappears() throws {
        let (m, _) = try make(goal: .unwind)
        m.refresh()
        m.rate("breath", .unwanted)
        #expect(m.recommendations.map(\.itemID) == ["scan"])
    }

    @Test func lastNightIsThisMorningsEntryOnly() throws {
        let (m, store) = try make()
        store.saveJournalEntry(JournalEntry(bedtime: TestEnv.d(2026, 9, 29, 23), wakeTime: TestEnv.d(2026, 9, 30, 7)))
        m.refresh()
        #expect(m.lastNight == nil)
        let tonight = JournalEntry(bedtime: TestEnv.d(2026, 10, 1, 23), wakeTime: TestEnv.d(2026, 10, 2, 7))
        m.saveJournalEntry(tonight)
        #expect(m.lastNight == tonight)
    }

    @Test func progressAndDifficultyCard() throws {
        let (m, store) = try make()
        store.addCompletion(ExerciseCompletion(exerciseID: "breath", category: .windDown, completedAt: TestEnv.d(2026, 10, 1, 22)))
        m.saveCheckIn(CheckIn(date: now, restedness: 2, persistentDifficulty: true))
        #expect(m.progress.windDownsThisWeek == 1)
        #expect(m.showsDifficultyCard)
    }

    @Test func awakeAtNightExerciseComesFromCatalog() throws {
        let (m, _) = try make()
        #expect(m.awakeAtNightExercise?.id == "awake")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/TodayModelTests`
Expected: build FAILS with "cannot find 'TodayModel' in scope".

- [ ] **Step 3: Implement the model**

`App/Stillmoon/Features/Today/TodayModel.swift`:
```swift
import Foundation
import Observation
import StillmoonCore

struct ResolvedRecommendation: Identifiable, Hashable {
    let itemID: String
    let kind: ContentKind
    let title: String
    let reason: String
    var id: String { itemID }
    var route: Route { kind == .exercise ? .exercise(itemID) : .article(itemID) }
}

@Observable final class TodayModel {
    static let doctorArticleID = "talk-to-a-doctor"
    /// A journal entry counts as "last night" if its wake time is within this window.
    static let lastNightWindow: TimeInterval = 20 * 3600

    @ObservationIgnored private let store: LocalStore
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let catalog: ContentCatalog
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let calendar: Calendar

    private(set) var greeting = ""
    private(set) var todayCheckIn: CheckIn?
    private(set) var lastNight: JournalEntry?
    private(set) var recommendations: [ResolvedRecommendation] = []
    private(set) var progress = ProgressSummary(windDownsThisWeek: 0, weeklyGoal: 3, goalMet: false,
                                                totalWindDowns: 0, journeyStage: 0)
    private(set) var showsDifficultyCard = false

    init(store: LocalStore, settings: SettingsStore, catalog: ContentCatalog,
         now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.store = store
        self.settings = settings
        self.catalog = catalog
        self.clock = now
        self.calendar = calendar
    }

    var awakeAtNightExercise: Exercise? { catalog.exercises.first { $0.category == .awakeAtNight } }
    var hideProgress: Bool { settings.settings.hideProgress }

    static func greeting(hour: Int) -> String {
        switch hour {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "It's late. Go gently."
        }
    }

    func refresh() {
        let now = clock()
        greeting = Self.greeting(hour: calendar.component(.hour, from: now))
        todayCheckIn = store.todayCheckIn(now: now, calendar: calendar)

        let entries = store.journalEntries()
        lastNight = entries
            .filter { $0.wakeTime <= now && now.timeIntervalSince($0.wakeTime) <= Self.lastNightWindow }
            .max { $0.wakeTime < $1.wakeTime }

        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let input = RecommendationInput(
            goal: settings.settings.goal,
            todayCheckIn: todayCheckIn,
            recentBedtimes: entries.map(\.bedtime).filter { $0 >= weekAgo && $0 <= now },
            feedback: store.feedback(),
            catalog: catalog.catalogItems)
        recommendations = RecommendationEngine.recommend(input, calendar: calendar).compactMap { rec in
            guard let title = catalog.title(for: rec.itemID) else { return nil }
            let kind: ContentKind = catalog.exercise(id: rec.itemID) != nil ? .exercise : .article
            return ResolvedRecommendation(itemID: rec.itemID, kind: kind, title: title, reason: rec.reason)
        }

        progress = ProgressCalculator.summary(completions: store.completions(), weeklyGoal: settings.settings.weeklyGoal,
                                              now: now, calendar: calendar)
        showsDifficultyCard = ReferralSignals.showsDifficultyCard(todayCheckIn: todayCheckIn)
    }

    /// One check-in per day: a second save today updates the first.
    func saveCheckIn(_ checkIn: CheckIn) {
        var checkIn = checkIn
        if let existing = todayCheckIn ?? store.todayCheckIn(now: clock(), calendar: calendar) {
            checkIn.id = existing.id
        }
        store.saveCheckIn(checkIn)
        refresh()
    }

    func saveJournalEntry(_ entry: JournalEntry) {
        store.saveJournalEntry(entry)
        refresh()
    }

    func rate(_ itemID: String, _ rating: FeedbackRating) {
        store.addFeedback(RecommendationFeedback(itemID: itemID, rating: rating, at: clock()))
        refresh()
    }
}
```

- [ ] **Step 4: Implement the view**

`App/Stillmoon/Features/Today/TodayView.swift`:
```swift
import SwiftUI
import StillmoonCore

struct TodayView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    let model: TodayModel
    @State private var showingCheckIn = false
    @State private var showingJournal = false
    @State private var showingSettings = false
    @State private var showEverythingAtNight = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(model.greeting)
                    .font(.largeTitle.weight(.semibold))
                    .accessibilityIdentifier("greeting")
                if theme.isNight && !showEverythingAtNight {
                    nightContent
                } else {
                    dayContent
                }
            }
            .foregroundStyle(theme.text)
            .padding()
        }
        .background(theme.background.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingSettings = true } label: { Image(systemName: "person.crop.circle") }
                    .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showingCheckIn, onDismiss: model.refresh) {
            CheckInSheet(existing: model.todayCheckIn) { model.saveCheckIn($0) }
        }
        .sheet(isPresented: $showingJournal, onDismiss: model.refresh) {
            JournalEntryForm { model.saveJournalEntry($0) }
        }
        .sheet(isPresented: $showingSettings, onDismiss: model.refresh) {
            SettingsView()
        }
        .onAppear { model.refresh() }
    }

    // MARK: Night: one card, large controls, nothing to track (PRD §7).

    @ViewBuilder private var nightContent: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Awake at night?").font(.title2.weight(.semibold))
                Text("A few quiet minutes can help you settle. There's nothing to track.")
                    .foregroundStyle(theme.secondaryText)
                if let exercise = model.awakeAtNightExercise {
                    Button {
                        env.playerRequest = PlayerRequest(exerciseID: exercise.id)
                    } label: {
                        Label(exercise.title, systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(theme.accent)
                }
            }
        }
        Button("Show everything") { showEverythingAtNight = true }
            .font(.footnote)
            .foregroundStyle(theme.secondaryText)
    }

    // MARK: Day

    @ViewBuilder private var dayContent: some View {
        lastNightCard
        checkInCard
        if model.showsDifficultyCard {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("If sleep has been hard for weeks, it can help to talk with a doctor.")
                    NavigationLink("When to talk to a doctor", value: Route.article(TodayModel.doctorArticleID))
                }
            }
        }
        if let first = model.recommendations.first {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Suggested for you").font(.caption).foregroundStyle(theme.secondaryText)
                        Spacer()
                        feedbackMenu(first.itemID)
                    }
                    NavigationLink(value: first.route) {
                        Text(first.title).font(.title3.weight(.semibold))
                    }
                    Text(first.reason).font(.subheadline).foregroundStyle(theme.secondaryText)
                }
            }
        }
        if model.recommendations.count > 1 {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Also for you").font(.headline)
                    ForEach(model.recommendations.dropFirst()) { rec in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                NavigationLink(rec.title, value: rec.route)
                                Text(rec.reason).font(.caption).foregroundStyle(theme.secondaryText)
                            }
                            Spacer()
                            feedbackMenu(rec.itemID)
                        }
                    }
                }
            }
        }
        if !model.hideProgress {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This week").font(.headline)
                    Text("\(model.progress.windDownsThisWeek) of \(model.progress.weeklyGoal) wind-downs")
                    ProgressView(value: Double(min(model.progress.windDownsThisWeek, model.progress.weeklyGoal)),
                                 total: Double(model.progress.weeklyGoal))
                        .tint(theme.accent)
                }
            }
        }
    }

    @ViewBuilder private var lastNightCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Last night").font(.headline)
                if let entry = model.lastNight {
                    Text("You recorded \(Format.duration(minutes: entry.asleepMinutes)) in bed")
                        .font(.title3)
                    Text("\(entry.bedtime.formatted(date: .omitted, time: .shortened)) to \(entry.wakeTime.formatted(date: .omitted, time: .shortened))")
                        .foregroundStyle(theme.secondaryText)
                } else {
                    Text("Nothing recorded for last night yet.")
                        .foregroundStyle(theme.secondaryText)
                    Button("Add last night") { showingJournal = true }
                }
            }
        }
    }

    @ViewBuilder private var checkInCard: some View {
        Card {
            if let checkIn = model.todayCheckIn {
                HStack {
                    Text("You felt \(checkIn.restedness) of 5 rested")
                    Spacer()
                    Button("Edit") { showingCheckIn = true }
                }
            } else {
                Button { showingCheckIn = true } label: {
                    Label("How do you feel?", systemImage: "sun.haze")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func feedbackMenu(_ itemID: String) -> some View {
        Menu {
            Button("Helpful") { model.rate(itemID, .helpful) }
            Button("Not relevant") { model.rate(itemID, .irrelevant) }
            Button("Don't show this again", role: .destructive) { model.rate(itemID, .unwanted) }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Rate this suggestion")
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `scripts/test-app.sh -only-testing:StillmoonTests`
Expected: `TodayModelTests` (7 tests, 5 greeting cases) pass; earlier suites pass.

- [ ] **Step 6: Commit**

```bash
git add App
git commit -m "feat(app): Today screen with check-in, recommendations and night card"
```

---

### Task 9: Onboarding and app wiring

**Files:**
- Create: `App/Stillmoon/Features/Onboarding/OnboardingModel.swift`, `App/Stillmoon/Features/Onboarding/OnboardingView.swift`, `App/Stillmoon/Root/RootView.swift`
- Modify: `App/Stillmoon/StillmoonApp.swift`, `App/StillmoonUITests/LaunchTests.swift`
- Test: `App/StillmoonTests/OnboardingModelTests.swift`

**Interfaces:**
- Consumes: everything above.
- Produces:
  - `@Observable final class OnboardingModel { enum Step: Int, CaseIterable { welcome, goal, schedule, privacy, firstExercise }; init(settings:); step; goal; bedtime: ClockTime; wakeTime: ClockTime; canGoBack; next(); back(); chooseGoal(_:); skipSchedule(); finish(); static let firstExerciseID = "gentle-breathing" }`
  - `OnboardingView(settings:)`, `RootView`, `MainTabs(env:)`

- [ ] **Step 1: Write the failing tests**

`App/StillmoonTests/OnboardingModelTests.swift`:
```swift
import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct OnboardingModelTests {
    @Test func fullPathSavesGoalAndSchedule() {
        let settings = TestEnv.settings()
        let m = OnboardingModel(settings: settings)
        #expect(m.step == .welcome)
        #expect(!m.canGoBack)
        m.next()
        m.chooseGoal(.nightWaking)
        #expect(m.step == .schedule)
        m.bedtime = ClockTime(hour: 23, minute: 30)
        m.wakeTime = ClockTime(hour: 6, minute: 45)
        m.next()
        #expect(m.step == .privacy)
        m.next()
        #expect(m.step == .firstExercise)
        m.finish()
        #expect(settings.settings.goal == .nightWaking)
        #expect(settings.settings.bedtime == ClockTime(hour: 23, minute: 30))
        #expect(settings.settings.wakeTime == ClockTime(hour: 6, minute: 45))
        #expect(settings.settings.hasOnboarded)
    }

    @Test func skippingScheduleLeavesDefaults() {
        let settings = TestEnv.settings()
        let m = OnboardingModel(settings: settings)
        m.next()
        m.chooseGoal(.unwind)
        m.skipSchedule()
        #expect(m.step == .privacy)
        #expect(settings.settings.bedtime == nil)
        #expect(settings.settings.wakeTime == nil)
    }

    @Test func backMovesOneStepAndStopsAtWelcome() {
        let m = OnboardingModel(settings: TestEnv.settings())
        m.next()
        m.next()
        #expect(m.step == .schedule)
        m.back()
        #expect(m.step == .goal)
        m.back()
        m.back()
        #expect(m.step == .welcome)
    }

    @Test func firstExerciseExistsInBundledCatalog() throws {
        #expect(try ContentStore.loadBundled().exercise(id: OnboardingModel.firstExerciseID) != nil)
    }
}
```

Replace `App/StillmoonUITests/LaunchTests.swift`:
```swift
import XCTest

final class LaunchTests: XCTestCase {
    @MainActor
    func testOnboardingReachesTodayAndExercises() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        app.buttons["Get started"].tap()
        app.buttons["Unwind before bed"].tap()
        app.buttons["Skip for now"].tap()
        app.buttons["Continue"].tap()
        app.buttons["Go to Today"].tap()

        XCTAssertTrue(app.staticTexts["greeting"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Exercises"].tap()
        XCTAssertTrue(app.staticTexts["Gentle breathing"].waitForExistence(timeout: 5))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/OnboardingModelTests`
Expected: build FAILS with "cannot find 'OnboardingModel' in scope".

- [ ] **Step 3: Implement onboarding**

`App/Stillmoon/Features/Onboarding/OnboardingModel.swift`:
```swift
import Foundation
import Observation
import StillmoonCore

/// PRD §5 onboarding. Sign-in (Plan 5), Apple Health (Plan 3) and microphone (Plan 4) steps are added later.
@Observable final class OnboardingModel {
    enum Step: Int, CaseIterable {
        case welcome, goal, schedule, privacy, firstExercise
    }

    static let firstExerciseID = "gentle-breathing"

    @ObservationIgnored private let settings: SettingsStore
    private(set) var step: Step = .welcome
    var goal: Goal = .unwind
    var bedtime = ClockTime(hour: 22, minute: 30)
    var wakeTime = ClockTime(hour: 7, minute: 0)

    init(settings: SettingsStore) {
        self.settings = settings
        goal = settings.settings.goal
    }

    var canGoBack: Bool { step != .welcome }

    func next() {
        if step == .schedule {
            settings.settings.bedtime = bedtime
            settings.settings.wakeTime = wakeTime
        }
        move(by: 1)
    }

    func back() { move(by: -1) }

    func chooseGoal(_ goal: Goal) {
        self.goal = goal
        settings.settings.goal = goal
        move(by: 1)
    }

    func skipSchedule() {
        settings.settings.bedtime = nil
        settings.settings.wakeTime = nil
        move(by: 1)
    }

    func finish() {
        settings.settings.hasOnboarded = true
    }

    private func move(by offset: Int) {
        let raw = min(max(step.rawValue + offset, 0), Step.allCases.count - 1)
        step = Step(rawValue: raw)!
    }
}
```

`App/Stillmoon/Features/Onboarding/OnboardingView.swift`:
```swift
import SwiftUI
import StillmoonCore

struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    @State private var model: OnboardingModel

    init(settings: SettingsStore) {
        _model = State(initialValue: OnboardingModel(settings: settings))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if model.canGoBack {
                Button { model.back() } label: { Label("Back", systemImage: "chevron.left") }
            }
            Spacer()
            switch model.step {
            case .welcome:
                Text("Stillmoon").font(.largeTitle.weight(.semibold))
                Text("Understand your nights. Find a calmer next step.").font(.title2)
                primary("Get started") { model.next() }
            case .goal:
                Text("What would help most?").font(.title.weight(.semibold))
                ForEach(Goal.allCases, id: \.self) { goal in
                    Button { model.chooseGoal(goal) } label: {
                        Text(goal.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                }
            case .schedule:
                Text("When do you usually sleep?").font(.title.weight(.semibold))
                Text("This sets when Stillmoon turns calm and dim. You can change it any time.")
                    .foregroundStyle(theme.secondaryText)
                DatePicker("Bedtime", selection: clock($model.bedtime), displayedComponents: .hourAndMinute)
                DatePicker("Wake time", selection: clock($model.wakeTime), displayedComponents: .hourAndMinute)
                primary("Continue") { model.next() }
                Button("Skip for now") { model.skipSchedule() }
            case .privacy:
                Text("Your nights stay yours").font(.title.weight(.semibold))
                VStack(alignment: .leading, spacing: 12) {
                    Label("Your journal and check-ins stay on this iPhone.", systemImage: "iphone")
                    Label("Nothing you write is read or analysed.", systemImage: "text.badge.xmark")
                    Label("You can delete everything from Settings at any time.", systemImage: "trash")
                }
                primary("Continue") { model.next() }
            case .firstExercise:
                Text("Try a few calm minutes?").font(.title.weight(.semibold))
                Text("Gentle breathing takes about 5 minutes. No sensors needed.")
                    .foregroundStyle(theme.secondaryText)
                primary("Start gentle breathing") {
                    model.finish()
                    env.playerRequest = PlayerRequest(exerciseID: OnboardingModel.firstExerciseID)
                }
                Button("Go to Today") { model.finish() }
            }
            Spacer()
        }
        .padding(24)
        .foregroundStyle(theme.text)
        .tint(theme.accent)
        .background(theme.background.ignoresSafeArea())
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func clock(_ binding: Binding<ClockTime>) -> Binding<Date> {
        Binding(get: { binding.wrappedValue.date(on: .now, calendar: .current) },
                set: { binding.wrappedValue = ClockTime(of: $0, calendar: .current) })
    }
}
```

- [ ] **Step 4: Wire the root**

`App/Stillmoon/Root/RootView.swift`:
```swift
import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        // Re-evaluates night mode every minute (PRD §7).
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let night = env.settings.isNight(at: context.date, calendar: .current, sessionActive: env.sessionActive)
            let theme: Theme = night ? .night : .day
            Group {
                if env.settings.settings.hasOnboarded {
                    MainTabs(env: env)
                } else {
                    OnboardingView(settings: env.settings)
                }
            }
            .environment(\.theme, theme)
            .tint(theme.accent)
            .preferredColorScheme(night ? .dark : .light)
        }
    }
}

struct MainTabs: View {
    @Environment(AppEnvironment.self) private var env
    @State private var today: TodayModel
    @State private var sleep: SleepModel
    @State private var exercises: ExercisesModel
    @State private var journey: JourneyModel

    init(env: AppEnvironment) {
        _today = State(initialValue: TodayModel(store: env.store, settings: env.settings, catalog: env.catalog))
        _sleep = State(initialValue: SleepModel(store: env.store))
        _exercises = State(initialValue: ExercisesModel(store: env.store, catalog: env.catalog))
        _journey = State(initialValue: JourneyModel(store: env.store, settings: env.settings, catalog: env.catalog))
    }

    var body: some View {
        @Bindable var env = env
        TabView {
            NavigationStack {
                TodayView(model: today)
                    .navigationDestination(for: Route.self) { RouteDestination(route: $0) }
            }
            .tabItem { Label("Today", systemImage: "sun.horizon") }

            NavigationStack {
                SleepView(model: sleep)
            }
            .tabItem { Label("Sleep", systemImage: "bed.double") }

            NavigationStack {
                ExercisesView(model: exercises)
                    .navigationDestination(for: Route.self) { RouteDestination(route: $0) }
            }
            .tabItem { Label("Exercises", systemImage: "leaf") }

            NavigationStack {
                JourneyView(model: journey)
            }
            .tabItem { Label("Journey", systemImage: "map") }
        }
        .fullScreenCover(item: $env.playerRequest, onDismiss: {
            today.refresh()
            journey.refresh()
        }) { request in
            if let exercise = env.catalog.exercise(id: request.exerciseID) {
                PlayerView(model: PlayerModel(exercise: exercise, store: env.store))
            }
        }
    }
}
```

Replace `App/Stillmoon/StillmoonApp.swift`:
```swift
import SwiftUI

@main
struct StillmoonApp: App {
    @State private var env = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env)
        }
    }
}
```

- [ ] **Step 5: Run every test, including the UI smoke test**

Run: `scripts/test-app.sh`
Expected: all unit suites pass (`OnboardingModelTests` 4 new); `LaunchTests.testOnboardingReachesTodayAndExercises` passes; `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add App
git commit -m "feat(app): onboarding, tab navigation and app wiring"
```
