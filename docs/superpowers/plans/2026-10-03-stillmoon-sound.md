# Stillmoon Sound Detection Implementation Plan (Plan 4 of 7)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An optional, user-started overnight sound session that classifies snoring-like, speech-like and cough-like sounds on the iPhone, stores only labels/times/confidence, shows them on a separate lane in the night detail where the user can correct each one, raises the one-time snoring note, and is gated by a user setting, microphone permission and a feature flag.

**Architecture:** Pure event-merging logic (`SoundEventDebouncer`) lives in `StillmoonCore`. The app has a `SoundDetecting` protocol with a real `SoundAnalysisDetector` (AVAudioEngine + `SNAudioStreamAnalyzer` + built-in classifier `.version1`) and a scripted `FakeSoundDetector` (`-fake-sound`). A `@MainActor` `SoundSessionController` owns session state, permission, battery warning and persistence; `AppEnvironment.sessionActive` derives from it so night mode turns on during a session. Sessions and events are new SwiftData models in the "health" configuration, added through a versioned schema migration (V1 → V2).

**Tech Stack:** SoundAnalysis, AVFAudio (`AVAudioEngine`, `AVAudioSession`, `AVAudioApplication`), SwiftData `VersionedSchema` + `SchemaMigrationPlan`, Swift Charts, SwiftUI, Swift Testing, XCTest UI tests.

**Spec:** `docs/PRD-v1.2.md` (FR-06, sound detection launch gate, §5 onboarding step 6, §5 "During the night", §7 Sound session screen and Sleep "sound-event markers on a separate lane", §9 data policy and safety language, FR-18).

## Global Constraints

- Everything in Plans 2–3 still applies (iOS 17, iPhone, main-actor default isolation, no dependencies, `import Foundation` first in tests, XcodeGen, tolerant `AppSettings` decoding for new keys).
- Labels are exactly `snoringLike`, `speechLike`, `coughLike` (Core `SoundLabel`), mapped from classifier identifiers `"snoring"`, `"speech"`, `"cough"`. No other classifications are stored.
- **No audio is ever recorded or stored.** Only label, time, confidence and the user's correction.
- Display names (verbatim): "Snoring-like sound", "Speech-like sound", "Cough-like sound". Never say "you snored", "you talked", or anything about mood, anxiety or health from a sound (PRD §9, §11).
- Corrections (verbatim menu titles): "This was me" (`.wasMe`), "Someone else" (`.someoneElse`), "Not correct" (`.incorrect`).
- `NSMicrophoneUsageDescription` (verbatim): "Stillmoon listens for snoring, speech and coughing on this iPhone during a sleep session you start. Sound is analyzed on the device and never recorded or stored."
- Background audio: `UIBackgroundModes` contains `audio` so a session keeps running with the screen locked.
- Sessions start only when the user taps Start. Nothing ever notifies, plays sound or vibrates because of a detection (PRD principle 1).
- Battery warning: when not charging and below 30% at session start.
- A session is available only when `flags.soundDetection` is true AND `settings.soundDetectionEnabled` is true; the flag is local (default true) until Plan 5 makes it remote.
- Event merging: ignore observations below confidence 0.6; observations of the same label less than 30 s after the previous one extend the same event.
- Sound events are night data: they live in the "health" SwiftData configuration (iCloud later), never on the server.

## Review Focus

1. **App killed mid-session** (crash, force quit, phone restart): the next launch closes the orphaned session so the app is not stuck in night mode and the events already saved still show. Pinned in Task 2 (`closeOrphanedSessionsEndsOpenSessions`) and Task 4 (`launchRecoversOrphanedSession`).
2. **Existing users' data survives the schema upgrade** (V1 store on disk → V2). Pinned in Task 2 (`migratesV1StoreOnDisk`).
3. **Microphone permission denied** or setting off or flag off: Start is not offered / fails gracefully with a plain message, never a crash or a silent dead session. Pinned in Task 4 (`startFailsWhenPermissionDenied`, `notAvailableWhenFlagOff`).
4. **A burst of observations** (snoring every 1.5 s for 10 minutes) becomes one event, not hundreds; a 2-minute gap starts a new one. Pinned in Task 1 (`burstBecomesOneEvent`, `gapStartsNewEvent`).
5. **Events between noon and 6 pm** (a nap session) don't vanish: they show on the row of the night window they fall in, or, if none, they are still counted on Today's session summary. Pinned in Task 6 (`eventsOutsideNightWindowsAreNotDropped`), which assigns them to the following morning.

---

## File Structure

```
StillmoonCore/Sources/StillmoonCore/SoundEvents.swift        # SoundEventDebouncer, SoundObservationInput, SoundLabel(classifierIdentifier:) (Task 1)
StillmoonCore/Tests/StillmoonCoreTests/SoundEventsTests.swift
App/Stillmoon/Persistence/Records.swift                      # + SoundSessionRecord, SoundEventRecord (Task 2)
App/Stillmoon/Persistence/LocalStore.swift                   # schema V2 + migration plan, sound methods (Task 2)
App/Stillmoon/Sound/SoundDetecting.swift                     # protocol, SoundObservation, FakeSoundDetector (Task 3)
App/Stillmoon/Sound/SoundAnalysisDetector.swift              # real detector (Task 3)
App/Stillmoon/Sound/DeviceServices.swift                     # MicrophonePermission, BatteryReading + fakes (Task 3)
App/Stillmoon/Sound/SoundSessionController.swift             # (Task 4)
App/Stillmoon/Info.plist                                     # UIBackgroundModes audio (Task 3)
App/Stillmoon/Features/Sound/SoundSessionView.swift          # (Task 5)
App/Stillmoon/Features/Sleep/*                               # sound lane + corrections (Task 6)
App/Stillmoon/Features/Today/*                               # start session, snoring note (Tasks 5, 6)
App/Stillmoon/Features/Onboarding/*, Settings/*              # microphone step, settings (Task 5)
```

---

### Task 1: Event merging in Core

**Files:**
- Create: `StillmoonCore/Sources/StillmoonCore/SoundEvents.swift`
- Test: `StillmoonCore/Tests/StillmoonCoreTests/SoundEventsTests.swift`

**Interfaces:**
- Consumes: Core `SoundLabel`, `SoundEvent`, `SoundCorrection`.
- Produces: `extension SoundLabel { public init?(classifierIdentifier: String) }`; `public struct SoundObservationInput: Sendable, Equatable { label: SoundLabel; confidence: Double; time: Date; init(label:confidence:time:) }`; `public struct SoundEventDebouncer: Sendable { public static let minimumConfidence = 0.6; public static let mergeWindow: TimeInterval = 30; public init(); public mutating func add(_:) -> [SoundEvent]; public mutating func flush() -> [SoundEvent] }`.

Semantics: `add` ignores inputs below `minimumConfidence`. For the input's label, if an event is open and `input.time - lastSeen <= mergeWindow`, it extends it (lastSeen = input.time, confidence = max). Otherwise the open event of that label (if any) is closed and a new one opened at `input.time`. Before handling the input, every open event (any label) whose `lastSeen < input.time - mergeWindow` is closed. `add` returns the events it closed, sorted by `at`. `flush` closes and returns all open events sorted by `at`. Emitted events have `at` = first observation time, `confidence` = max seen, `correction` = `.none`, a fresh UUID.

- [ ] **Step 1: Write the failing tests**

