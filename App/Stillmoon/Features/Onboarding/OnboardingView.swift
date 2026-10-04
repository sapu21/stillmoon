import SwiftUI
import StillmoonCore

struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    @State private var model: OnboardingModel
    @State private var connecting = false

    init(settings: SettingsStore) {
        _model = State(initialValue: OnboardingModel(settings: settings))
    }

    var body: some View {
        let line = LumiDirector.onboarding(model.step)
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Button { model.back() } label: {
                    Image(systemName: "chevron.left").font(.headline).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Back")
                .disabled(connecting || !model.canGoBack)
                .opacity(model.canGoBack ? 1 : 0)
                .accessibilityHidden(!model.canGoBack)
                StepProgress(value: model.step.rawValue + 1, total: OnboardingModel.Step.allCases.count)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .bottom, spacing: 4) {
                        LumiView(mood: line.mood, motion: line.motion, size: 120)
                        if let text = line.text {
                            SpeechBubble(text: text).padding(.bottom, 56)
                        }
                    }
                    stepContent
                }
                .padding(.vertical, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.horizontal, 20)
        .foregroundStyle(theme.text)
        .tint(theme.accent)
        .background(theme.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: model.step)
    }

    @ViewBuilder private var stepContent: some View {
        switch model.step {
        case .welcome:
            Text("Stillmoon").font(.largeTitle.bold())
            Text("Understand your nights. Find a calmer next step.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
            privacyNote
            primary("Get started") { model.next() }
        case .goal:
            Text("What brings you here?").font(.title.bold())
            ForEach(Goal.allCases, id: \.self) { goal in
                let chosen = goal == model.goal
                Button { model.chooseGoal(goal) } label: { GoalCard(goal: goal) }
                    .buttonStyle(TileButtonStyle(fill: chosen ? theme.accentSoft : theme.surface,
                                                 border: chosen ? theme.accent : theme.cardBorder))
                    .accessibilityLabel(goal.title)
                    .accessibilityHint(goal.subtitle)
            }
        case .schedule:
            Text("When do you usually sleep?").font(.title.bold())
            Text("This sets when Stillmoon turns calm and dim. You can change it any time.")
                .foregroundStyle(theme.secondaryText)
            Card {
                VStack(spacing: 8) {
                    DatePicker("Bedtime", selection: clock($model.bedtime), displayedComponents: .hourAndMinute)
                    Divider()
                    DatePicker("Wake time", selection: clock($model.wakeTime), displayedComponents: .hourAndMinute)
                }
            }
            primary("Continue") { model.next() }
            secondary("Skip for now") { model.skipSchedule() }
        case .health:
            Text("Add your watch's estimates?").font(.title.bold())
            Text("Stillmoon can read sleep from Apple Health and save finished exercises as Mindful Minutes. Your sleep data stays on this iPhone.")
                .foregroundStyle(theme.secondaryText)
            primary("Connect Apple Health") {
                guard !connecting else { return }
                connecting = true
                Task {
                    _ = await env.connectHealth()
                    model.next()
                    connecting = false
                }
            }
            .disabled(connecting)
            secondary("Not now") { model.next() }
                .disabled(connecting)
        case .microphone:
            Text("Listen for sounds at night?").font(.title.bold())
            Text("During a sleep session you start, Stillmoon can notice snoring-like, speech-like and cough-like sounds. Sound is analyzed on this iPhone and never recorded. You can turn this off at any time.")
                .foregroundStyle(theme.secondaryText)
            primary("Turn on sound detection") {
                guard !connecting else { return }
                connecting = true
                Task {
                    env.settings.settings.soundDetectionEnabled = await env.sound.requestPermission()
                    connecting = false
                    model.next()
                }
            }
            .disabled(connecting)
            secondary("Not now") { model.next() }
                .disabled(connecting)
        case .privacy:
            Text("Your nights stay yours").font(.title.bold())
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Your journal and check-ins stay on this iPhone.", systemImage: "iphone")
                    Label("Nothing you write is read or analyzed.", systemImage: "text.badge.xmark")
                    Label("You can delete everything from Settings at any time.", systemImage: "trash")
                }
            }
            primary("Continue") { model.next() }
        case .firstExercise:
            Text("Try a few calm minutes?").font(.title.bold())
            Text("Gentle breathing takes about 5 minutes. No sensors needed.")
                .foregroundStyle(theme.secondaryText)
            primary("Start gentle breathing") {
                model.finish()
                env.playerRequest = PlayerRequest(exerciseID: OnboardingModel.firstExerciseID)
            }
            secondary("Go to Today") { model.finish() }
        }
    }

    private var privacyNote: some View {
        Label("Your sleep data stays on your phone.", systemImage: "lock.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(theme.secondaryText)
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(ChunkyButtonStyle())
            .padding(.top, 4)
    }

    private func secondary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 44)
    }

    private func clock(_ binding: Binding<ClockTime>) -> Binding<Date> {
        Binding(get: { binding.wrappedValue.date(on: .now, calendar: .current) },
                set: { binding.wrappedValue = ClockTime(of: $0, calendar: .current) })
    }
}

private struct GoalCard: View {
    @Environment(\.theme) private var theme
    let goal: Goal

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemName: goal.symbol, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title).font(.headline).foregroundStyle(theme.text)
                Text(goal.subtitle).font(.subheadline).foregroundStyle(theme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .multilineTextAlignment(.leading)
        .padding(14)
    }
}
