import SwiftUI
import StillmoonCore

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false
    @State private var connecting = false
    @State private var soundDenied = false

    var body: some View {
        @Bindable var settings = env.settings
        NavigationStack {
            Form {
                Section("Your goal") {
                    Picker("Goal", selection: $settings.settings.goal) {
                        ForEach(Goal.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                }
                Section {
                    if env.settings.settings.healthConnected {
                        LabeledContent("Apple Health", value: "Connected")
                        Button("Disconnect Apple Health") { env.settings.settings.healthConnected = false }
                    } else {
                        Button("Connect Apple Health") {
                            guard !connecting else { return }
                            connecting = true
                            Task {
                                _ = await env.connectHealth()
                                connecting = false
                            }
                        }
                        .disabled(connecting)
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Disconnecting stops reading sleep and saving Mindful Minutes. To change permissions, open the Health app, then Sharing, Apps, Stillmoon.")
                }
                Section {
                    Toggle("Use my bedtime and wake time", isOn: Binding(
                        get: { settings.settings.bedtime != nil },
                        set: { on in
                            settings.settings.bedtime = on ? ClockTime(hour: 22, minute: 0) : nil
                            settings.settings.wakeTime = on ? ClockTime(hour: 7, minute: 0) : nil
                        }))
                    if let bedtime = settings.settings.bedtime, let wake = settings.settings.wakeTime {
                        DatePicker("Bedtime", selection: clockBinding(bedtime) { settings.settings.bedtime = $0 },
                                   displayedComponents: .hourAndMinute)
                        DatePicker("Wake time", selection: clockBinding(wake) { settings.settings.wakeTime = $0 },
                                   displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Schedule")
                } footer: {
                    Text("Night mode starts an hour before bedtime. Without times, it runs from 9pm to 7am.")
                }
                if env.flags.soundDetection {
                    Section {
                        Toggle("Listen for sounds during a sleep session", isOn: Binding(
                            get: { settings.settings.soundDetectionEnabled },
                            set: { on in
                                if on {
                                    Task {
                                        let granted = await env.sound.requestPermission()
                                        settings.settings.soundDetectionEnabled = granted
                                        soundDenied = !granted
                                    }
                                } else {
                                    settings.settings.soundDetectionEnabled = false
                                    soundDenied = false
                                }
                            }))
                    } header: {
                        Text("Sound detection")
                    } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Only during a session you start. Labels, times and confidence are saved on this iPhone; sound is never recorded.")
                            if soundDenied {
                                Text("Microphone access is off. You can turn it on in the Settings app, under Privacy & Security, Microphone.")
                            }
                        }
                    }
                }
                Section("Progress") {
                    Stepper("Weekly goal: \(settings.settings.weeklyGoal) wind-downs",
                            value: $settings.settings.weeklyGoal, in: 1...7)
                    Toggle("Hide progress", isOn: $settings.settings.hideProgress)
                }
                Section("Night mode") {
                    Picker("Night mode", selection: $settings.settings.nightModeOverride) {
                        Text("Automatic").tag(NightModeOverride.automatic)
                        Text("Always on").tag(NightModeOverride.on)
                        Text("Off").tag(NightModeOverride.off)
                    }
                }
                Section {
                    Button("Delete all my data on this iPhone", role: .destructive) { confirmingDelete = true }
                } footer: {
                    Text("Removes your nights, check-ins, saved items and progress from this iPhone, and resets your goal, schedule and night mode.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete all your data on this iPhone?", isPresented: $confirmingDelete,
                                titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) { env.deleteAllLocalData() }
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    private func clockBinding(_ value: ClockTime, set: @escaping (ClockTime) -> Void) -> Binding<Date> {
        Binding(get: { value.date(on: .now, calendar: .current) },
                set: { set(ClockTime(of: $0, calendar: .current)) })
    }
}
