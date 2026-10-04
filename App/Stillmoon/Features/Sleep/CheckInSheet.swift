import SwiftUI
import StillmoonCore

struct CheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let existing: CheckIn?
    private let onSave: (CheckIn) -> Void
    @State private var restedness: Int
    @State private var tense: Bool
    @State private var woke: Bool
    @State private var persistent: Bool
    @State private var note: String

    init(existing: CheckIn?, initialLevel: Int? = nil, onSave: @escaping (CheckIn) -> Void) {
        self.existing = existing
        self.onSave = onSave
        _restedness = State(initialValue: initialLevel ?? existing?.restedness ?? 3)
        _tense = State(initialValue: existing?.tenseAtBedtime ?? false)
        _woke = State(initialValue: existing?.wokeDuringNight ?? false)
        _persistent = State(initialValue: existing?.persistentDifficulty ?? false)
        _note = State(initialValue: existing?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("How rested do you feel?") {
                    Picker("Rested", selection: $restedness) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityValue("\(restedness) of 5")
                    .accessibilityHint("1 means not at all rested, 5 means very rested")
                    HStack {
                        Text("Not at all")
                        Spacer()
                        Text("Very")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Section {
                    Toggle("I felt tense at bedtime", isOn: $tense)
                    Toggle("I was awake during the night", isOn: $woke)
                    Toggle("Trouble sleeping most nights for 3+ weeks", isOn: $persistent)
                }
                Section("Note") {
                    TextField("Optional", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("How do you feel?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(CheckIn(id: existing?.id ?? UUID(), date: existing?.date ?? .now,
                                       restedness: restedness, tenseAtBedtime: tense, wokeDuringNight: woke,
                                       persistentDifficulty: persistent, note: note.isEmpty ? nil : note))
                        dismiss()
                    }
                }
            }
        }
    }
}
