import SwiftUI

struct JournalEntryForm: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entry: JournalEntry
    private let onSave: (JournalEntry) -> Void

    init(entry: JournalEntry? = nil, now: Date = .now, calendar: Calendar = .current,
         onSave: @escaping (JournalEntry) -> Void) {
        self.onSave = onSave
        _entry = State(initialValue: entry ?? JournalEntry.defaultEntry(now: now, calendar: calendar))
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Went to bed", selection: $entry.bedtime)
                DatePicker("Woke up", selection: $entry.wakeTime)
                TextField("Anything to note? (optional)",
                          text: Binding(get: { entry.note ?? "" }, set: { entry.note = $0.isEmpty ? nil : $0 }),
                          axis: .vertical)
                    .lineLimit(3...6)
                if let message = entry.validationMessage() {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Your night")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(entry)
                        dismiss()
                    }
                    .disabled(entry.validationMessage() != nil)
                }
            }
        }
    }
}
