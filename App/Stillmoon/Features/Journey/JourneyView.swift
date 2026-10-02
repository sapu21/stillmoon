import SwiftUI

struct JourneyView: View {
    @Environment(\.theme) private var theme
    let model: JourneyModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if model.isHidden {
                    Card {
                        Text("Progress is hidden. You can show it again in Settings.")
                            .foregroundStyle(theme.secondaryText)
                    }
                } else {
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("This week").font(.headline)
                            Text("\(model.summary.windDownsThisWeek) of \(model.summary.weeklyGoal) wind-downs")
                                .font(.title2.weight(.semibold))
                            ProgressView(value: Double(min(model.summary.windDownsThisWeek, model.summary.weeklyGoal)),
                                         total: Double(model.summary.weeklyGoal))
                                .tint(theme.accent)
                                .accessibilityLabel("Wind-downs this week")
                                .accessibilityValue("\(model.summary.windDownsThisWeek) of \(model.summary.weeklyGoal)")
                            Text("Missed days are fine. Your path only moves forward.")
                                .font(.footnote)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(model.stageName).font(.headline)
                            JourneyPath(stage: model.summary.journeyStage, name: model.stageName)
                            Text("\(model.summary.totalWindDowns) wind-downs so far")
                                .font(.footnote)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                    if !model.recent.isEmpty {
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recently").font(.headline)
                                ForEach(model.recent) { item in
                                    HStack {
                                        Text(item.title)
                                        Spacer()
                                        Text(item.completedAt, format: .dateTime.month().day())
                                            .foregroundStyle(theme.secondaryText)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Journey")
        .onAppear { model.refresh() }
    }
}

struct JourneyPath: View {
    @Environment(\.theme) private var theme
    let stage: Int
    let name: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                Circle()
                    .fill(i <= stage ? theme.accent : theme.accent.opacity(0.2))
                    .frame(width: 18, height: 18)
                if i < 6 {
                    Rectangle()
                        .fill(i < stage ? theme.accent : theme.accent.opacity(0.2))
                        .frame(height: 3)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), stage \(stage) of 6")
    }
}
