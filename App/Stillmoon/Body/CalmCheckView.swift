import SwiftUI

/// One side of a calm check: "How tense do you feel?" plus an optional camera heart reading.
/// Everything here is optional; Skip is always one tap away.
struct CalmCheckView: View {
    enum Side { case before, after }
    @Environment(\.theme) private var theme
    let side: Side
    let flow: CalmCheckFlow
    /// Called once, with the final answer, when this side finishes (not on every tap).
    let onTension: (Int) -> Void
    let onDone: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var camera = PulseCamera()
    @State private var tension: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(side == .before ? "Before you start" : "How do you feel now?")
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("A quick check you can compare afterwards. Nothing here is a score.")
                    .foregroundStyle(theme.secondaryText)

                Text("How tense do you feel?").font(.headline)
                FlowLayout(spacing: 8) {
                    ForEach(1...5, id: \.self) { level in
                        Chip(title: TensionScale.label(level), isSelected: tension == level) {
                            tension = level
                            flow.recordTension(level)
                        }
                    }
                }

                if PulseCamera.isAvailable { pulseCard }

                Button(side == .before ? "Start the exercise" : "Done") { finish() }
                    .buttonStyle(ChunkyButtonStyle())
                    .padding(.top, 8)
                if tension == nil, !hasReading {
                    Button("Skip") { finish() }
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(20)
        }
        .onDisappear { camera.stop() }
        // Leaving the app interrupts the camera; start the reading over rather than keep a skewed one.
        .onChange(of: scenePhase) { _, phase in if phase != .active { camera.stop() } }
        .onChange(of: camera.state) { _, state in
            if case .finished(let result) = state { flow.recordPulse(result) }
        }
    }

    private var hasReading: Bool {
        if case .finished(.reading) = camera.state { return true }
        return false
    }

    private func finish() {
        camera.stop()
        let final = side == .before ? flow.finishBefore() : flow.finishAfter()
        if let final { onTension(final) }
        onDone()
    }

    @ViewBuilder private var pulseCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Heart rate (optional)").font(.headline)
                switch camera.state {
                case .idle:
                    Text("Rest a fingertip over the back camera and flash for \(Int(PulseCamera.seconds)) seconds. Sit still and breathe normally.")
                        .foregroundStyle(theme.secondaryText)
                    Button { Task { await camera.start() } } label: {
                        Label("Check my pulse", systemImage: "heart")
                    }
                    .buttonStyle(ChunkyButtonStyle(kind: .secondary))
                case .preparing(let covering):
                    Text(covering ? "Hold still while the camera settles…" : "Cover the camera and flash fully with your fingertip.")
                        .font(.subheadline.weight(.semibold))
                    Button("Stop") { camera.stop() }
                        .font(.headline)
                case .measuring(let progress, let covering):
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().stroke(theme.cardBorder, lineWidth: 8)
                            Circle().trim(from: 0, to: progress)
                                .stroke(theme.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(Int((1 - progress) * PulseCamera.seconds))")
                                .font(.headline.monospacedDigit())
                        }
                        .frame(width: 64, height: 64)
                        .accessibilityElement()
                        .accessibilityLabel("\(Int((1 - progress) * PulseCamera.seconds)) seconds left")
                        Text(covering ? "Good. Keep still." : "Cover the camera and flash fully with your fingertip.")
                            .font(.subheadline.weight(.semibold))
                    }
                    Button("Stop") { camera.stop() }
                        .font(.headline)
                case .finished(.reading(let bpm, _)):
                    Text("Heart rate \(Int(bpm.rounded())) bpm").font(.title3.bold())
                    Text(CalmCheckLine.Source.camera.label)
                        .font(.footnote)
                        .foregroundStyle(theme.secondaryText)
                case .finished(.unclear(let issue)):
                    Text(message(for: issue)).foregroundStyle(theme.secondaryText)
                    Button("Try again") { Task { await camera.start() } }
                        .font(.headline)
                case .failed(let message):
                    Text(message).foregroundStyle(theme.secondaryText)
                }
            }
        }
    }

    private func message(for issue: PulseIssue) -> String {
        switch issue {
        case .noFinger: "Couldn't see your fingertip over the camera. Cover the camera and flash fully and try again."
        case .tooShort, .noisy: "Couldn't get a clear reading. Rest your hand, keep still, press lightly and try again."
        }
    }
}

/// A result line with its source underneath, so estimates and answers never blur together.
struct CalmLineView: View {
    @Environment(\.theme) private var theme
    let line: CalmCheckLine

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(line.text).font(.headline)
            Text(line.source.label).font(.footnote).foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
