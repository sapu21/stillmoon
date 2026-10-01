import Foundation

public struct NightReport: Sendable, Equatable {
    public let sleepStart: Date
    public let sleepEnd: Date
    /// Seconds asleep (core, deep, REM, unspecified), overlaps merged.
    public let estimatedAsleep: TimeInterval
    public let stageDurations: [SleepStage: TimeInterval]
    public let hasStageDetail: Bool
    /// Spans inside the sleep window with no data from the primary source.
    public let gaps: [DateInterval]
    public let primarySource: String
    /// Every source that recorded this night, primary first, then alphabetical.
    public let allSources: [String]
    /// Primary-source samples, deduplicated and sorted by start.
    public let timeline: [SleepSample]
}

public enum SleepReportBuilder {
    public static let minimumGap: TimeInterval = 15 * 60

    public static func build(samples: [SleepSample], window: NightWindow) -> NightReport? {
        let clipped = Set(samples).compactMap { clip($0, to: window) }
        guard clipped.contains(where: { $0.stage.isAsleep }) else { return nil }

        let bySource = Dictionary(grouping: clipped, by: \.sourceName)
        let ranked = bySource.map { name, items in
            (name: name,
             detailed: items.contains { $0.stage.isDetailed },
             asleep: total(merge(items.filter { $0.stage.isAsleep })))
        }.sorted { a, b in
            if a.detailed != b.detailed { return a.detailed }
            if a.asleep != b.asleep { return a.asleep > b.asleep }
            return a.name < b.name
        }
        let primary = ranked[0].name
        let timeline = Set(bySource[primary]!).sorted { ($0.start, $0.end) < ($1.start, $1.end) }

        let asleep = merge(timeline.filter { $0.stage.isAsleep })
        let sleepStart = asleep.first!.start
        let sleepEnd = asleep.last!.end

        var stageDurations: [SleepStage: TimeInterval] = [:]
        for (stage, items) in Dictionary(grouping: timeline, by: \.stage) {
            stageDurations[stage] = total(merge(items))
        }

        return NightReport(
            sleepStart: sleepStart,
            sleepEnd: sleepEnd,
            estimatedAsleep: total(asleep),
            stageDurations: stageDurations,
            hasStageDetail: timeline.contains { $0.stage.isDetailed },
            gaps: gaps(in: merge(timeline), from: sleepStart, to: sleepEnd),
            primarySource: primary,
            allSources: ranked.map(\.name),
            timeline: timeline
        )
    }

    static func clip(_ sample: SleepSample, to window: NightWindow) -> SleepSample? {
        let start = max(sample.start, window.start)
        let end = min(sample.end, window.end)
        guard start < end else { return nil }
        var copy = sample
        copy.start = start
        copy.end = end
        return copy
    }

    static func merge(_ samples: [SleepSample]) -> [DateInterval] {
        mergeIntervals(samples.map { DateInterval(start: $0.start, end: $0.end) })
    }

    static func mergeIntervals(_ intervals: [DateInterval]) -> [DateInterval] {
        var result: [DateInterval] = []
        for next in intervals.sorted(by: { $0.start < $1.start }) {
            if let last = result.last, next.start <= last.end {
                result[result.count - 1] = DateInterval(start: last.start, end: max(last.end, next.end))
            } else {
                result.append(next)
            }
        }
        return result
    }

    static func total(_ intervals: [DateInterval]) -> TimeInterval {
        intervals.reduce(0) { $0 + $1.duration }
    }

    static func gaps(in covered: [DateInterval], from start: Date, to end: Date) -> [DateInterval] {
        var result: [DateInterval] = []
        var cursor = start
        for interval in covered where interval.end > start && interval.start < end {
            if interval.start.timeIntervalSince(cursor) >= minimumGap {
                result.append(DateInterval(start: cursor, end: interval.start))
            }
            cursor = max(cursor, interval.end)
        }
        return result
    }
}
