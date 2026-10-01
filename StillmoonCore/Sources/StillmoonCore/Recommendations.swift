import Foundation

public enum ContentTag: String, Codable, Sendable, CaseIterable {
    case relaxation, awakeAtNight, routine, sleepData, morning
}

public enum ContentKind: String, Codable, Sendable {
    case exercise, article
}

public struct CatalogItem: Codable, Sendable, Hashable {
    public var id: String
    public var kind: ContentKind
    public var title: String
    public var tags: Set<ContentTag>

    public init(id: String, kind: ContentKind, title: String, tags: Set<ContentTag>) {
        self.id = id
        self.kind = kind
        self.title = title
        self.tags = tags
    }
}

public enum FeedbackRating: String, Codable, Sendable {
    case helpful, irrelevant, unwanted
}

public struct RecommendationFeedback: Codable, Sendable, Hashable {
    public var id: UUID
    public var itemID: String
    public var rating: FeedbackRating
    public var at: Date

    public init(id: UUID = UUID(), itemID: String, rating: FeedbackRating, at: Date) {
        self.id = id
        self.itemID = itemID
        self.rating = rating
        self.at = at
    }
}

public struct Recommendation: Sendable, Equatable {
    public let itemID: String
    public let reason: String

    public init(itemID: String, reason: String) {
        self.itemID = itemID
        self.reason = reason
    }
}

public struct RecommendationInput: Sendable {
    public var goal: Goal
    /// Only today's check-in; pass nil if the user has not checked in today.
    public var todayCheckIn: CheckIn?
    /// Bedtimes from the last 7 nights (journal entries or report sleep starts).
    public var recentBedtimes: [Date]
    public var feedback: [RecommendationFeedback]
    /// In editorial order; earlier items win ties.
    public var catalog: [CatalogItem]

    public init(goal: Goal, todayCheckIn: CheckIn?, recentBedtimes: [Date],
                feedback: [RecommendationFeedback], catalog: [CatalogItem]) {
        self.goal = goal
        self.todayCheckIn = todayCheckIn
        self.recentBedtimes = recentBedtimes
        self.feedback = feedback
        self.catalog = catalog
    }
}

public enum RecommendationEngine {
    public static let maxResults = 3
    static let minimumBedtimes = 4
    static let variedSpreadMinutes = 90
    static let demoteAfterIrrelevant = 2

    public enum Reason {
        public static let tense = "You mentioned feeling tense before bed."
        public static let woke = "You mentioned being awake during the night."
        public static let varied = "Your recorded bedtimes varied this week."
        public static let goal = "Based on the goal you chose."
    }

    public static func recommend(_ input: RecommendationInput, calendar: Calendar) -> [Recommendation] {
        let unwanted = Set(input.feedback.filter { $0.rating == .unwanted }.map(\.itemID))
        let irrelevant = Dictionary(input.feedback.filter { $0.rating == .irrelevant }.map { ($0.itemID, 1) },
                                    uniquingKeysWith: +)
        let eligible = input.catalog.filter { !unwanted.contains($0.id) }

        var results: [Recommendation] = []
        func candidates(_ tag: ContentTag) -> [CatalogItem] {
            let open = eligible.filter { item in
                item.tags.contains(tag) && !results.contains { $0.itemID == item.id }
            }
            let demoted = { (item: CatalogItem) in (irrelevant[item.id] ?? 0) >= demoteAfterIrrelevant }
            return open.filter { !demoted($0) } + open.filter(demoted)
        }
        func add(_ tag: ContentTag, _ reason: String) {
            guard results.count < maxResults, let item = candidates(tag).first else { return }
            results.append(Recommendation(itemID: item.id, reason: reason))
        }

        if input.todayCheckIn?.tenseAtBedtime == true { add(.relaxation, Reason.tense) }
        if input.todayCheckIn?.wokeDuringNight == true { add(.awakeAtNight, Reason.woke) }
        if bedtimesVary(input.recentBedtimes, calendar: calendar) { add(.routine, Reason.varied) }
        for item in candidates(tag(for: input.goal)) where results.count < maxResults {
            results.append(Recommendation(itemID: item.id, reason: Reason.goal))
        }
        return results
    }

    public static func bedtimesVary(_ bedtimes: [Date], calendar: Calendar) -> Bool {
        guard bedtimes.count >= minimumBedtimes else { return false }
        let minutes = bedtimes.map { ClockTime(of: $0, calendar: calendar).minutesSinceSixPM }
        return minutes.max()! - minutes.min()! > variedSpreadMinutes
    }

    static func tag(for goal: Goal) -> ContentTag {
        switch goal {
        case .unwind: .relaxation
        case .understandSleep: .sleepData
        case .nightWaking: .awakeAtNight
        case .consistency: .routine
        }
    }
}
