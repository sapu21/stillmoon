import SwiftUI
import UIKit

/// Always dim (PRD §2 night interaction): large controls, minimal text, no reward animation.
struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: PlayerModel
    private let theme = Theme.night

    init(model: PlayerModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        VStack(spacing: 32) {
            HStack {
                Button { dismiss() } label: {
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
                try? await Task.sleep(for: .seconds(1))
                model.tick()
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            model.play()
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}
