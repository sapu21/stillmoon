import SwiftUI
import UIKit
import StillmoonCore

/// Always dim (PRD §2 night interaction): large controls, minimal text, no reward animation.
/// A finished daytime wind-down hands over to `CompletionView`.
struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    /// The app's theme outside the player (the player itself is always dim).
    @Environment(\.theme) private var appTheme
    @State private var model: PlayerModel
    @State private var celebration: CompletionSummary?
    private let weeklyGoal: Int
    private let savesToHealth: Bool
    private let hideProgress: Bool
    private let theme = Theme.night

    init(exercise: Exercise, store: LocalStore, weeklyGoal: Int = 3, savesToHealth: Bool = false,
         hideProgress: Bool = false, onFinish: ((DateInterval) -> Void)? = nil) {
        _model = State(initialValue: PlayerModel(exercise: exercise, store: store, onFinish: onFinish))
        self.weeklyGoal = weeklyGoal
        self.savesToHealth = savesToHealth
        self.hideProgress = hideProgress
    }

    var body: some View {
        Group {
            if let celebration {
                CompletionView(summary: celebration) { dismiss() }
                    .transition(.opacity)
            } else {
                player
            }
        }
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { break }
                guard !Task.isCancelled else { break }
                model.tick()
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            if model.stepIndex == 0 && model.elapsedInStep == 0 && !model.isComplete { model.play() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.pause() }
        }
        .onChange(of: model.isComplete) { _, done in
            guard done, CompletionStyle.style(for: model.exercise.category, isNight: appTheme.isNight) == .celebrate else { return }
            let summary = CompletionSummary(progress: model.progress(weeklyGoal: weeklyGoal, calendar: .current),
                                            playedSeconds: model.playedSeconds, savedToHealth: savesToHealth,
                                            hideProgress: hideProgress)
            withAnimation(.easeInOut(duration: 0.4)) { celebration = summary }
        }
        .onDisappear {
            model.pause()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var total: Int { model.exercise.durationSeconds }

    private var player: some View {
        VStack(spacing: 24) {
            HStack {
                Button { model.pause(); dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .background(theme.surface, in: Circle())
                }
                .accessibilityLabel(model.isComplete ? "Close" : "End exercise")
                Spacer()
                Text(model.exercise.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.secondaryText)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer()
            if model.isComplete {
                LumiView(mood: .sleepy, motion: .drift, size: 140)
                Text("Well done. Rest now.")
                    .font(.title.weight(.semibold))
                    .multilineTextAlignment(.center)
                Button("Done") { dismiss() }
                    .buttonStyle(ChunkyButtonStyle())
                    .padding(.horizontal, 40)
            } else {
                ZStack {
                    BreathingRings()
                    LumiView(mood: .calm, motion: .breathe(period: 8), size: 170)
                }
                .frame(width: 280, height: 280)
                Text(model.currentStep.text)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 90)
                VStack(spacing: 6) {
                    ProgressView(value: Double(total - model.remainingSeconds), total: Double(max(total, 1)))
                        .tint(theme.accent)
                        .accessibilityHidden(true)
                    HStack {
                        Text(Format.clock(seconds: total - model.remainingSeconds))
                            .accessibilityHidden(true)
                        Spacer()
                        Text(Format.clock(seconds: model.remainingSeconds))
                            .accessibilityLabel("\(Format.exerciseLength(seconds: model.remainingSeconds)) left")
                    }
                    .font(.footnote.monospacedDigit().weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                }
                HStack(spacing: 40) {
                    Button { model.togglePlay() } label: {
                        Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(theme.onAccent)
                            .frame(width: 84, height: 84)
                            .background(theme.accent, in: Circle())
                    }
                    .accessibilityLabel(model.isPlaying ? "Pause" : "Play")
                    Button { model.skipStep() } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.title2)
                            .frame(width: 56, height: 56)
                            .background(theme.surface, in: Circle())
                    }
                    .accessibilityLabel("Next step")
                }
            }
            Spacer()
        }
        .padding()
        .foregroundStyle(theme.text)
        .tint(theme.accent)
        .background(theme.background.ignoresSafeArea())
        .environment(\.theme, theme)
        .preferredColorScheme(.dark)
    }
}

/// Two soft rings breathing on the same 8 s cycle as Lumi.
private struct BreathingRings: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let k = reduceMotion ? 0.5 : LumiAnimation.wave(context.date.timeIntervalSinceReferenceDate, period: 8)
            ZStack {
                Circle().fill(theme.accentSoft.opacity(0.6)).scaleEffect(0.78 + 0.3 * k)
                Circle().fill(theme.accentSoft).padding(40).scaleEffect(0.78 + 0.3 * k)
            }
        }
        .accessibilityHidden(true)
    }
}
