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

    @Test func closeStaleClosesOnlyOldEvents() {
        var d = SoundEventDebouncer()
        _ = d.add(obs(.snoringLike, 0))
        _ = d.add(obs(.speechLike, 25))
        let closed = d.closeStale(now: t0.addingTimeInterval(40))
        #expect(closed.map(\.label) == [.snoringLike])
        #expect(d.flush().map(\.label) == [.speechLike])
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
        #expect(closed[0].confidence == Double(0.95))
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
