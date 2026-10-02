import Foundation
import Observation
import StillmoonCore

/// One morning: what a device estimated (report), what the user recorded (entry) and how they felt (checkIn).
struct NightRow: Identifiable, Hashable {
    let morning: Date
    let report: NightReport?
    let entry: JournalEntry?
    let checkIn: CheckIn?
    let soundEvents: [SoundEvent]
    var id: Date { morning }

    init(morning: Date, report: NightReport?, entry: JournalEntry?, checkIn: CheckIn?, soundEvents: [SoundEvent] = []) {
        self.morning = morning
        self.report = report
        self.entry = entry
        self.checkIn = checkIn
        self.soundEvents = soundEvents
    }
}

@Observable final class SleepModel {
    static let historyDays = 14

    @ObservationIgnored private let store: LocalStore
    @ObservationIgnored private let health: HealthDataSource
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let calendar: Calendar

    @ObservationIgnored private var generation = 0

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
        generation += 1
        let mine = generation
        let now = clock()
        let today = calendar.startOfDay(for: now)
        var reports: [Date: NightReport] = [:]
        var failed = false

        if isHealthConnected {
            let oldestMorning = calendar.date(byAdding: .day, value: -(Self.historyDays - 1), to: today)!
            let from = NightWindow.forMorning(of: oldestMorning, calendar: calendar).start
            do {
                let samples = try await health.sleepSamples(from: from, to: now)
                for offset in 0..<Self.historyDays {
                    let morning = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: today)!)
                    let window = NightWindow.forMorning(of: morning, calendar: calendar)
                    if let report = SleepReportBuilder.build(samples: samples, window: window) {
                        reports[morning] = report
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                failed = true
            }
        }
        guard !Task.isCancelled, mine == generation else { return }
        healthError = failed

        let entriesByMorning = Dictionary(grouping: store.journalEntries()) { calendar.startOfDay(for: $0.wakeTime) }
        let checkIns = store.checkIns()
        let oldestMorning = calendar.date(byAdding: .day, value: -(Self.historyDays - 1), to: today)!
        let windows: [(morning: Date, window: NightWindow)] = (0..<Self.historyDays).map { offset in
            let morning = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: today)!)
            return (morning, NightWindow.forMorning(of: morning, calendar: calendar))
        }
        var eventsByMorning: [Date: [SoundEvent]] = [:]
        let allEvents = store.soundEvents(from: NightWindow.forMorning(of: oldestMorning, calendar: calendar).start, to: now)
        for event in allEvents {
            if let hit = windows.first(where: { $0.window.start <= event.at && event.at < $0.window.end }) {
                eventsByMorning[hit.morning, default: []].append(event)
            } else {
                let next = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: event.at))!
                eventsByMorning[next, default: []].append(event)
            }
        }
        let mornings = Set(reports.keys).union(entriesByMorning.keys).union(eventsByMorning.keys)
        rows = mornings.sorted(by: >).map { morning in
            NightRow(morning: morning,
                     report: reports[morning],
                     entry: entriesByMorning[morning]?.first,
                     checkIn: checkIns.first { calendar.isDate($0.date, inSameDayAs: morning) },
                     soundEvents: (eventsByMorning[morning] ?? []).sorted { $0.at < $1.at })
        }
    }

    func correct(_ event: SoundEvent, as correction: SoundCorrection) async {
        store.setCorrection(correction, forEvent: event.id)
        await refresh()
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
