import Charts
import SwiftUI
import StillmoonCore

enum NightSummary {
    /// Top to bottom on the chart and in the list.
    static let stageOrder: [SleepStage] = [.awake, .rem, .core, .deep]

    /// Stage durations, only when the source recorded stages.
    static func stageRows(_ report: NightReport) -> [(stage: SleepStage, seconds: TimeInterval)] {
        guard report.hasStageDetail else { return [] }
        return stageOrder.compactMap { stage in
            report.stageDurations[stage].map { (stage, $0) }
        }
    }

    static func estimateLine(_ report: NightReport) -> String {
        "\(report.primarySource) estimated \(Format.duration(minutes: Int(report.estimatedAsleep / 60))) asleep"
    }

    static func timelineDescription(_ report: NightReport) -> String {
        report.timeline
            .filter { stageOrder.contains($0.stage) }
            .map { "\($0.stage.title) \($0.start.formatted(date: .omitted, time: .shortened)) to \($0.end.formatted(date: .omitted, time: .shortened))" }
            .joined(separator: ", ")
    }

    static func incompleteNote(_ report: NightReport) -> String? {
        report.gaps.isEmpty ? nil : "Part of the night wasn't recorded, so totals may be lower than your actual sleep."
    }

    static func gapLine(_ gap: DateInterval) -> String {
        "No data from \(gap.start.formatted(date: .omitted, time: .shortened)) to \(gap.end.formatted(date: .omitted, time: .shortened))."
    }
}

struct NightDetailView: View {
    @Environment(\.theme) private var theme
    let row: NightRow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(row.morning, format: .dateTime.weekday(.wide).month().day())
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                if let report = row.report {
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("What your device estimated").font(.headline)
                            Text(NightSummary.estimateLine(report)).font(.title3)
                            Text("\(report.sleepStart.formatted(date: .omitted, time: .shortened)) to \(report.sleepEnd.formatted(date: .omitted, time: .shortened))")
                                .foregroundStyle(theme.secondaryText)
                            if report.hasStageDetail {
                                StageChart(timeline: report.timeline, description: NightSummary.timelineDescription(report))
                                ForEach(NightSummary.stageRows(report), id: \.stage) { item in
                                    HStack {
                                        Text(item.stage.title)
                                        Spacer()
                                        Text(Format.duration(minutes: Int(item.seconds / 60)))
                                            .foregroundStyle(theme.secondaryText)
                                    }
                                    .accessibilityElement(children: .combine)
                                }
                                Text("Stages are estimates from your device, not measurements.")
                                    .font(.footnote)
                                    .foregroundStyle(theme.secondaryText)
                            } else {
                                Text("\(report.primarySource) recorded time asleep without stages.")
                                    .font(.footnote)
                                    .foregroundStyle(theme.secondaryText)
                            }
                            ForEach(report.gaps, id: \.self) { gap in
                                Text(NightSummary.gapLine(gap))
                                    .font(.footnote)
                                    .foregroundStyle(theme.secondaryText)
                            }
                            if let note = NightSummary.incompleteNote(report) {
                                Text(note)
                                    .font(.footnote)
                                    .foregroundStyle(theme.secondaryText)
                            }
                            if report.allSources.count > 1 {
                                Text("Also recorded by: \(report.allSources.dropFirst().joined(separator: ", "))")
                                    .font(.footnote)
                                    .foregroundStyle(theme.secondaryText)
                            }
                        }
                    }
                }
                if let entry = row.entry {
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("You recorded").font(.headline)
                            Text("\(entry.bedtime.formatted(date: .omitted, time: .shortened)) to \(entry.wakeTime.formatted(date: .omitted, time: .shortened)), \(Format.duration(minutes: entry.inBedMinutes)) in bed")
                            if let note = entry.note, !note.isEmpty {
                                Text(note).foregroundStyle(theme.secondaryText)
                            }
                        }
                    }
                }
                if let checkIn = row.checkIn {
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("You felt \(checkIn.restedness) of 5 rested").font(.headline)
                            if checkIn.tenseAtBedtime { Text("You felt tense at bedtime") }
                            if checkIn.wokeDuringNight { Text("You were awake during the night") }
                        }
                    }
                }
            }
            .foregroundStyle(theme.text)
            .padding()
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Night")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Stage timeline: one bar per sample, stages as rows.
struct StageChart: View {
    @Environment(\.theme) private var theme
    let timeline: [SleepSample]
    let description: String
    @ScaledMetric private var chartHeight: CGFloat = 160

    init(timeline: [SleepSample], description: String) {
        self.timeline = timeline
        self.description = description
    }

    private func color(for stage: SleepStage) -> Color {
        switch stage {
        case .awake: theme.accent2
        case .rem: theme.accent.opacity(0.55)
        case .core: theme.accent.opacity(0.8)
        default: theme.accent
        }
    }

    var body: some View {
        let staged = timeline.filter { NightSummary.stageOrder.contains($0.stage) }
        Chart(staged, id: \.self) { sample in
            BarMark(xStart: .value("Start", sample.start),
                    xEnd: .value("End", sample.end),
                    y: .value("Stage", sample.stage.title))
                .foregroundStyle(color(for: sample.stage))
        }
        .chartYScale(domain: NightSummary.stageOrder.map(\.title))
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .frame(height: chartHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sleep stage timeline")
        .accessibilityValue(description)
    }
}