`StillmoonCore/Tests/StillmoonCoreTests/SoundEventsTests.swift`:
```swift
import Foundation
import Testing
@testable import StillmoonCore

struct SoundEventsTests {
    let t0 = T.d(2026, 10, 2, 2)

    func obs(_ label: SoundLabel, _ seconds: Double, _ confidence: Double = 0.8) -> SoundObservationInput {
        SoundObservationInput(label: label, confidence: confidence, time: t0.addingTimeInterval(seconds))
    }

    @Test func mapsClassifierIdentifiers() {
        #expect(SoundLabel(classifierIdentifier: "snoring") == .snoringLike)
        #expect(SoundLabel(classifierIdentifier: "speech") == .speechLike)
        #expect(SoundLabel(classifierIdentifier: "cough") == .coughLike)
        #expect(SoundLabel(classifierIdentifier: "dog_bark") == nil)
    }

    @Test func lowConfidenceIsIgnored() {
        var d = SoundEventDebouncer()
        #expect(d.add(obs(.snoringLike, 0, 0.59)).isEmpty)
        #expect(d.flush().isEmpty)
    }

    @Test func burstBecomesOneEvent() {
        var d = SoundEventDebouncer()
        var closed: [SoundEvent] = []
        for i in 0..<400 { closed += d.add(obs(.snoringLike, Double(i) * 1.5, i == 7 ? 0.95 : 0.7)) }
        closed += d.flush()
        #expect(closed.count == 1)
        #expect(closed[0].at == t0)
        #expect(closed[0].confidence == 0.95)
        #expect(closed[0].label == .snoringLike)
        #expect(closed[0].correction == SoundCorrection.none)
    }

    @Test func gapStartsNewEvent() {
        var d = SoundEventDebouncer()
        var closed = d.add(obs(.snoringLike, 0))
        closed += d.add(obs(.snoringLike, 20))
        closed += d.add(obs(.snoringLike, 140)) // 120 s after the last one
        closed += d.flush()
        #expect(closed.map(\.at) == [t0, t0.addingTimeInterval(140)])
    }

    @Test func labelsAreIndependentAndStaleOnesClose() {
        var d = SoundEventDebouncer()
        #expect(d.add(obs(.speechLike, 0)).isEmpty)
        #expect(d.add(obs(.coughLike, 10)).isEmpty)
        // 100 s later: both open events are stale and close before the new snoring event opens.
        let closed = d.add(obs(.snoringLike, 110))
        #expect(closed.map(\.label) == [.speechLike, .coughLike])
        #expect(d.flush().map(\.label) == [.snoringLike])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd StillmoonCore && swift test --filter SoundEventsTests`
Expected: build FAILS with "cannot find 'SoundObservationInput' in scope".

- [ ] **Step 3: Implement**

