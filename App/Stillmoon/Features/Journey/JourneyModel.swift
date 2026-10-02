import Foundation
import Observation
import StillmoonCore

struct RecentCompletion: Identifiable, Hashable {
    let id: UUID
    let title: String
    let completedAt: Date
}

@Observable final class JourneyModel {
    /// Stage 0 is the empty path; 1...6 are the illustrated stages (PRD §2).
    static let stageNames = ["The path begins", "First light", "Quiet meadow", "Willow bend",
                             "Still lake", "Hilltop", "Moonrise"]
    static let recentLimit = 10

    @ObservationIgnored private let store: LocalStore
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let catalog: ContentCatalog
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: Calendar

    private(set) var summary = ProgressSummary(windDownsThisWeek: 0, weeklyGoal: 3, goalMet: false,
                                               totalWindDowns: 0, journeyStage: 0)
    private(set) var recent: [RecentCompletion] = []

    init(store: LocalStore, settings: SettingsStore, catalog: ContentCatalog,
         now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.store = store
        self.settings = settings
        self.catalog = catalog
        self.now = now
        self.calendar = calendar
    }

    var isHidden: Bool { settings.settings.hideProgress }
    var stageName: String { Self.stageNames[min(max(summary.journeyStage, 0), Self.stageNames.count - 1)] }

    func refresh() {
        let completions = store.completions()
        summary = ProgressCalculator.summary(completions: completions, weeklyGoal: settings.settings.weeklyGoal,
                                             now: now(), calendar: calendar)
        recent = completions.prefix(Self.recentLimit).compactMap { c in
            catalog.title(for: c.exerciseID).map { RecentCompletion(id: c.id, title: $0, completedAt: c.completedAt) }
        }
    }
}
