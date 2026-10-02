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
