import Foundation
import Observation
import StillmoonCore

/// One morning: what a device estimated (report), what the user recorded (entry) and how they felt (checkIn).
struct NightRow: Identifiable, Hashable {
    let morning: Date
    let report: NightReport?
    let entry: JournalEntry?
    let checkIn: CheckIn?
    var id: Date { morning }
}

@Observable final class SleepModel {
    static let historyDays = 14

    @ObservationIgnored private let store: LocalStore
    @ObservationIgnored private let health: HealthDataSource
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let calendar: Calendar

    private(set) var rows: [NightRow] = []
    private(set) var healthError = false

    init(store: LocalStore, health: HealthDataSource, settings: SettingsStore,
         now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.store = store
        self.health = health
        self.settings = settings
        self.clock = now
        self.calendar = calendar
    }

    var isHealthConnected: Bool { settings.settings.healthConnected }

    func refresh() async {
        let now = clock()
        let today = calendar.startOfDay(for: now)
        var reports: [Date: NightReport] = [:]
        healthError = false

        if isHealthConnected {
            let oldestMorning = calendar.date(byAdding: .day, value: -(Self.historyDays - 1), to: today)!
            let from = NightWindow.forMorning(of: oldestMorning, calendar: calendar).start
            do {
                let samples = try await health.sleepSamples(from: from, to: now)
                for offset in 0..<Self.historyDays {
                    let morning = calendar.date(byAdding: .day, value: -offset, to: today)!
                    let window = NightWindow.forMorning(of: morning, calendar: calendar)
                    if let report = SleepReportBuilder.build(samples: samples, window: window) {
                        reports[morning] = report
                    }
                }
            } catch {
                healthError = true
            }
        }

        let entriesByMorning = Dictionary(grouping: store.journalEntries()) { calendar.startOfDay(for: $0.wakeTime) }
        let checkIns = store.checkIns()
        let mornings = Set(reports.keys).union(entriesByMorning.keys)
        rows = mornings.sorted(by: >).map { morning in
            NightRow(morning: morning,
                     report: reports[morning],
                     entry: entriesByMorning[morning]?.first,
                     checkIn: checkIns.first { calendar.isDate($0.date, inSameDayAs: morning) })
        }
    }

    func save(_ entry: JournalEntry) async {
        store.saveJournalEntry(entry)
        await refresh()
    }

    /// Health data is managed in the Health app; only the user's own entry is deleted here.
    func deleteEntry(of row: NightRow) async {
        if let entry = row.entry { store.deleteJournalEntry(id: entry.id) }
        await refresh()
    }
}
