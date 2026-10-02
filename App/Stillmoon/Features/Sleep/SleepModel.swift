import Foundation
import Observation
import StillmoonCore

struct NightRow: Identifiable, Hashable {
    let entry: JournalEntry
    /// The check-in made on the morning of the wake time, if any.
    let checkIn: CheckIn?
    var id: UUID { entry.id }
}

@Observable final class SleepModel {
    @ObservationIgnored private let store: LocalStore
    @ObservationIgnored private let calendar: Calendar
    private(set) var rows: [NightRow] = []

    init(store: LocalStore, calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
    }

    func refresh() {
        let checkIns = store.checkIns()
        rows = store.journalEntries().map { entry in
            NightRow(entry: entry, checkIn: checkIns.first { calendar.isDate($0.date, inSameDayAs: entry.wakeTime) })
        }
    }

    func save(_ entry: JournalEntry) {
        store.saveJournalEntry(entry)
        refresh()
    }

    func delete(_ row: NightRow) {
        store.deleteJournalEntry(id: row.entry.id)
        refresh()
    }
}
