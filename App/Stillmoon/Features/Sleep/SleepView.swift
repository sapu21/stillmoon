import SwiftUI

struct SleepView: View {
    @Environment(\.theme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    let model: SleepModel
    @State private var addingEntry = false

    var body: some View {
        List {
            if model.rows.isEmpty {
                ContentUnavailableView("No nights yet", systemImage: "moon.zzz",
                                       description: Text("Add a night with the + button, or connect Apple Health in Settings."))
                    .listRowBackground(Color.clear)
            }
            if !model.isHealthConnected {
                Text("Connect Apple Health in Settings to see estimates from your watch or other devices.")
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryText)
                    .listRowBackground(Color.clear)
            } else if model.healthError {
                Text("Apple Health couldn't be read right now. Your own entries are below.")
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryText)
                    .listRowBackground(Color.clear)
            }
            ForEach(model.rows) { row in
                NavigationLink(value: row) {
                    NightRowView(row: row)
                }
                    .listRowBackground(theme.surface)
                    .deleteDisabled(row.entry == nil)
            }
            .onDelete { offsets in
                let rows = offsets.map { model.rows[$0] }
                Task { for row in rows { await model.deleteEntry(of: row) } }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refresh() } }
        }
        .navigationDestination(for: NightRow.self) { row in
            NightDetailView(row: model.rows.first { $0.morning == row.morning } ?? row,
                            onCorrect: { event, c in Task { await model.correct(event, as: c) } })
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
            JournalEntryForm { entry in Task { await model.save(entry) } }
        }
        .task { await model.refresh() }
    }
}

struct NightRowView: View {
    @Environment(\.theme) private var theme
    let row: NightRow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.morning, format: .dateTime.weekday(.wide).month().day())
                .font(.headline)
            if let report = row.report {
                Text(NightSummary.estimateLine(report))
                    .font(.subheadline)
            }
            if let entry = row.entry {
                Text("You recorded \(Format.duration(minutes: entry.inBedMinutes)) in bed")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }
            if let checkIn = row.checkIn {
                Text("You felt \(checkIn.restedness) of 5 rested")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }
            if let line = NightSummary.soundCountLine(row.soundEvents.count) {
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .foregroundStyle(theme.text)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
