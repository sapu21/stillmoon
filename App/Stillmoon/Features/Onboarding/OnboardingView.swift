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
        VStack(alignment: .leading, spacing: 24) {
            if model.canGoBack {
                Button { model.back() } label: { Label("Back", systemImage: "chevron.left") }
            }
            Spacer()
            switch model.step {
            case .welcome:
                Text("Stillmoon").font(.largeTitle.weight(.semibold))
                Text("Understand your nights. Find a calmer next step.").font(.title2)
                primary("Get started") { model.next() }
            case .goal:
                Text("What would help most?").font(.title.weight(.semibold))
                ForEach(Goal.allCases, id: \.self) { goal in
                    Button { model.chooseGoal(goal) } label: {
                        Text(goal.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                }
            case .schedule:
                Text("When do you usually sleep?").font(.title.weight(.semibold))
                Text("This sets when Stillmoon turns calm and dim. You can change it any time.")
                    .foregroundStyle(theme.secondaryText)
                DatePicker("Bedtime", selection: clock($model.bedtime), displayedComponents: .hourAndMinute)
                DatePicker("Wake time", selection: clock($model.wakeTime), displayedComponents: .hourAndMinute)
                primary("Continue") { model.next() }
                Button("Skip for now") { model.skipSchedule() }
            case .health:
                Text("Add your watch's estimates?").font(.title.weight(.semibold))
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
                Button("Not now") { model.next() }
                    .disabled(connecting)
            case .microphone:
                Text("Listen for sounds at night?").font(.title.weight(.semibold))
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
                Button("Not now") { model.next() }
                    .disabled(connecting)
            case .privacy:
                Text("Your nights stay yours").font(.title.weight(.semibold))
                VStack(alignment: .leading, spacing: 12) {
                    Label("Your journal and check-ins stay on this iPhone.", systemImage: "iphone")
                    Label("Nothing you write is read or analyzed.", systemImage: "text.badge.xmark")
                    Label("You can delete everything from Settings at any time.", systemImage: "trash")
                }
                primary("Continue") { model.next() }
            case .firstExercise:
                Text("Try a few calm minutes?").font(.title.weight(.semibold))
                Text("Gentle breathing takes about 5 minutes. No sensors needed.")
                    .foregroundStyle(theme.secondaryText)
                primary("Start gentle breathing") {
                    model.finish()
                    env.playerRequest = PlayerRequest(exerciseID: OnboardingModel.firstExerciseID)
                }
                Button("Go to Today") { model.finish() }
            }
            Spacer()
        }
        .padding(24)
        .foregroundStyle(theme.text)
        .tint(theme.accent)
        .background(theme.background.ignoresSafeArea())
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func clock(_ binding: Binding<ClockTime>) -> Binding<Date> {
        Binding(get: { binding.wrappedValue.date(on: .now, calendar: .current) },
                set: { binding.wrappedValue = ClockTime(of: $0, calendar: .current) })
    }
}