`StillmoonCore/Sources/StillmoonCore/SoundEvents.swift`:
```swift
import Foundation

extension SoundLabel {
    /// Maps Apple's built-in sound classifier identifiers to the three labels Stillmoon keeps.
    public init?(classifierIdentifier: String) {
        switch classifierIdentifier {
        case "snoring": self = .snoringLike
        case "speech": self = .speechLike
        case "cough": self = .coughLike
        default: return nil
        }
    }
}

public struct SoundObservationInput: Sendable, Equatable {
    public let label: SoundLabel
    public let confidence: Double
    public let time: Date

    public init(label: SoundLabel, confidence: Double, time: Date) {
        self.label = label
        self.confidence = confidence
        self.time = time
    }
}

/// Turns a stream of classifier observations into a few events (PRD FR-06).
public struct SoundEventDebouncer: Sendable {
    public static let minimumConfidence = 0.6
    public static let mergeWindow: TimeInterval = 30

    private struct Open: Sendable {
        var event: SoundEvent
        var lastSeen: Date
    }

    private var open: [SoundLabel: Open] = [:]

    public init() {}

    /// Feeds one observation; returns the events this closed, oldest first.
    public mutating func add(_ input: SoundObservationInput) -> [SoundEvent] {
        guard input.confidence >= Self.minimumConfidence else { return [] }
        var closed: [SoundEvent] = []
        for (label, item) in open where input.time.timeIntervalSince(item.lastSeen) > Self.mergeWindow {
            closed.append(item.event)
            open[label] = nil
        }
        if var current = open[input.label] {
            current.lastSeen = input.time
            current.event.confidence = max(current.event.confidence, input.confidence)
            open[input.label] = current
        } else {
            open[input.label] = Open(event: SoundEvent(label: input.label, at: input.time, confidence: input.confidence),
                                     lastSeen: input.time)
        }
        return closed.sorted { $0.at < $1.at }
    }

    /// Closes every open event, oldest first.
    public mutating func flush() -> [SoundEvent] {
        let all = open.values.map(\.event).sorted { $0.at < $1.at }
        open.removeAll()
        return all
    }
}
```
(The dictionary is mutated after iteration ends in Swift's `for … in` over a copy; if the compiler objects, collect stale labels first, then remove.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd StillmoonCore && swift test`
Expected: all Core tests pass, including `SoundEventsTests` (5).

- [ ] **Step 5: Commit**

```bash
git add StillmoonCore
git commit -m "feat(core): merge sound classifier observations into events"
```

---

### Task 2: Sound persistence and schema migration

**Files:**
- Modify: `App/Stillmoon/Persistence/Records.swift`, `App/Stillmoon/Persistence/LocalStore.swift`
- Test: `App/StillmoonTests/SoundStoreTests.swift`

**Interfaces:**
- Consumes: Core `SoundEvent`, `SoundLabel`, `SoundCorrection`; existing `StillmoonSchemaV1`, `StillmoonSchema.makeContainer(inMemory:)`, `LocalStore`.
- Produces:
  - `@Model final class SoundSessionRecord { id: UUID; ownerID: String; startedAt: Date; endedAt: Date?; interruptions: Int }`, `@Model final class SoundEventRecord { id: UUID; ownerID: String; sessionID: UUID; labelRaw: String; at: Date; confidence: Double; correctionRaw: String; var value: SoundEvent }`
  - `enum StillmoonSchemaV2: VersionedSchema` (2.0.0, V1 models + the two), `enum StillmoonMigrationPlan: SchemaMigrationPlan` (V1 → V2 lightweight)
  - `StillmoonSchema.makeContainer(inMemory: Bool, directory: URL? = nil) throws -> ModelContainer` (directory = where on-disk stores live; nil = default)
  - `StillmoonSchema.makeV1ContainerForTesting(directory: URL) throws -> ModelContainer`
  - `LocalStore`: `startSoundSession(at: Date) -> UUID`, `endSoundSession(_ id: UUID, at: Date)`, `recordInterruption(sessionID: UUID)`, `addSoundEvents(_ events: [SoundEvent], sessionID: UUID)`, `soundEvents(from: Date, to: Date) -> [SoundEvent]` (sorted by `at`), `setCorrection(_ correction: SoundCorrection, forEvent id: UUID)`, `closeOrphanedSessions()`, `openSessionID() -> UUID?`; `deleteAllData()` also removes sound records.

- [ ] **Step 1: Write the failing tests**

`App/StillmoonTests/SoundStoreTests.swift`:
```swift
import Foundation
import SwiftData
import Testing
import StillmoonCore
@testable import Stillmoon

struct SoundStoreTests {
    @Test func storesEventsAndCorrections() throws {
        let store = try TestEnv.store()
        let session = store.startSoundSession(at: TestEnv.d(2026, 10, 1, 23))
        let e1 = SoundEvent(label: .snoringLike, at: TestEnv.d(2026, 10, 2, 2), confidence: 0.8)
        let e2 = SoundEvent(label: .speechLike, at: TestEnv.d(2026, 10, 2, 1), confidence: 0.7)
        store.addSoundEvents([e1, e2], sessionID: session)
        store.setCorrection(.someoneElse, forEvent: e2.id)
        let events = store.soundEvents(from: TestEnv.d(2026, 10, 1, 18), to: TestEnv.d(2026, 10, 2, 12))
        #expect(events.map(\.id) == [e2.id, e1.id])
        #expect(events[0].correction == .someoneElse)
        #expect(events[1].correction == SoundCorrection.none)
    }

    @Test func closeOrphanedSessionsEndsOpenSessions() throws {
        let store = try TestEnv.store()
        let session = store.startSoundSession(at: TestEnv.d(2026, 10, 1, 23))
        store.addSoundEvents([SoundEvent(label: .coughLike, at: TestEnv.d(2026, 10, 2, 3), confidence: 0.9)], sessionID: session)
        #expect(store.openSessionID() == session)
        store.closeOrphanedSessions()
        #expect(store.openSessionID() == nil)
        #expect(store.soundEvents(from: TestEnv.d(2026, 10, 1, 18), to: TestEnv.d(2026, 10, 2, 12)).count == 1)
    }

    @Test func soundDataIsOwnerScopedAndDeleted() throws {
        let container = try TestEnv.container()
        let a = try TestEnv.store(owner: "a", container: container)
        let b = try TestEnv.store(owner: "b", container: container)
        let s = a.startSoundSession(at: TestEnv.d(2026, 10, 1, 23))
        a.addSoundEvents([SoundEvent(label: .snoringLike, at: TestEnv.d(2026, 10, 2, 2), confidence: 0.8)], sessionID: s)
        #expect(b.soundEvents(from: .distantPast, to: .distantFuture).isEmpty)
        #expect(b.openSessionID() == nil)
        a.deleteAllData()
        #expect(a.soundEvents(from: .distantPast, to: .distantFuture).isEmpty)
        #expect(a.openSessionID() == nil)
    }

    @Test func migratesV1StoreOnDisk() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        do {
            let v1 = try StillmoonSchema.makeV1ContainerForTesting(directory: dir)
            let old = LocalStore(container: v1, ownerID: "a")
            old.saveCheckIn(CheckIn(date: TestEnv.d(2026, 10, 1, 8), restedness: 4))
        }
        let v2 = try StillmoonSchema.makeContainer(inMemory: false, directory: dir)
        let store = LocalStore(container: v2, ownerID: "a")
        #expect(store.checkIns().first?.restedness == 4)
        let s = store.startSoundSession(at: TestEnv.d(2026, 10, 1, 23))
        store.addSoundEvents([SoundEvent(label: .snoringLike, at: TestEnv.d(2026, 10, 2, 2), confidence: 0.8)], sessionID: s)
        #expect(store.soundEvents(from: .distantPast, to: .distantFuture).count == 1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/SoundStoreTests`
Expected: build FAILS ("value of type 'LocalStore' has no member 'startSoundSession'").

- [ ] **Step 3: Add the records**

Append to `Records.swift`:
```swift
@Model final class SoundSessionRecord {
    var id: UUID = UUID()
    var ownerID: String = ""
    var startedAt: Date = Date.distantPast
    var endedAt: Date?
    var interruptions: Int = 0

    init(ownerID: String, startedAt: Date) {
        self.ownerID = ownerID
        self.startedAt = startedAt
    }
}

@Model final class SoundEventRecord {
    var id: UUID = UUID()
    var ownerID: String = ""
    var sessionID: UUID = UUID()
    var labelRaw: String = SoundLabel.snoringLike.rawValue
    var at: Date = Date.distantPast
    var confidence: Double = 0
    var correctionRaw: String = SoundCorrection.none.rawValue

    init(ownerID: String, sessionID: UUID, event: SoundEvent) {
        self.ownerID = ownerID
        self.sessionID = sessionID
        id = event.id
        labelRaw = event.label.rawValue
        at = event.at
        confidence = event.confidence
        correctionRaw = event.correction.rawValue
    }

    var value: SoundEvent {
        SoundEvent(id: id, label: SoundLabel(rawValue: labelRaw) ?? .snoringLike, at: at, confidence: confidence,
                   correction: SoundCorrection(rawValue: correctionRaw) ?? .none)
    }
}
```

- [ ] **Step 4: Schema V2, migration plan and store methods**

In `LocalStore.swift`, keep `StillmoonSchemaV1` exactly as is and add:
```swift
enum StillmoonSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [CheckInRecord.self, JournalEntryRecord.self, CompletionRecord.self, FeedbackRecord.self,
         SavedItemRecord.self, SoundSessionRecord.self, SoundEventRecord.self]
    }
}

enum StillmoonMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [StillmoonSchemaV1.self, StillmoonSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: StillmoonSchemaV1.self, toVersion: StillmoonSchemaV2.self)]
    }
}
```
Change `StillmoonSchema.makeContainer(inMemory:)` to `makeContainer(inMemory: Bool, directory: URL? = nil)`:
- "health" configuration schema: `[CheckInRecord, JournalEntryRecord, SoundSessionRecord, SoundEventRecord]`; "account" unchanged.
- when `directory` is non-nil and not in-memory, pass `url: directory.appendingPathComponent("health.store")` / `"account.store"` to the configurations (use the `ModelConfiguration(_:schema:url:allowsSave:cloudKitDatabase:)` initializer).
- build with `ModelContainer(for: Schema(versionedSchema: StillmoonSchemaV2.self), migrationPlan: StillmoonMigrationPlan.self, configurations: [health, account])`.
Add `static func makeV1ContainerForTesting(directory: URL) throws -> ModelContainer` that builds the V1 layout (health = check-ins + journal, account = the three event types) at the same two URLs with `Schema(versionedSchema: StillmoonSchemaV1.self)`.
If SwiftData rejects a migration plan across two configurations, keep the two configurations, find the working variant (e.g. one migration plan applied per configuration or relying on SwiftData's automatic lightweight migration for added entities), make `migratesV1StoreOnDisk` pass, and explain exactly what you did.

`LocalStore` additions (all owner-scoped, same fetch/save helpers):
```swift
    // MARK: Sound sessions

    func startSoundSession(at date: Date) -> UUID {
        let record = SoundSessionRecord(ownerID: ownerID, startedAt: date)
        context.insert(record)
        save()
        return record.id
    }

    func endSoundSession(_ id: UUID, at date: Date) {
        let owner = ownerID
        fetch(FetchDescriptor<SoundSessionRecord>(predicate: #Predicate { $0.ownerID == owner && $0.id == id })).first?.endedAt = date
        save()
    }

    func recordInterruption(sessionID id: UUID) {
        let owner = ownerID
        if let record = fetch(FetchDescriptor<SoundSessionRecord>(predicate: #Predicate { $0.ownerID == owner && $0.id == id })).first {
            record.interruptions += 1
        }
        save()
    }

    func openSessionID() -> UUID? {
        let owner = ownerID
        return fetch(FetchDescriptor<SoundSessionRecord>(predicate: #Predicate { $0.ownerID == owner && $0.endedAt == nil })).first?.id
    }

    /// Ends sessions left open by a crash or force quit, at their last event (or start) time.
    func closeOrphanedSessions() {
        let owner = ownerID
        for session in fetch(FetchDescriptor<SoundSessionRecord>(predicate: #Predicate { $0.ownerID == owner && $0.endedAt == nil })) {
            let sid = session.id
            let last = fetch(FetchDescriptor<SoundEventRecord>(
                predicate: #Predicate { $0.ownerID == owner && $0.sessionID == sid },
                sortBy: [SortDescriptor(\.at, order: .reverse)])).first?.at
            session.endedAt = last ?? session.startedAt
        }
        save()
    }

    // MARK: Sound events

    func addSoundEvents(_ events: [SoundEvent], sessionID: UUID) {
        guard !events.isEmpty else { return }
        for event in events { context.insert(SoundEventRecord(ownerID: ownerID, sessionID: sessionID, event: event)) }
        save()
    }

    func soundEvents(from start: Date, to end: Date) -> [SoundEvent] {
        let owner = ownerID
        let descriptor = FetchDescriptor<SoundEventRecord>(
            predicate: #Predicate { $0.ownerID == owner && $0.at >= start && $0.at < end },
            sortBy: [SortDescriptor(\.at)])
        return fetch(descriptor).map(\.value)
    }

    func setCorrection(_ correction: SoundCorrection, forEvent id: UUID) {
        let owner = ownerID
        fetch(FetchDescriptor<SoundEventRecord>(predicate: #Predicate { $0.ownerID == owner && $0.id == id })).first?.correctionRaw = correction.rawValue
        save()
    }
```
and in `deleteAllData()` also delete `SoundSessionRecord` and `SoundEventRecord` for the owner.
Update `AppEnvironment.live` to call `store.closeOrphanedSessions()` right after creating the store (Review Focus 1).

- [ ] **Step 5: Run tests to verify they pass**

Run: `scripts/test-app.sh -only-testing:StillmoonTests`
Expected: `SoundStoreTests` (4) pass; all existing suites pass (the in-memory container now uses V2).

- [ ] **Step 6: Commit**

```bash
git add App
git commit -m "feat(sound): sound session and event storage with V1 to V2 migration"
```

---

### Task 3: Detector, device services and capability

**Files:**
- Create: `App/Stillmoon/Sound/SoundDetecting.swift`, `App/Stillmoon/Sound/SoundAnalysisDetector.swift`, `App/Stillmoon/Sound/DeviceServices.swift`, `App/Stillmoon/Info.plist`
- Modify: `project.yml`
- Test: `App/StillmoonTests/SoundDetectorTests.swift`

**Interfaces:**
- Produces:
  - `struct SoundObservation: Sendable, Equatable { identifier: String; confidence: Double; time: Date }`
  - `protocol SoundDetecting: AnyObject { func start(onObservation: @escaping @Sendable (SoundObservation) -> Void) throws; func stop() }`
  - `final class SoundAnalysisDetector: SoundDetecting` (+ `static let wantedIdentifiers: Set<String> = ["snoring", "speech", "cough"]`)
  - `final class FakeSoundDetector: SoundDetecting { init(script: [SoundObservation] = []); private(set) var isRunning; func emit(_:) ; static func lastNightScript(now: Date, calendar: Calendar) -> [SoundObservation] }`
  - `protocol MicrophonePermission: AnyObject { func request() async -> Bool }`, `final class SystemMicrophonePermission`, `final class FakeMicrophonePermission { init(granted: Bool) }`
  - `struct BatteryState: Equatable { level: Double?; charging: Bool }` (`level` nil when unknown), `protocol BatteryReading: AnyObject { func read() -> BatteryState }`, `final class DeviceBattery`, `final class FakeBattery { var state: BatteryState }`

- [ ] **Step 1: Write the failing tests**

`App/StillmoonTests/SoundDetectorTests.swift`:
```swift
import Foundation
import SoundAnalysis
import Testing
@testable import Stillmoon

struct SoundDetectorTests {
    @Test func builtInClassifierHasOurLabels() throws {
        let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
        #expect(SoundAnalysisDetector.wantedIdentifiers.isSubset(of: Set(request.knownClassifications)))
    }

    @Test func fakeEmitsItsScriptOnStart() throws {
        let script = FakeSoundDetector.lastNightScript(now: TestEnv.d(2026, 10, 2, 9), calendar: TestEnv.cal)
        let fake = FakeSoundDetector(script: script)
        let received = LockedBox<[SoundObservation]>([])
        try fake.start { obs in received.mutate { $0.append(obs) } }
        #expect(fake.isRunning)
        #expect(received.value == script)
        fake.stop()
        #expect(!fake.isRunning)
    }

    @Test func lastNightScriptIsInsideLastNight() {
        let script = FakeSoundDetector.lastNightScript(now: TestEnv.d(2026, 10, 2, 9), calendar: TestEnv.cal)
        #expect(!script.isEmpty)
        #expect(script.allSatisfy { $0.time > TestEnv.d(2026, 10, 1, 23) && $0.time < TestEnv.d(2026, 10, 2, 6) })
    }
}

/// Tiny thread-safe box for collecting callback values in tests.
final class LockedBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: T
    init(_ value: T) { stored = value }
    var value: T { lock.withLock { stored } }
    func mutate(_ f: (inout T) -> Void) { lock.withLock { f(&stored) } }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/SoundDetectorTests`
Expected: build FAILS ("cannot find 'SoundAnalysisDetector' in scope").

- [ ] **Step 3: Capability**

`App/Stillmoon/Info.plist` (merged with the generated Info.plist):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
    </array>
</dict>
</plist>
```
In `project.yml` Stillmoon target: add `INFOPLIST_FILE: App/Stillmoon/Info.plist` (keep `GENERATE_INFOPLIST_FILE: YES`), add `INFOPLIST_KEY_NSMicrophoneUsageDescription: "Stillmoon listens for snoring, speech and coughing on this iPhone during a sleep session you start. Sound is analyzed on the device and never recorded or stored."`, and exclude the plist from sources (`sources: - path: App/Stillmoon, excludes: ["Info.plist"]`). Verify after building with `plutil -p <built app>/Info.plist | grep -A2 UIBackgroundModes` and quote the output in the report.

- [ ] **Step 4: Implement the detector and services**

`App/Stillmoon/Sound/SoundDetecting.swift`:
```swift
import Foundation

struct SoundObservation: Sendable, Equatable {
    let identifier: String
    let confidence: Double
    let time: Date
}

protocol SoundDetecting: AnyObject {
    /// `onObservation` may be called on any thread.
    func start(onObservation: @escaping @Sendable (SoundObservation) -> Void) throws
    func stop()
}

/// Emits a fixed script when started. Used by tests and `-fake-sound`.
final class FakeSoundDetector: SoundDetecting {
    private let script: [SoundObservation]
    private var handler: (@Sendable (SoundObservation) -> Void)?
    private(set) var isRunning = false

    init(script: [SoundObservation] = []) {
        self.script = script
    }

    func start(onObservation: @escaping @Sendable (SoundObservation) -> Void) throws {
        handler = onObservation
        isRunning = true
        script.forEach(onObservation)
    }

    func emit(_ observation: SoundObservation) {
        handler?(observation)
    }

    func stop() {
        isRunning = false
        handler = nil
    }

    /// Snoring at 02:00 and 02:00:10 (one event) and speech at 03:00, last night.
    static func lastNightScript(now: Date, calendar: Calendar) -> [SoundObservation] {
        let day = calendar.startOfDay(for: now)
        func at(_ h: Int, _ m: Int, _ s: Int) -> Date {
            calendar.date(bySettingHour: h, minute: m, second: s, of: day)!
        }
        return [
            SoundObservation(identifier: "snoring", confidence: 0.82, time: at(2, 0, 0)),
            SoundObservation(identifier: "snoring", confidence: 0.9, time: at(2, 0, 10)),
            SoundObservation(identifier: "speech", confidence: 0.7, time: at(3, 0, 0)),
        ]
    }
}
```

`App/Stillmoon/Sound/SoundAnalysisDetector.swift`:
```swift
import AVFAudio
import Foundation
import SoundAnalysis

/// Live classification of microphone input on the device. No audio is kept.
final class SoundAnalysisDetector: SoundDetecting {
    static let wantedIdentifiers: Set<String> = ["snoring", "speech", "cough"]

    private let engine = AVAudioEngine()
    private var analyzer: SNAudioStreamAnalyzer?
    private var observer: ClassificationObserver?
    private let analysisQueue = DispatchQueue(label: "app.stillmoon.sound-analysis")

    func start(onObservation: @escaping @Sendable (SoundObservation) -> Void) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let analyzer = SNAudioStreamAnalyzer(format: format)
        let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
        let observer = ClassificationObserver(wanted: Self.wantedIdentifiers, onObservation: onObservation)
        try analyzer.add(request, withObserver: observer)
        self.analyzer = analyzer
        self.observer = observer

        input.installTap(onBus: 0, bufferSize: 8192, format: format,
                         block: Self.makeTapBlock(analyzer: analyzer, queue: analysisQueue))
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        analyzer?.completeAnalysis()
        analyzer = nil
        observer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Built outside the main actor: the tap runs on an audio thread.
    private nonisolated static func makeTapBlock(analyzer: SNAudioStreamAnalyzer,
                                                 queue: DispatchQueue) -> AVAudioNodeTapBlock {
        nonisolated(unsafe) let analyzer = analyzer
        return { buffer, time in
            queue.async { analyzer.analyze(buffer, atAudioFramePosition: time.sampleTime) }
        }
    }
}

/// Receives classifier results on SoundAnalysis's queue.
nonisolated final class ClassificationObserver: NSObject, SNResultsObserving, @unchecked Sendable {
    private let wanted: Set<String>
    private let onObservation: @Sendable (SoundObservation) -> Void

    init(wanted: Set<String>, onObservation: @escaping @Sendable (SoundObservation) -> Void) {
        self.wanted = wanted
        self.onObservation = onObservation
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        let now = Date()
        for classification in result.classifications where wanted.contains(classification.identifier) {
            onObservation(SoundObservation(identifier: classification.identifier,
                                           confidence: classification.confidence, time: now))
        }
    }
}
```
Swift 6 / main-actor-default isolation is the risk here: a closure created inside a main-actor type and called on an audio or analysis thread crashes at runtime. Keep the tap block and the observer nonisolated as above; if the compiler needs different spellings (`nonisolated(unsafe)`, `@Sendable` annotations), adjust, and explain in the report. `analyzer.analyze` must never run on the main thread.

`App/Stillmoon/Sound/DeviceServices.swift`:
```swift
import AVFAudio
import UIKit

protocol MicrophonePermission: AnyObject {
    func request() async -> Bool
}

final class SystemMicrophonePermission: MicrophonePermission {
    func request() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
}

final class FakeMicrophonePermission: MicrophonePermission {
    var granted: Bool
    private(set) var requests = 0
    init(granted: Bool) { self.granted = granted }
    func request() async -> Bool {
        requests += 1
        return granted
    }
}

struct BatteryState: Equatable {
    /// 0...1, or nil when unknown (e.g. in the simulator).
    var level: Double?
    var charging: Bool
}

protocol BatteryReading: AnyObject {
    func read() -> BatteryState
}

final class DeviceBattery: BatteryReading {
    func read() -> BatteryState {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let level = device.batteryLevel < 0 ? nil : Double(device.batteryLevel)
        let charging = device.batteryState == .charging || device.batteryState == .full
        return BatteryState(level: level, charging: charging)
    }
}

final class FakeBattery: BatteryReading {
    var state: BatteryState
    init(state: BatteryState = BatteryState(level: 1, charging: true)) { self.state = state }
    func read() -> BatteryState { state }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `scripts/test-app.sh -only-testing:StillmoonTests`
Expected: `SoundDetectorTests` (3) pass; all other suites pass.

- [ ] **Step 6: Commit**

```bash
git add project.yml App
git commit -m "feat(sound): on-device sound classifier, fakes, microphone and battery services"
```

---

### Task 4: Session controller

**Files:**
- Create: `App/Stillmoon/Sound/SoundSessionController.swift`
- Modify: `App/Stillmoon/Settings/SettingsStore.swift` (`soundDetectionEnabled`), `App/Stillmoon/Content/AppEnvironment.swift`
- Test: `App/StillmoonTests/SoundSessionControllerTests.swift`

**Interfaces:**
- Consumes: Task 1 `SoundEventDebouncer`, `SoundObservationInput`, `SoundLabel(classifierIdentifier:)`; Task 2 store methods; Task 3 protocols and fakes.
- Produces:
  - `struct FeatureFlags: Equatable { var soundDetection = true }`
  - `AppSettings.soundDetectionEnabled: Bool = false` (CodingKeys + tolerant decoding)
  - `enum SoundSessionError: Error, Equatable { case notAvailable, permissionDenied, couldNotStart }`
  - `@Observable final class SoundSessionController { enum State: Equatable { case idle, running(since: Date), paused(since: Date) }; init(store:detector:permission:battery:settings:flags: @escaping () -> FeatureFlags, now:); state; isActive; isAvailable; needsBatteryWarning() -> Bool; start() async throws; pause(); resume() throws; stop(); handleInterruption(began: Bool); static let lowBattery = 0.3 }`
  - `AppEnvironment`: `var flags: FeatureFlags`, `let sound: SoundSessionController`, `sessionActive` becomes a computed `var sessionActive: Bool { sound.isActive }` (remove the stored property; update any writers), `live` picks `FakeSoundDetector(script: lastNightScript)` + `FakeMicrophonePermission(granted: true)` + `FakeBattery()` when `-fake-sound` is present, otherwise the real ones.

- [ ] **Step 1: Write the failing tests**

`App/StillmoonTests/SoundSessionControllerTests.swift`:
```swift
import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct SoundSessionControllerTests {
    let now = TestEnv.d(2026, 10, 1, 23)

    func make(enabled: Bool = true, granted: Bool = true, flag: Bool = true,
              script: [SoundObservation] = [], battery: BatteryState = BatteryState(level: 0.9, charging: false))
    throws -> (SoundSessionController, LocalStore, FakeSoundDetector, FakeMicrophonePermission) {
        let store = try TestEnv.store()
        let settings = TestEnv.settings()
        settings.settings.soundDetectionEnabled = enabled
        let detector = FakeSoundDetector(script: script)
        let permission = FakeMicrophonePermission(granted: granted)
        let controller = SoundSessionController(store: store, detector: detector, permission: permission,
                                                battery: FakeBattery(state: battery), settings: settings,
                                                flags: { FeatureFlags(soundDetection: flag) }, now: { now })
        return (controller, store, detector, permission)
    }

    func obs(_ id: String, _ h: Int, _ m: Int, _ s: Int = 0, _ c: Double = 0.8) -> SoundObservation {
        SoundObservation(identifier: id, confidence: c, time: TestEnv.d(2026, 10, 2, h, m).addingTimeInterval(Double(s)))
    }

    @Test func startRunsAndStopSavesMergedEvents() async throws {
        let (c, store, detector, _) = try make(script: [obs("snoring", 2, 0), obs("snoring", 2, 0, 10), obs("speech", 3, 0), obs("dog_bark", 3, 1)])
        try await c.start()
        #expect(c.state == .running(since: now))
        #expect(c.isActive)
        #expect(detector.isRunning)
        await c.drainForTesting()
        c.stop()
        #expect(c.state == .idle)
        #expect(!detector.isRunning)
        let events = store.soundEvents(from: .distantPast, to: .distantFuture)
        #expect(events.map(\.label) == [.snoringLike, .speechLike])
        #expect(store.openSessionID() == nil)
    }

    @Test func startFailsWhenPermissionDenied() async throws {
        let (c, store, detector, _) = try make(granted: false)
        await #expect(throws: SoundSessionError.permissionDenied) { try await c.start() }
        #expect(c.state == .idle)
        #expect(!detector.isRunning)
        #expect(store.openSessionID() == nil)
    }

    @Test func notAvailableWhenFlagOffOrSettingOff() async throws {
        let (flagOff, _, _, p1) = try make(flag: false)
        #expect(!flagOff.isAvailable)
        await #expect(throws: SoundSessionError.notAvailable) { try await flagOff.start() }
        #expect(p1.requests == 0)
        let (settingOff, _, _, _) = try make(enabled: false)
        #expect(!settingOff.isAvailable)
    }

    @Test func pauseStopsListeningAndResumeRestarts() async throws {
        let (c, _, detector, _) = try make()
        try await c.start()
        c.pause()
        #expect(c.state == .paused(since: now))
        #expect(!detector.isRunning)
        try c.resume()
        #expect(c.state == .running(since: now))
        #expect(detector.isRunning)
    }

    @Test func interruptionPausesAndCounts() async throws {
        let (c, store, detector, _) = try make()
        try await c.start()
        let session = store.openSessionID()
        c.handleInterruption(began: true)
        #expect(!detector.isRunning)
        c.handleInterruption(began: false)
        #expect(detector.isRunning)
        #expect(session != nil)
    }

    @Test(arguments: [(BatteryState(level: 0.2, charging: false), true),
                      (BatteryState(level: 0.2, charging: true), false),
                      (BatteryState(level: 0.5, charging: false), false),
                      (BatteryState(level: nil, charging: false), false)])
    func batteryWarning(state: BatteryState, warns: Bool) throws {
        let (c, _, _, _) = try make(battery: state)
        #expect(c.needsBatteryWarning() == warns)
    }

    @Test func launchRecoversOrphanedSession() throws {
        let env = AppEnvironment.live(arguments: ["-ui-testing", "-fake-sound"])
        let session = env.store.startSoundSession(at: now)
        #expect(env.store.openSessionID() == session)
        env.store.closeOrphanedSessions()
        #expect(env.store.openSessionID() == nil)
        #expect(!env.sessionActive)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/SoundSessionControllerTests`
Expected: build FAILS ("cannot find 'SoundSessionController' in scope").

- [ ] **Step 3: Implement**

`App/Stillmoon/Sound/SoundSessionController.swift`:
```swift
import AVFAudio
import Foundation
import Observation
import StillmoonCore

struct FeatureFlags: Equatable {
    /// Remote in Plan 5 (FR-18); local default until then.
    var soundDetection = true
}

enum SoundSessionError: Error, Equatable {
    case notAvailable, permissionDenied, couldNotStart
}

/// One user-started overnight session at a time. Never notifies or makes sound.
@Observable final class SoundSessionController {
    enum State: Equatable {
        case idle
        case running(since: Date)
        case paused(since: Date)
    }

    static let lowBattery = 0.3

    @ObservationIgnored private let store: LocalStore
    @ObservationIgnored private let detector: SoundDetecting
    @ObservationIgnored private let permission: MicrophonePermission
    @ObservationIgnored private let battery: BatteryReading
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let flags: () -> FeatureFlags
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var debouncer = SoundEventDebouncer()
    @ObservationIgnored private var sessionID: UUID?

    private(set) var state: State = .idle

    init(store: LocalStore, detector: SoundDetecting, permission: MicrophonePermission, battery: BatteryReading,
         settings: SettingsStore, flags: @escaping () -> FeatureFlags, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.detector = detector
        self.permission = permission
        self.battery = battery
        self.settings = settings
        self.flags = flags
        self.now = now
    }

    var isActive: Bool { state != .idle }
    var isAvailable: Bool { flags().soundDetection && settings.settings.soundDetectionEnabled }

    func needsBatteryWarning() -> Bool {
        let reading = battery.read()
        guard let level = reading.level else { return false }
        return !reading.charging && level < Self.lowBattery
    }

    func start() async throws {
        guard state == .idle else { return }
        guard isAvailable else { throw SoundSessionError.notAvailable }
        guard await permission.request() else { throw SoundSessionError.permissionDenied }
        let started = now()
        let id = store.startSoundSession(at: started)
        sessionID = id
        debouncer = SoundEventDebouncer()
        // Running before the detector starts, so observations delivered immediately are kept.
        state = .running(since: started)
        do {
            try startDetector()
        } catch {
            store.endSoundSession(id, at: started)
            sessionID = nil
            state = .idle
            throw SoundSessionError.couldNotStart
        }
    }

    func pause() {
        guard case .running(let since) = state else { return }
        detector.stop()
        saveClosed(debouncer.flush())
        state = .paused(since: since)
    }

    func resume() throws {
        guard case .paused(let since) = state else { return }
        state = .running(since: since)
        do {
            try startDetector()
        } catch {
            state = .paused(since: since)
            throw error
        }
    }

    func stop() {
        guard isActive else { return }
        detector.stop()
        saveClosed(debouncer.flush())
        if let id = sessionID { store.endSoundSession(id, at: now()) }
        sessionID = nil
        state = .idle
    }

    /// Phone calls and Siri interrupt the microphone; pause and count, resume when allowed.
    func handleInterruption(began: Bool) {
        if began {
            guard case .running = state else { return }
            if let id = sessionID { store.recordInterruption(sessionID: id) }
            pause()
        } else {
            try? resume()
        }
    }

    /// Lets main-actor hops from a background detector finish (tests only; the fake delivers synchronously).
    func drainForTesting() async {
        await Task.yield()
    }

    private func startDetector() throws {
        try detector.start { [weak self] observation in
            if Thread.isMainThread {
                MainActor.assumeIsolated { self?.receive(observation) }
            } else {
                Task { @MainActor in self?.receive(observation) }
            }
        }
    }

    private func receive(_ observation: SoundObservation) {
        guard case .running = state, let label = SoundLabel(classifierIdentifier: observation.identifier) else { return }
        saveClosed(debouncer.add(SoundObservationInput(label: label, confidence: observation.confidence, time: observation.time)))
    }

    private func saveClosed(_ events: [SoundEvent]) {
        guard let id = sessionID else { return }
        store.addSoundEvents(events, sessionID: id)
    }
}
```
The fake detector calls back synchronously on the main thread, so the controller handles those observations inline; the real detector calls back on SoundAnalysis's queue and hops to the main actor.
Also observe `AVAudioSession.interruptionNotification` in `AppEnvironment.live` (or in the controller's init for the real detector only) and call `handleInterruption(began:)` with the notification's `.began`/`.ended` type.

In `SettingsStore.swift`: add `var soundDetectionEnabled = false` with CodingKeys + `decodeIfPresent ?? false`.
In `AppEnvironment.swift`: add `var flags = FeatureFlags()`, `let sound: SoundSessionController`, replace the stored `sessionActive` with `var sessionActive: Bool { sound.isActive }`, extend `init` with `sound: SoundSessionController? = nil` (default: a controller built from the given store/settings with `FakeSoundDetector()`, `FakeMicrophonePermission(granted: true)`, `FakeBattery()`), build the real or fake trio in `live`, call `store.closeOrphanedSessions()` there, and fix any code that assigned `env.sessionActive`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `scripts/test-app.sh -only-testing:StillmoonTests`
Expected: `SoundSessionControllerTests` (6 tests, 4 battery cases) pass; all other suites pass.

- [ ] **Step 5: Commit**

```bash
git add App
git commit -m "feat(sound): session controller with permission, battery warning and interruptions"
```

---

### Task 5: Session screen, start points, onboarding and Settings

**Files:**
- Create: `App/Stillmoon/Features/Sound/SoundSessionView.swift`
- Modify: `App/Stillmoon/Features/Today/TodayView.swift`, `App/Stillmoon/Root/RootView.swift`, `App/Stillmoon/Features/Onboarding/OnboardingModel.swift`, `OnboardingView.swift`, `App/Stillmoon/Features/Settings/SettingsView.swift`
- Modify tests: `App/StillmoonTests/OnboardingModelTests.swift`, `App/StillmoonUITests/LaunchTests.swift`

**Interfaces:**
- Consumes: `AppEnvironment.sound`, `SoundSessionController` (`isAvailable`, `needsBatteryWarning()`, `start()`, `pause()`, `resume()`, `stop()`, `state`), `SoundSessionError`.
- Produces: `SoundSessionView()`; `OnboardingModel.Step.microphone` between `.health` and `.privacy`; `struct SoundStartButton: View` (shared start control with battery confirmation and error message).

- [ ] **Step 1: Update tests first**

`OnboardingModelTests`: in `fullPathSavesGoalAndSchedule` and `skippingScheduleLeavesDefaults`, after the `.health` step expect `.microphone`, call `next()`, then expect `.privacy`.
`LaunchTests`: in every existing test add `app.buttons["Not now"].firstMatch.tap()` for the new microphone step right after the health step's button (the health step's "Not now" or "Connect Apple Health"). Add:
```swift
    @MainActor
    func testFakeSoundSessionSavesEvents() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-fake-sound"]
        app.launch()

        app.buttons["Get started"].tap()
        app.buttons["Unwind before bed"].tap()
        app.buttons["Skip for now"].tap()
        app.buttons["Not now"].tap()                       // health
        app.buttons["Turn on sound detection"].tap()       // microphone (fake grants)
        app.buttons["Continue"].tap()
        app.buttons["Go to Today"].tap()

        let start = app.buttons["Start sleep session"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        XCTAssertTrue(app.staticTexts["Listening for sounds"].waitForExistence(timeout: 5))
        app.buttons["End session"].tap()

        app.tabBars.buttons["Sleep"].tap()
        let row = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "2 sounds noted")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }
```
(The "2 sounds noted" row text comes from Task 6; this UI test is expected to fail until Task 6 lands — mark it with `XCTExpectFailure("Sleep row lands in Task 6")` around the last assertion in this task, and remove that wrapper in Task 6.)

- [ ] **Step 2: Run onboarding unit tests to verify they fail**

Run: `scripts/test-app.sh -only-testing:StillmoonTests/OnboardingModelTests`
Expected: FAIL (step `.microphone` does not exist).

- [ ] **Step 3: Implement**

`OnboardingModel.Step`: `case welcome, goal, schedule, health, microphone, privacy, firstExercise`.
`OnboardingView` gains (reuse the `connecting` re-entrancy pattern from the health step):
```swift
            case .microphone:
                Text("Listen for sounds at night?").font(.title.weight(.semibold))
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
                Button("Not now") { model.next() }
                    .disabled(connecting)
```
Add `func requestPermission() async -> Bool { await permission.request() }` to `SoundSessionController`.

`App/Stillmoon/Features/Sound/SoundSessionView.swift`:
```swift
import SwiftUI

/// Full-screen, always dim. Large controls, no counts, no animation (PRD §7 Sound session).
struct SoundSessionView: View {
    @Environment(AppEnvironment.self) private var env
    private let theme = Theme.night

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Listening for sounds")
                .font(.title.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if case .running(let since) = env.sound.state {
                Text("Since \(since.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(theme.secondaryText)
            } else if case .paused = env.sound.state {
                Text("Paused").foregroundStyle(theme.secondaryText)
            }
            Text("The orange dot at the top of the screen means the microphone is on. Sound is analyzed on this iPhone and never recorded.")
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.secondaryText)
            Text("Place your phone on a stable surface, ideally charging.")
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.secondaryText)
            Spacer()
            if case .paused = env.sound.state {
                Button("Resume") { try? env.sound.resume() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            } else {
                Button("Pause") { env.sound.pause() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
            Button("End session") { env.sound.stop() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(24)
        .foregroundStyle(theme.text)
        .tint(theme.accent)
        .background(theme.background.ignoresSafeArea())
        .environment(\.theme, theme)
        .preferredColorScheme(.dark)
    }
}

/// Starts a session: battery confirmation first, plain message on failure.
struct SoundStartButton: View {
    @Environment(AppEnvironment.self) private var env
    @State private var confirmingBattery = false
    @State private var message: String?
    @State private var starting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                if env.sound.needsBatteryWarning() { confirmingBattery = true } else { start() }
            } label: {
                Label("Start sleep session", systemImage: "waveform")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(starting)
            if let message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .confirmationDialog("Your battery is below 30% and not charging.", isPresented: $confirmingBattery,
                            titleVisibility: .visible) {
            Button("Start anyway") { start() }
        } message: {
            Text("A sleep session listens all night. Plugging in your phone is best.")
        }
    }

    private func start() {
        guard !starting else { return }
        starting = true
        Task {
            do {
                try await env.sound.start()
                message = nil
            } catch SoundSessionError.permissionDenied {
                message = "Microphone access is off. You can turn it on in the Settings app, under Privacy & Security, Microphone."
            } catch {
                message = "The sleep session couldn't start. Please try again."
            }
            starting = false
        }
    }
}
```
`TodayView`: show `SoundStartButton()` inside the night wind-down card (below Start) and at the end of the day content, only `if env.sound.isAvailable && !env.sound.isActive`.
`MainTabs` (RootView.swift): add `.fullScreenCover(isPresented: Binding(get: { env.sound.isActive }, set: { if !$0 { env.sound.stop() } })) { SoundSessionView() }`. SwiftUI shows one presentation per view, so attach this cover to a different view than the player cover (e.g. the player cover on the `TabView`, the sound cover on a wrapping `Group`/`ZStack`). The two are never shown together: hide the sound start button while `env.playerRequest != nil`.
`SettingsView`: section "Sound detection" with `Toggle("Listen for sounds during a sleep session", isOn: ...)` whose setter, when turning on, requests permission via `env.sound.requestPermission()` and keeps it off if denied (show the same denied footer text); footer: "Only during a session you start. Labels, times and confidence are saved on this iPhone; sound is never recorded." Hide the section entirely when `env.flags.soundDetection` is false.

- [ ] **Step 4: Run everything**

Run: `scripts/test-app.sh`
Expected: all unit suites pass; existing UI tests pass with the extra microphone tap; `testFakeSoundSessionSavesEvents` passes up to the session screen and its last assertion is an expected failure; `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add App
git commit -m "feat(sound): sleep session screen, start points, onboarding and settings"
```

---

### Task 6: Sound lane, corrections and the snoring note

**Files:**
- Modify: `App/Stillmoon/Features/Sleep/SleepModel.swift`, `SleepView.swift`, `NightDetailView.swift`, `App/Stillmoon/Features/Today/TodayModel.swift`, `TodayView.swift`
- Modify tests: `App/StillmoonTests/SleepModelTests.swift`, `App/StillmoonTests/TodayModelTests.swift`, `App/StillmoonTests/NightDetailTests.swift`, `App/StillmoonUITests/LaunchTests.swift` (remove the `XCTExpectFailure` wrapper)

**Interfaces:**
- Consumes: `LocalStore.soundEvents(from:to:)`, `setCorrection(_:forEvent:)`; Core `ReferralSignals.showsSnoringNote(events:now:calendar:alreadyShown:)`, `NightWindow`.
- Produces: `NightRow.soundEvents: [SoundEvent]` (default `[]` in its init so existing call sites compile), `SleepModel.correct(_ event: SoundEvent, as: SoundCorrection) async`, `SoundLabel.title`, `SoundCorrection.title: String?`, `NightSummary.soundCountLine(_ count: Int) -> String?`, `TodayModel.showsSnoringNote: Bool`, `TodayModel.dismissSnoringNote()`, `SoundLane(events:)` view.

Rules: an event belongs to the morning whose `NightWindow` contains it; an event outside every window in the 14-day range (12:00–18:00) belongs to the next morning. Rows exist for mornings with a report, an entry, or sound events.

- [ ] **Step 1: Write the failing tests**

Add to `SleepModelTests`:
```swift
    @Test func soundEventsJoinTheirNight() async throws {
        let (m, store, _) = try make()
        let s = store.startSoundSession(at: TestEnv.d(2026, 10, 1, 23))
        store.addSoundEvents([SoundEvent(label: .snoringLike, at: TestEnv.d(2026, 10, 2, 2), confidence: 0.8),
                              SoundEvent(label: .speechLike, at: TestEnv.d(2026, 10, 2, 3), confidence: 0.7)], sessionID: s)
        await m.refresh()
        #expect(m.rows[0].soundEvents.map(\.label) == [.snoringLike, .speechLike])
    }

    @Test func eventsOutsideNightWindowsAreNotDropped() async throws {
        let (m, store, _) = try make(connected: false)
        let s = store.startSoundSession(at: TestEnv.d(2026, 10, 1, 14))
        store.addSoundEvents([SoundEvent(label: .coughLike, at: TestEnv.d(2026, 10, 1, 15), confidence: 0.9)], sessionID: s)
        await m.refresh()
        #expect(m.rows.map(\.morning) == [TestEnv.d(2026, 10, 2)])
        #expect(m.rows[0].soundEvents.count == 1)
    }

    @Test func correctingAnEventPersists() async throws {
        let (m, store, _) = try make()
        let s = store.startSoundSession(at: TestEnv.d(2026, 10, 1, 23))
        let e = SoundEvent(label: .snoringLike, at: TestEnv.d(2026, 10, 2, 2), confidence: 0.8)
        store.addSoundEvents([e], sessionID: s)
        await m.refresh()
        await m.correct(m.rows[0].soundEvents[0], as: .wasMe)
        #expect(m.rows[0].soundEvents[0].correction == .wasMe)
    }
```
Add to `NightDetailTests`:
```swift
    @Test func soundCopy() {
        #expect(SoundLabel.speechLike.title == "Speech-like sound")
        #expect(SoundCorrection.someoneElse.title == "Someone else")
        #expect(SoundCorrection.none.title == nil)
        #expect(NightSummary.soundCountLine(0) == nil)
        #expect(NightSummary.soundCountLine(1) == "1 sound noted")
        #expect(NightSummary.soundCountLine(2) == "2 sounds noted")
    }
```
Add to `TodayModelTests`:
```swift
    @Test func snoringNoteShowsOnceAfterFiveNights() throws {
        let (m, store) = try make()
        let s = store.startSoundSession(at: TestEnv.d(2026, 9, 26, 23))
        for day in 26...30 {
            let e = SoundEvent(label: .snoringLike, at: TestEnv.d(2026, 9, day, 23, 30), confidence: 0.8, correction: .wasMe)
            store.addSoundEvents([e], sessionID: s)
        }
        m.refresh()
        #expect(m.showsSnoringNote)
        m.dismissSnoringNote()
        #expect(!m.showsSnoringNote)
    }
```
(`make()` in TodayModelTests must keep the `SettingsStore` reachable for `dismissSnoringNote()`; the model writes `settings.settings.snoringNoteShown = true`.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test-app.sh -only-testing:StillmoonTests`
Expected: build FAILS ("no member 'soundEvents'" / "'title'").

- [ ] **Step 3: Implement**

- `NightRow`: add `let soundEvents: [SoundEvent]` with init default `[]` (write an explicit init so existing `NightRow(morning:report:entry:checkIn:)` calls compile).
- `SleepModel.refresh()`: after reports and entries, load `store.soundEvents(from: <oldest window start>, to: now)`; for each event pick the first morning `m` in the 14-day range with `NightWindow.forMorning(of: m).start <= event.at < end`, else `calendar.startOfDay(for: event.at) + 1 day`; group into `[Date: [SoundEvent]]`; include those mornings in the row set; pass `soundEvents:` sorted by `at`. Add `func correct(_ event: SoundEvent, as correction: SoundCorrection) async { store.setCorrection(correction, forEvent: event.id); await refresh() }`.
- Copy helpers (in `NightDetailView.swift`):
```swift
extension SoundLabel {
    var title: String {
        switch self {
        case .snoringLike: "Snoring-like sound"
        case .speechLike: "Speech-like sound"
        case .coughLike: "Cough-like sound"
        }
    }
}

extension SoundCorrection {
    var title: String? {
        switch self {
        case .none: nil
        case .wasMe: "This was me"
        case .someoneElse: "Someone else"
        case .incorrect: "Not correct"
        }
    }
}
```
and `static func soundCountLine(_ count: Int) -> String?` in `NightSummary` (`nil` for 0, "1 sound noted", "\(n) sounds noted").
- `NightRowView`: add `if let line = NightSummary.soundCountLine(row.soundEvents.count) { Text(line)... }`.
- `NightDetailView`: `NightDetailView` takes `row` and an `onCorrect: (SoundEvent, SoundCorrection) -> Void`; below the device card add (only when events exist):
```swift
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Sounds noticed").font(.headline)
                            SoundLane(events: row.soundEvents)
                            ForEach(row.soundEvents, id: \.id) { event in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("A \(event.label.title.lowercased()) was detected")
                                        Text(event.at.formatted(date: .omitted, time: .shortened)
                                             + (event.correction.title.map { " · \($0)" } ?? ""))
                                            .font(.footnote)
                                            .foregroundStyle(theme.secondaryText)
                                    }
                                    Spacer()
                                    Menu {
                                        Button("This was me") { onCorrect(event, .wasMe) }
                                        Button("Someone else") { onCorrect(event, .someoneElse) }
                                        Button("Not correct") { onCorrect(event, .incorrect) }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .frame(width: 44, height: 44)
                                            .contentShape(Rectangle())
                                    }
                                    .accessibilityLabel("Correct this \(event.label.title.lowercased())")
                                }
                            }
                            Text("Sounds are guesses from a classifier. They can't tell who made a sound or how anyone felt.")
                                .font(.footnote)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
```
  and a separate small chart (not part of `StageChart`):
```swift
struct SoundLane: View {
    @Environment(\.theme) private var theme
    let events: [SoundEvent]

    var body: some View {
        Chart(events, id: \.id) { event in
            PointMark(x: .value("Time", event.at), y: .value("Sound", event.label.title))
                .foregroundStyle(theme.accent2)
        }
        .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 2)) { _ in AxisValueLabel(format: .dateTime.hour()) } }
        .frame(height: 90)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sounds noticed during the night, listed below")
    }
}
```
  `SleepView`'s `navigationDestination` passes `onCorrect: { event, c in Task { await model.correct(event, as: c) } }`; the detail must show the updated row after a correction — pass the row by morning and look it up in `model.rows` (`NightDetailView(row: model.rows.first { $0.morning == morning } ?? row, …)`), or give the detail a binding; pick one and keep it simple.
- `TodayModel`: in `refresh()` compute `showsSnoringNote = ReferralSignals.showsSnoringNote(events: store.soundEvents(from: now - 8 days, to: now), now: now, calendar: calendar, alreadyShown: settings.settings.snoringNoteShown)`; `func dismissSnoringNote() { settings.settings.snoringNoteShown = true; refresh() }`.
- `TodayView` (day content, after the difficulty card): when `model.showsSnoringNote`, a `Card` with "Frequent loud snoring is worth mentioning to a doctor." + `NavigationLink("When to talk to a doctor", value: Route.article(TodayModel.doctorArticleID))` + `Button("Dismiss") { model.dismissSnoringNote() }`.
- `LaunchTests`: remove the `XCTExpectFailure` wrapper from Task 5.

- [ ] **Step 4: Run everything**

Run: `scripts/test-app.sh`
Expected: all unit suites pass (5 new tests); all 4 UI tests pass, including `testFakeSoundSessionSavesEvents` showing "2 sounds noted"; `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add App
git commit -m "feat(sound): sound lane with corrections in night detail and the snoring note"
```
