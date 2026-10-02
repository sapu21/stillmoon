import SwiftUI

struct SleepView: View {
    @Environment(\.theme) private var theme
    let model: SleepModel
    @State private var addingEntry = false

    var body: some View {
        List {
            if model.rows.isEmpty {
                ContentUnavailableView("No nights yet", systemImage: "moon.zzz",
                                       description: Text("Add last night with the + button."))
                    .listRowBackground(Color.clear)
            }
            ForEach(model.rows) { row in
                NightRowView(row: row)
                    .listRowBackground(theme.surface)
            }
            .onDelete { offsets in
                let rows = offsets.map { model.rows[$0] }
                rows.forEach { model.delete($0) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Sleep")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { addingEntry = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add a night")
            }
        }
        .sheet(isPresented: $addingEntry) {
            JournalEntryForm { model.save($0) }
        }
        .onAppear { model.refresh() }
    }
}

struct NightRowView: View {
    @Environment(\.theme) private var theme
    let row: NightRow

    private var bedtime: String { row.entry.bedtime.formatted(date: .omitted, time: .shortened) }
    private var wake: String { row.entry.wakeTime.formatted(date: .omitted, time: .shortened) }
    private var duration: String { Format.duration(minutes: row.entry.inBedMinutes) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.entry.wakeTime, format: .dateTime.weekday(.wide).month().day())
                .font(.headline)
            Text("You recorded \(bedtime) to \(wake) · \(duration) in bed")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .accessibilityLabel("You recorded \(bedtime) to \(wake), \(duration) in bed")
            if let checkIn = row.checkIn {
                Text("You felt \(checkIn.restedness) of 5 rested")
                    .font(.subheadline)
            }
            if let note = row.entry.note, !note.isEmpty {
                Text(note)
                    .font(.callout)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .foregroundStyle(theme.text)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
