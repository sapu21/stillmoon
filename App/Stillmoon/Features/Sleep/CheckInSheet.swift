import SwiftUI
import StillmoonCore

/// Morning check-in: Lumi mirrors the chosen restedness. What the user reports stays separate from estimates (PRD principle 3).
struct CheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
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
        let line = LumiDirector.checkIn(level: restedness, isNight: theme.isNight)
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Text("Morning check-in")
                        .font(.footnote.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(theme.secondaryText)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .frame(width: 44, height: 44)
                            .background(theme.accentSoft, in: Circle())
                    }
                    .accessibilityLabel("Cancel")
                }
                Text("How rested do you feel?")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                if let text = line.text { SpeechBubble(text: text) }
                LumiView(mood: line.mood, motion: line.motion, size: 160)
                Text(MoonPhase.label(level: restedness))
                    .font(.title2.bold())
                    .foregroundStyle(theme.accent)
                    .contentTransition(.opacity)
                HStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { level in
                        MoonButton(level: level, isSelected: level == restedness, size: 58) {
                            withAnimation(.spring(duration: 0.3)) { restedness = level }
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Restedness")
                Text("Anything else from last night?")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                FlowLayout(spacing: 8) {
                    Chip(title: "Felt tense at bedtime", isSelected: tense) { tense.toggle() }
                    Chip(title: "Woke up during the night", isSelected: woke) { woke.toggle() }
                    Chip(title: "Trouble sleeping most nights for 3+ weeks", isSelected: persistent) { persistent.toggle() }
                }
                TextField("Add a note (optional)", text: $note, axis: .vertical)
                    .lineLimit(2...5)
                    .padding(12)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(theme.cardBorder, lineWidth: 2))
                Label("This is how you felt. Stillmoon keeps it apart from what your watch estimated.", systemImage: "heart")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Save check-in") {
                    onSave(CheckIn(id: existing?.id ?? UUID(), date: existing?.date ?? .now,
                                   restedness: restedness, tenseAtBedtime: tense, wokeDuringNight: woke,
                                   persistentDifficulty: persistent, note: note.isEmpty ? nil : note))
                    dismiss()
                }
                .buttonStyle(ChunkyButtonStyle())
            }
            .padding(20)
        }
        .foregroundStyle(theme.text)
        .background(theme.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }
}
