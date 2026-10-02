import SwiftUI

/// Full-screen, always dim. Large controls, no counts, no animation (PRD §7 Sound session).
struct SoundSessionView: View {
    @Environment(AppEnvironment.self) private var env
    private let theme = Theme.night

    var body: some View {
        GeometryReader { proxy in
        ScrollView {
        VStack(spacing: 28) {
            Spacer()
            Text("Listening for sounds")
                .font(.title.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if case .running(let since) = env.sound.state {
                Text("Since \(since.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(theme.secondaryText)
            } else if case .paused = env.sound.state {
                Text("Paused").foregroundStyle(theme.secondaryText)
            }
            Text("The orange dot at the top of the screen means the microphone is on. Sound is analyzed on this iPhone and never recorded.")
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.secondaryText)
            Text("Place your phone on a stable surface, ideally charging.")
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.secondaryText)
            if env.sound.lastError != nil {
                Text("Listening stopped. Tap Resume to try again.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer()
            if case .paused = env.sound.state {
                Button("Resume") { do { try env.sound.resume() } catch { } }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            } else {
                Button("Pause") { env.sound.pause() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
            Button("End session") { env.sound.stop() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
        }
        }
        .foregroundStyle(theme.text)
        .tint(theme.accent)
        .background(theme.background.ignoresSafeArea())
        .environment(\.theme, theme)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }
}

/// Starts a session: battery confirmation first, plain message on failure.
struct SoundStartButton: View {
    @Environment(AppEnvironment.self) private var env
    @State private var confirmingBattery = false
    @State private var message: String?
    @State private var starting = false
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                if env.sound.needsBatteryWarning() { confirmingBattery = true } else { start() }
            } label: {
                Label("Start sleep session", systemImage: "waveform")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(starting)
            if let message {
                Text(message).font(.footnote).foregroundStyle(theme.secondaryText)
            }
        }
        .confirmationDialog("Your battery is below 30% and not charging.", isPresented: $confirmingBattery,
                            titleVisibility: .visible) {
            Button("Start anyway") { start() }
        } message: {
            Text("A sleep session listens all night. Plugging in your phone is best.")
        }
    }

    private func start() {
        guard !starting else { return }
        starting = true
        Task {
            do {
                try await env.sound.start()
                message = nil
            } catch SoundSessionError.permissionDenied {
                message = "Microphone access is off. You can turn it on in the Settings app, under Privacy & Security, Microphone."
            } catch {
                message = "The sleep session couldn't start. Please try again."
            }
            starting = false
        }
    }
}
