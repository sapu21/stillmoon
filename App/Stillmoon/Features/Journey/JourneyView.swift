import SwiftUI
import StillmoonCore

/// "Your sky": one star per wind-down, Duolingo-style path, Lumi beside the next star.
struct JourneyView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    let model: JourneyModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    if model.isHidden {
                        Card {
                            Text("Progress is hidden. You can show it again in Settings.")
                                .foregroundStyle(theme.secondaryText)
                        }
                    } else {
                        weekCard
                        ForEach(model.sky) { stage in
                            StageBanner(stage: stage)
                            VStack(spacing: 14) {
                                ForEach(stage.stars) { star in
                                    StarNode(star: star, nextTitle: model.nextWindDown?.title, onStart: startNext)
                                        .offset(x: SkyPath.xOffset(forStar: star.index))
                                        .frame(maxWidth: .infinity)
                                        .id(star.index)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        if !model.recent.isEmpty { recentCard }
                    }
                }
                .padding()
            }
            .onAppear {
                model.refresh()
                let target = min(model.summary.totalWindDowns, 20)
                Task { proxy.scrollTo(target, anchor: .center) }
            }
        }
        .foregroundStyle(theme.text)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Your sky")
    }

    private func startNext() {
        guard let exercise = model.nextWindDown else { return }
        env.playerRequest = PlayerRequest(exerciseID: exercise.id)
    }

    private var weekCard: some View {
        let done = min(model.summary.windDownsThisWeek, model.summary.weeklyGoal)
        let goal = model.summary.weeklyGoal
        return Card {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(theme.cardBorder, lineWidth: 8)
                    Circle().trim(from: 0, to: CGFloat(done) / CGFloat(max(goal, 1)))
                        .stroke(theme.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(done)/\(goal)").font(.subheadline.bold())
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(done) of \(goal) wind-downs this week").font(.headline)
                    Text("Missed days are fine. Your sky only grows.")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var recentCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recently").font(.headline).accessibilityAddTraits(.isHeader)
                ForEach(model.recent) { item in
                    HStack {
                        Text(item.title)
                        Spacer()
                        Text(item.completedAt, format: .dateTime.month().day())
                            .foregroundStyle(theme.secondaryText)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

private struct StageBanner: View {
    @Environment(\.theme) private var theme
    let stage: SkyStage

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Stage \(stage.number)").font(.caption.weight(.heavy)).textCase(.uppercase)
                Text(stage.name).font(.title3.bold())
            }
            Spacer()
            Text("\(stage.litCount) of \(stage.stars.count) stars").font(.subheadline.bold())
        }
        .foregroundStyle(theme.onAccent)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(shape.fill(theme.accent))
        .background(shape.fill(theme.accentEdge).offset(y: theme.isNight ? 0 : 5))
        .padding(.bottom, theme.isNight ? 0 : 5)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct StarNode: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let star: SkyStar
    let nextTitle: String?
    let onStart: () -> Void
    @State private var pulsing = false

    var body: some View {
        switch star.state {
        case .lit:
            node(fill: theme.moon, edge: theme.moonEdge, symbol: "star.fill", tint: .white, size: 56)
                .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                .accessibilityElement()
                .accessibilityLabel("Star \(star.index + 1), lit")
        case .locked:
            node(fill: theme.cardBorder, edge: theme.secondaryText.opacity(0.25), symbol: "star.fill",
                 tint: theme.secondaryText.opacity(0.4), size: 56)
                .accessibilityElement()
                .accessibilityLabel("Star \(star.index + 1), not lit yet")
        case .next:
            Button(action: onStart) {
                node(fill: theme.accent, edge: theme.accentEdge, symbol: "play.fill", tint: theme.onAccent, size: 68)
            }
            .buttonStyle(.plain)
            .background {
                Circle().fill(theme.accent)
                    .frame(width: 68, height: 68)
                    .scaleEffect(pulsing ? 1.6 : 1)
                    .opacity(pulsing ? 0 : 0.5)
            }
            .overlay(alignment: .top) {
                Text("TONIGHT")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(theme.cardBorder, lineWidth: 2))
                    .offset(y: -30)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: SkyPath.xOffset(forStar: star.index) > 0 ? .leading : .trailing) {
                LumiView(mood: .happy, motion: .float, size: 90)
                    .offset(x: SkyPath.xOffset(forStar: star.index) > 0 ? -100 : 100)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) { pulsing = true }
            }
            .accessibilityLabel(nextTitle.map { "Next star. Start \($0)" } ?? "Next star")
        }
    }

    private func node(fill: Color, edge: Color, symbol: String, tint: Color, size: CGFloat) -> some View {
        ZStack {
            Circle().fill(edge).offset(y: 6)
            Circle().fill(fill)
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .padding(.bottom, 6)
    }
}
