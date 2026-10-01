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
