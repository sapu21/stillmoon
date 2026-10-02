import SwiftUI
import UIKit
import StillmoonCore

/// Always dim (PRD §2 night interaction): large controls, minimal text, no reward animation.
struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: PlayerModel
    private let theme = Theme.night

    init(exercise: Exercise, store: LocalStore) {
        _model = State(initialValue: PlayerModel(exercise: exercise, store: store))
    }

    var body: some View {
        VStack(spacing: 32) {
            HStack {
                Button { model.pause(); dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(model.isComplete ? "Close" : "End exercise")
                Spacer()
            }
            Spacer()
            if model.isComplete {
                Text("Well done. Rest now.")
                    .font(.title.weight(.medium))
                    .multilineTextAlignment(.center)
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            } else {
                Text(model.exercise.title)
                    .font(.headline)
                    .foregroundStyle(theme.secondaryText)
                Text(model.currentStep.text)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 120)
                Text(Format.clock(seconds: model.remainingSeconds))
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(theme.secondaryText)
                    .accessibilityLabel("\(Format.exerciseLength(seconds: model.remainingSeconds)) left")
                HStack(spacing: 40) {
                    Button { model.togglePlay() } label: {
                        Image(systemName: model.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 88))
                    }
                    .accessibilityLabel(model.isPlaying ? "Pause" : "Play")
                    Button { model.skipStep() } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.title)
                            .frame(width: 44, height: 44)
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
        .onDisappear {
            model.pause()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
