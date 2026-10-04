import SwiftUI
import StillmoonCore

/// A compact strip of last night's estimated stages in time order. The card's text says the same, so it is hidden from VoiceOver.
struct StageBar: View {
    @Environment(\.theme) private var theme
    let timeline: [SleepSample]

    struct Segment: Equatable {
        let stage: SleepStage
        let fraction: Double
    }

    /// Consecutive samples of one stage merge; "in bed" is not a stage to show.
    static func segments(_ timeline: [SleepSample]) -> [Segment] {
        var merged: [(stage: SleepStage, seconds: Double)] = []
        for sample in timeline where sample.stage != .inBed {
            let seconds = max(0, sample.end.timeIntervalSince(sample.start))
            if let last = merged.last, last.stage == sample.stage {
                merged[merged.count - 1].seconds += seconds
            } else {
                merged.append((sample.stage, seconds))
            }
        }
        let total = merged.reduce(0) { $0 + $1.seconds }
        guard total > 0 else { return [] }
        return merged.map { Segment(stage: $0.stage, fraction: $0.seconds / total) }
    }

    var body: some View {
        let segments = Self.segments(timeline)
        GeometryReader { geo in
            let usable = geo.size.width - CGFloat(max(0, segments.count - 1)) * 2
            HStack(spacing: 2) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    Rectangle()
                        .fill(color(segment.stage))
                        .frame(width: max(2, usable * segment.fraction))
                }
            }
        }
        .frame(height: 12)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    private func color(_ stage: SleepStage) -> Color {
        switch stage {
        case .awake: theme.accent2
        case .deep: theme.accent
        case .rem: theme.accent.opacity(0.7)
        case .core, .asleepUnspecified, .inBed: theme.accent.opacity(0.4)
        }
    }
}
