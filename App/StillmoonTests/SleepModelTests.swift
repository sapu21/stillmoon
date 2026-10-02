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
        #expect(m.rows[0].report?.estimatedAsleep == TimeInterval(7 * 3600 + 20 * 60))
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

    @Test func failedReadClearsOnNextSuccessfulRefresh() async throws {
        let (m, _, health) = try make()
        health.failReads = true
        await m.refresh()
        #expect(m.healthError)
        health.failReads = false
        await m.refresh()
        #expect(!m.healthError)
        #expect(m.rows.count == 1)
        #expect(m.rows[0].report != nil)
    }

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
}
