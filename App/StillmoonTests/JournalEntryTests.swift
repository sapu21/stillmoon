import Foundation
import Testing
@testable import Stillmoon

struct JournalEntryTests {
    @Test func validEntryHasNoMessage() {
        let e = JournalEntry(bedtime: TestEnv.d(2026, 10, 1, 23), wakeTime: TestEnv.d(2026, 10, 2, 7))
        #expect(e.validationMessage() == nil)
        #expect(e.inBedMinutes == 480)
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
