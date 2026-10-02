import Foundation

public struct NightReport: Sendable, Equatable, Hashable {
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

    public init(sleepStart: Date, sleepEnd: Date, estimatedAsleep: TimeInterval,
                stageDurations: [SleepStage: TimeInterval], hasStageDetail: Bool, gaps: [DateInterval],
                primarySource: String, allSources: [String], timeline: [SleepSample]) {
        self.sleepStart = sleepStart
        self.sleepEnd = sleepEnd
        self.estimatedAsleep = estimatedAsleep
        self.stageDurations = stageDurations
        self.hasStageDetail = hasStageDetail
        self.gaps = gaps
        self.primarySource = primarySource
        self.allSources = allSources
        self.timeline = timeline
    }
}

public enum SleepReportBuilder {
    public static let minimumGap: TimeInterval = 15 * 60
    /// A detailed source is preferred only if its asleep total is at least this share of the largest source's.
    public static let detailCoverageRatio = 0.5
    /// A hole this long in the primary source's samples starts a new cluster (nap vs night).
    public static let clusterBreak: TimeInterval = 2 * 3600

    public static func build(samples: [SleepSample], window: NightWindow) -> NightReport? {
        let clipped = Set(samples).compactMap { clip($0, to: window) }
        guard clipped.contains(where: { $0.stage.isAsleep }) else { return nil }

        let bySource = Dictionary(grouping: clipped, by: \.sourceName)
        let stats = bySource.map { name, items in
            (name: name,
             detailed: items.contains { $0.stage.isDetailed },
             asleep: total(merge(items.filter { $0.stage.isAsleep })))
        }
        let largest = stats.map(\.asleep).max() ?? 0
        let ranked = stats.map { (name: $0.name, qualifies: $0.detailed && $0.asleep >= largest * detailCoverageRatio, asleep: $0.asleep) }
            .sorted { a, b in
                if a.qualifies != b.qualifies { return a.qualifies }
                if a.asleep != b.asleep { return a.asleep > b.asleep }
                return a.name < b.name
            }
        let primary = ranked[0].name

        // The night is the cluster of primary-source samples with the most asleep time.
        let primarySamples = Set(bySource[primary]!).sorted {
            ($0.start, $0.end, $0.stage.rawValue) < ($1.start, $1.end, $1.stage.rawValue)
        }
        var clusters: [[SleepSample]] = []
        var clusterEnd = Date.distantPast
        for sample in primarySamples {
            if clusters.isEmpty || sample.start.timeIntervalSince(clusterEnd) >= clusterBreak {
                clusters.append([sample])
                clusterEnd = sample.end
            } else {
                clusters[clusters.count - 1].append(sample)
                clusterEnd = max(clusterEnd, sample.end)
            }
        }
        let candidates = clusters.map { cluster in
            (samples: cluster,
             asleep: total(merge(cluster.filter { $0.stage.isAsleep })),
             end: cluster.map(\.end).max()!)
        }.filter { $0.asleep > 0 }
        guard let night = candidates.max(by: { ($0.asleep, $0.end) < ($1.asleep, $1.end) }) else { return nil }
        let timeline = night.samples

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
