import SwiftUI

/// Sign in with Apple or Google (PRD §5 step 2). Apple and Google buttons keep their brand colors in every theme.
struct ProviderButtons: View {
    enum Provider { case apple, google }
    enum Intent { case logIn, signUp }

    let intent: Intent
    var isWorking = false
    let onApple: () -> Void
    let onGoogle: () -> Void

    static func title(_ provider: Provider, _ intent: Intent) -> String {
        let name = provider == .apple ? "Apple" : "Google"
        return intent == .logIn ? "Continue with \(name)" : "Sign up with \(name)"
    }

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onApple) {
                Label(Self.title(.apple, intent), systemImage: "apple.logo")
            }
            .buttonStyle(ProviderButtonStyle(fill: .black, text: .white, edge: Color(hex: 0x3A3550), border: nil))
            Button(action: onGoogle) {
                HStack(spacing: 10) {
                    Image("GoogleG").resizable().frame(width: 20, height: 20).accessibilityHidden(true)
                    Text(Self.title(.google, intent))
                }
            }
            .buttonStyle(ProviderButtonStyle(fill: .white, text: Color(hex: 0x231E3A), edge: Color(hex: 0xE2DCEC),
                                             border: Color(hex: 0xE2DCEC)))
        }
        .disabled(isWorking)
        .opacity(isWorking ? 0.6 : 1)
        .overlay { if isWorking { ProgressView() } }
    }
}

private struct ProviderButtonStyle: ButtonStyle {
    let fill: Color
    let text: Color
    let edge: Color
    let border: Color?

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        configuration.label
            .font(.headline)
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(border ?? .clear, lineWidth: 2))
            .offset(y: configuration.isPressed ? 3 : 0)
            .background(shape.fill(edge).offset(y: 5))
            .padding(.bottom, 5)
            .animation(.spring(duration: 0.12), value: configuration.isPressed)
    }
}

/// Returning users. Plan 5 supplies the actions.
struct LoginView: View {
    @Environment(\.theme) private var theme
    var isWorking = false
    let onApple: () -> Void
    let onGoogle: () -> Void
    let onCreateAccount: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                SkyBackdrop().ignoresSafeArea(edges: .top)
                LumiView(mood: .wave, motion: .float, size: 180).padding(.bottom, 36)
            }
            .frame(maxHeight: .infinity)
            VStack(spacing: 8) {
                Text("Welcome back").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                Text("Lumi kept your sky safe. Log in to pick up where you left off.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            VStack(spacing: 14) {
                ProviderButtons(intent: .logIn, isWorking: isWorking, onApple: onApple, onGoogle: onGoogle)
                HStack(spacing: 4) {
                    Text("New to Stillmoon?")
                    Button("Create an account", action: onCreateAccount).fontWeight(.heavy)
                }
                .font(.subheadline.weight(.semibold))
                Label("Your sleep data never leaves your phone.", systemImage: "lock.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(20)
        }
        .foregroundStyle(theme.text)
        .background(theme.background.ignoresSafeArea())
    }
}

/// Account creation inside onboarding. Copy from PRD §5 step 2.
struct SignUpView: View {
    @Environment(\.theme) private var theme
    /// Onboarding position for the progress bar, e.g. (2, 8); nil hides it.
    var step: (value: Int, total: Int)?
    var isWorking = false
    let termsURL: URL
    let privacyURL: URL
    let onApple: () -> Void
    let onGoogle: () -> Void
    let onLogIn: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let step { StepProgress(value: step.value, total: step.total) }
                HStack(alignment: .bottom, spacing: 4) {
                    LumiView(mood: .happy, motion: .float, size: 120)
                    SpeechBubble(text: "Let's keep your stars safe, even on a new phone.").padding(.bottom, 56)
                }
                Text("Create your account").font(.title.bold()).accessibilityAddTraits(.isHeader)
                Text("Keeps your progress, saved exercises and journey safe across devices.")
                    .foregroundStyle(theme.secondaryText)
                Grid(horizontalSpacing: 10) {
                    GridRow {
                        storeTile("icloud", "In your account", "Progress, saved exercises, your sky")
                        storeTile("iphone", "On this iPhone", "Sleep data, check-ins, journal, sounds")
                    }
                }
                ProviderButtons(intent: .signUp, isWorking: isWorking, onApple: onApple, onGoogle: onGoogle)
                    .padding(.top, 8)
                HStack(spacing: 4) {
                    Text("Already have an account?")
                    Button("Log in", action: onLogIn).fontWeight(.heavy)
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                Text(termsLine)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .foregroundStyle(theme.text)
        .tint(theme.accent)
        .background(theme.background.ignoresSafeArea())
    }

    private var termsLine: AttributedString {
        let markdown = "By continuing you agree to the [Terms](\(termsURL.absoluteString)) and [Privacy Policy](\(privacyURL.absoluteString))."
        return (try? AttributedString(markdown: markdown)) ?? AttributedString("By continuing you agree to the Terms and Privacy Policy.")
    }

    private func storeTile(_ symbol: String, _ title: String, _ detail: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol).font(.title3).foregroundStyle(theme.accent).accessibilityHidden(true)
                Text(title).font(.subheadline.bold())
                Text(detail).font(.footnote).foregroundStyle(theme.secondaryText)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview("Log in") {
    LoginView(onApple: {}, onGoogle: {}, onCreateAccount: {})
        .fontDesign(.rounded)
}

#Preview("Sign up") {
    SignUpView(step: (2, 8), termsURL: URL(string: "https://example.com/terms")!,
               privacyURL: URL(string: "https://example.com/privacy")!,
               onApple: {}, onGoogle: {}, onLogIn: {})
        .fontDesign(.rounded)
}
