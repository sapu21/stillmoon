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
