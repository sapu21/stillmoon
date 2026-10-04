import SwiftUI

/// Daytime wind-down celebration (spec "Completion"). Never shown at night.
struct CompletionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let summary: CompletionSummary
    let onDone: () -> Void
    private let theme = Theme.day
    @State private var newMoonShown = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack {
                    Rays()
                    LumiView(mood: .cheer, motion: .bounce, size: 190)
                }
                .frame(height: 250)
                Text("Wind-down done!")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("You gave yourself \(summary.minutes) calm \(summary.minutes == 1 ? "minute" : "minutes").")
                    .font(.headline)
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
                weekCard
                if let star = summary.star { starCard(star) }
                if summary.savedToHealth {
                    Text("Saved to Apple Health as Mindful Minutes")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                }
                Button("Continue", action: onDone)
                    .buttonStyle(ChunkyButtonStyle())
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .foregroundStyle(theme.text)
        .background(theme.accentSoft.ignoresSafeArea())
        .environment(\.theme, theme)
        .preferredColorScheme(.light)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.5).delay(0.7)) {
                newMoonShown = true
            }
        }
    }

    private var weekCard: some View {
        let shown = min(summary.windDownsThisWeek, summary.weeklyGoal)
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("This week").font(.headline)
                    Spacer()
                    Text("\(shown) of \(summary.weeklyGoal)").font(.subheadline.weight(.heavy)).foregroundStyle(theme.accent)
                }
                HStack(spacing: 12) {
                    ForEach(0..<min(summary.weeklyGoal, 7), id: \.self) { i in
                        MoonPhaseView(level: i < shown ? 5 : 1, background: theme.surface, size: 44)
                            .scaleEffect(i == shown - 1 && !newMoonShown ? 0.01 : 1)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(shown) of \(summary.weeklyGoal) wind-downs this week")
                Text(shown >= summary.weeklyGoal ? "This week's moon is full." : "Every wind-down fills a little more.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }

    private func starCard(_ star: CompletionSummary.Star) -> some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.title)
                    .foregroundStyle(theme.moon)
                    .scaleEffect(newMoonShown ? 1 : 0.01)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("A new star lit up in Lumi's sky").font(.headline)
                    Text("\(star.stageName) · \(star.litInStage) of \(star.starsInStage) stars")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// Slowly turning soft rays behind Lumi.
private struct Rays: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { context in
            let turn = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 40) / 40 * 360
            Canvas { gc, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let r = max(size.width, size.height)
                for i in 0..<8 {
                    let a = (Double(i) * 45 + turn) * .pi / 180
                    var ray = Path()
                    ray.move(to: c)
                    ray.addLine(to: CGPoint(x: c.x + r * cos(a - 0.09), y: c.y + r * sin(a - 0.09)))
                    ray.addLine(to: CGPoint(x: c.x + r * cos(a + 0.09), y: c.y + r * sin(a + 0.09)))
                    ray.closeSubpath()
                    gc.fill(ray, with: .color(.white.opacity(0.6)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
