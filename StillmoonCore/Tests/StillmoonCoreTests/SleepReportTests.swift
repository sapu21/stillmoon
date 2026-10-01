import Foundation
import Testing
@testable import StillmoonCore

struct SleepReportTests {
    let window = NightWindow.forMorning(of: T.d(2026, 10, 2, 8), calendar: T.cal)
    let watch = "Apple Watch"

    func s(_ stage: SleepStage, _ from: Date, _ to: Date, _ source: String = "Apple Watch") -> SleepSample {
        SleepSample(stage: stage, start: from, end: to, sourceName: source)
    }

    var watchNight: [SleepSample] {
        [
            s(.core, T.d(2026, 10, 1, 23), T.d(2026, 10, 2, 1)),
            s(.deep, T.d(2026, 10, 2, 1), T.d(2026, 10, 2, 2)),
            s(.awake, T.d(2026, 10, 2, 2), T.d(2026, 10, 2, 2, 10)),
            s(.rem, T.d(2026, 10, 2, 2, 10), T.d(2026, 10, 2, 3)),
            s(.core, T.d(2026, 10, 2, 3), T.d(2026, 10, 2, 6, 30)),
        ]
    }

    @Test func noSamplesGivesNoReport() {
        #expect(SleepReportBuilder.build(samples: [], window: window) == nil)
    }

    @Test func inBedOnlyGivesNoReport() {
        let r = SleepReportBuilder.build(samples: [s(.inBed, T.d(2026, 10, 1, 22), T.d(2026, 10, 2, 7))], window: window)
        #expect(r == nil)
    }

    @Test func buildsAWatchNight() throws {
        let r = try #require(SleepReportBuilder.build(samples: watchNight, window: window))
        #expect(r.sleepStart == T.d(2026, 10, 1, 23))
        #expect(r.sleepEnd == T.d(2026, 10, 2, 6, 30))
        #expect(r.estimatedAsleep == 7 * 3600 + 20 * 60)
        #expect(r.stageDurations[.deep] == 3600)
        #expect(r.stageDurations[.awake] == 600)
        #expect(r.hasStageDetail)
        #expect(r.gaps.isEmpty)
        #expect(r.primarySource == watch)
        #expect(r.allSources == [watch])
        #expect(r.timeline.count == 5)
    }

    @Test func duplicatesAreNotDoubleCounted() throws {
        let r = try #require(SleepReportBuilder.build(samples: watchNight + watchNight, window: window))
        #expect(r.estimatedAsleep == 7 * 3600 + 20 * 60)
        #expect(r.timeline.count == 5)
    }

    @Test func prefersTheSourceWithStageDetail() throws {
        let phone = s(.asleepUnspecified, T.d(2026, 10, 1, 22, 30), T.d(2026, 10, 2, 7), "iPhone")
        let r = try #require(SleepReportBuilder.build(samples: watchNight + [phone], window: window))
        #expect(r.primarySource == watch)
        #expect(r.allSources == [watch, "iPhone"])
        #expect(r.estimatedAsleep == 7 * 3600 + 20 * 60)
    }

    @Test func iPhoneOnlyNightHasNoStageDetail() throws {
        let phone = s(.asleepUnspecified, T.d(2026, 10, 1, 23), T.d(2026, 10, 2, 7), "iPhone")
        let r = try #require(SleepReportBuilder.build(samples: [phone], window: window))
        #expect(!r.hasStageDetail)
        #expect(r.estimatedAsleep == 8 * 3600)
    }

    @Test func reportsGapsOfFifteenMinutesOrMore() throws {
        let samples = [
            s(.core, T.d(2026, 10, 1, 23), T.d(2026, 10, 2, 1)),
            s(.core, T.d(2026, 10, 2, 2), T.d(2026, 10, 2, 4)),
            s(.core, T.d(2026, 10, 2, 4, 10), T.d(2026, 10, 2, 6)),
        ]
        let r = try #require(SleepReportBuilder.build(samples: samples, window: window))
        #expect(r.gaps == [DateInterval(start: T.d(2026, 10, 2, 1), end: T.d(2026, 10, 2, 2))])
    }

    @Test func clipsAndIgnoresSamplesOutsideTheWindow() throws {
        let yesterdayMorning = s(.core, T.d(2026, 10, 1, 3), T.d(2026, 10, 1, 6))
        let nap = s(.core, T.d(2026, 10, 1, 17), T.d(2026, 10, 1, 19)) // clipped to 18:00–19:00
        let r = try #require(SleepReportBuilder.build(samples: [yesterdayMorning, nap], window: window))
        #expect(r.sleepStart == T.d(2026, 10, 1, 18))
        #expect(r.estimatedAsleep == 3600)
    }

    @Test func fallBackNightCountsRealElapsedTime() throws {
        let w = NightWindow.forMorning(of: T.d(2026, 11, 1, 9), calendar: T.cal)
        // 23:00 to 07:00 across the 02:00 fall-back is 9 real hours.
        let sample = s(.core, T.d(2026, 10, 31, 23), T.d(2026, 11, 1, 7))
        let r = try #require(SleepReportBuilder.build(samples: [sample], window: w))
        #expect(r.estimatedAsleep == 9 * 3600)
    }
}
