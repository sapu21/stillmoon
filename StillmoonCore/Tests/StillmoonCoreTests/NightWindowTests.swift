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
