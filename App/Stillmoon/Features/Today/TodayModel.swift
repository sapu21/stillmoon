import Foundation
import Observation
import StillmoonCore

struct ResolvedRecommendation: Identifiable, Hashable {
    let itemID: String
    let kind: ContentKind
    let title: String
    let reason: String
    var id: String { itemID }
    var route: Route { kind == .exercise ? .exercise(itemID) : .article(itemID) }
}

@Observable final class TodayModel {
    static let doctorArticleID = "talk-to-a-doctor"
    /// A journal entry counts as "last night" if its wake time is within this window.
    static let lastNightWindow: TimeInterval = 20 * 3600

    @ObservationIgnored private let store: LocalStore
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let catalog: ContentCatalog
    @ObservationIgnored private let health: HealthDataSource
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var healthBedtimes: [Date] = []
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let calendar: Calendar

    private(set) var greeting = ""
    private(set) var todayCheckIn: CheckIn?
    private(set) var lastNight: JournalEntry?
    private(set) var lastNightReport: NightReport?
    private(set) var recommendations: [ResolvedRecommendation] = []
    private(set) var progress = ProgressSummary(windDownsThisWeek: 0, weeklyGoal: 3, goalMet: false,
                                                totalWindDowns: 0, journeyStage: 0)
    private(set) var showsDifficultyCard = false
    private(set) var showsSnoringNote = false

    init(store: LocalStore, settings: SettingsStore, catalog: ContentCatalog,
         health: HealthDataSource = FakeHealthSource(),
         now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.store = store
        self.settings = settings
        self.catalog = catalog
        self.health = health
        self.clock = now
        self.calendar = calendar
    }

    var awakeAtNightExercise: Exercise? { catalog.exercises.first { $0.category == .awakeAtNight } }
    enum NightPhase { case windDown, awake }

    /// Night mode starts an hour before bedtime; until bedtime that hour is for winding down.
    func nightPhase(at now: Date) -> NightPhase {
        let bedtime = settings.settings.bedtime ?? NightModeResolver.defaultBedtime
        return ClockTime(of: now, calendar: calendar).minutesSinceSixPM < bedtime.minutesSinceSixPM ? .windDown : .awake
    }

    var windDownSuggestion: ResolvedRecommendation? {
        if let rec = recommendations.first(where: { catalog.exercise(id: $0.itemID)?.category == .windDown }) {
            return rec
        }
        guard let exercise = catalog.exercises.first(where: { $0.category == .windDown }) else { return nil }
        return ResolvedRecommendation(itemID: exercise.id, kind: .exercise, title: exercise.title, reason: "")
    }

    var hideProgress: Bool { settings.settings.hideProgress }

    /// "5 min · Audio" for exercises; nil for articles.
    func meta(for rec: ResolvedRecommendation) -> String? {
        guard let exercise = catalog.exercise(id: rec.itemID) else { return nil }
        return "\(Format.exerciseLength(seconds: exercise.durationSeconds)) · \(exercise.format == .audio ? "Audio" : "Text")"
    }

    static func greeting(hour: Int) -> String {
        switch hour {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "It's late. Go gently."
        }
    }

    /// Bedtimes for recommendations: one per night, a Health estimate replacing the journal entry for the same night.
    /// Health values are when sleep began; journal values are when the user went to bed. Both are good enough for the "bedtimes varied" rule.
    static func combinedBedtimes(journal: [Date], health: [Date], calendar: Calendar) -> [Date] {
        var byNight: [Date: Date] = [:]
        for bedtime in journal { byNight[NightWindow.nightKey(for: bedtime, calendar: calendar)] = bedtime }
        for bedtime in health { byNight[NightWindow.nightKey(for: bedtime, calendar: calendar)] = bedtime }
        return Array(byNight.values)
    }

    /// Reads the last 7 nights from Health (when connected), then recomputes everything.
    /// Results are computed into locals and assigned once, so overlapping calls never show a half-cleared state.
    func refreshHealth() async {
        generation += 1
        let mine = generation
        let now = clock()
        var report: NightReport?
        var bedtimes: [Date] = []
        if settings.settings.healthConnected {
            let today = calendar.startOfDay(for: now)
            let oldest = calendar.date(byAdding: .day, value: -6, to: today)!
            do {
                let samples = try await health.sleepSamples(from: NightWindow.forMorning(of: oldest, calendar: calendar).start, to: now)
                for offset in 0..<7 {
                    let morning = calendar.date(byAdding: .day, value: -offset, to: today)!
                    guard let night = SleepReportBuilder.build(samples: samples, window: NightWindow.forMorning(of: morning, calendar: calendar)) else { continue }
                    if offset == 0 { report = night }
                    bedtimes.append(night.sleepStart)
                }
            } catch is CancellationError {
                return
            } catch {
                // Leave locals empty.
            }
            guard !Task.isCancelled, mine == generation else { return }
        }
        lastNightReport = report
        healthBedtimes = bedtimes
        refresh()
    }

    func refresh() {
        let now = clock()
        greeting = Self.greeting(hour: calendar.component(.hour, from: now))
        todayCheckIn = store.todayCheckIn(now: now, calendar: calendar)

        let entries = store.journalEntries()
        lastNight = entries
            .filter { $0.wakeTime <= now && now.timeIntervalSince($0.wakeTime) <= Self.lastNightWindow }
            .max { $0.wakeTime < $1.wakeTime }

        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let input = RecommendationInput(
            goal: settings.settings.goal,
            todayCheckIn: todayCheckIn,
            recentBedtimes: Self.combinedBedtimes(journal: entries.map(\.bedtime).filter { $0 >= weekAgo && $0 <= now },
                                                  health: healthBedtimes, calendar: calendar)
                .filter { $0 >= weekAgo && $0 <= now },
            feedback: store.feedback(),
            catalog: catalog.catalogItems)
        recommendations = RecommendationEngine.recommend(input, calendar: calendar).compactMap { rec in
            guard let title = catalog.title(for: rec.itemID) else { return nil }
            let kind: ContentKind = catalog.exercise(id: rec.itemID) != nil ? .exercise : .article
            return ResolvedRecommendation(itemID: rec.itemID, kind: kind, title: title, reason: rec.reason)
        }

        progress = ProgressCalculator.summary(completions: store.completions(), weeklyGoal: settings.settings.weeklyGoal,
                                              now: now, calendar: calendar)
        showsDifficultyCard = ReferralSignals.showsDifficultyCard(todayCheckIn: todayCheckIn)
        let eightDaysAgo = calendar.date(byAdding: .day, value: -8, to: now)!
        showsSnoringNote = ReferralSignals.showsSnoringNote(events: store.soundEvents(from: eightDaysAgo, to: now),
                                                            now: now, calendar: calendar,
                                                            alreadyShown: settings.settings.snoringNoteShown)
    }

    func dismissSnoringNote() {
        settings.settings.snoringNoteShown = true
        refresh()
    }

    /// One check-in per day: a second save today updates the first.
    func saveCheckIn(_ checkIn: CheckIn) {
        var checkIn = checkIn
        if let existing = todayCheckIn ?? store.todayCheckIn(now: clock(), calendar: calendar) {
            checkIn.id = existing.id
        }
        store.saveCheckIn(checkIn)
        refresh()
    }

    func saveJournalEntry(_ entry: JournalEntry) {
        store.saveJournalEntry(entry)
        refresh()
    }

    func rate(_ itemID: String, _ rating: FeedbackRating) {
        store.addFeedback(RecommendationFeedback(itemID: itemID, rating: rating, at: clock()))
        refresh()
    }
}
