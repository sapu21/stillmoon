import Foundation
import SwiftData
import StillmoonCore
@testable import Stillmoon

enum TestEnv {
    static let tz = TimeZone(identifier: "America/New_York")!

    static var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        c.firstWeekday = 1
        return c
    }

    static func d(_ y: Int, _ mo: Int, _ day: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: mo, day: day, hour: h, minute: mi))!
    }

    static func container() throws -> ModelContainer {
        try StillmoonSchema.makeContainer(inMemory: true)
    }

    static func store(owner: String = "user-a", container: ModelContainer? = nil) throws -> LocalStore {
        LocalStore(container: try container ?? Self.container(), ownerID: owner)
    }

    static func settings() -> SettingsStore {
        SettingsStore(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
    }

    static func exercise(_ id: String, _ title: String, _ category: ExerciseCategory, _ tags: Set<ContentTag>,
                         steps: [ExerciseStep] = [ExerciseStep(text: "Breathe in", seconds: 3), ExerciseStep(text: "Breathe out", seconds: 2)]) -> Exercise {
        Exercise(id: id, title: title, summary: "\(title) summary.", category: category, format: .text, tags: tags,
                 steps: steps, audioFile: nil, tier: .free, techniqueSource: "Test technique", licence: "Original")
    }

    static func article(_ id: String, _ title: String, _ tags: Set<ContentTag>) -> Article {
        Article(id: id, title: title, summary: "\(title) summary.", body: "First paragraph.\n\nSecond paragraph.",
                tags: tags, sources: [SourceLink(title: "CDC", url: URL(string: "https://www.cdc.gov/sleep/about/")!)],
                reviewedOn: "2026-10-02", nextReview: "2027-04-02", tier: .free)
    }

    static let catalog = ContentCatalog(
        exercises: [
            exercise("breath", "Gentle breathing", .windDown, [.relaxation]),
            exercise("scan", "Body scan", .windDown, [.relaxation]),
            exercise("awake", "Five quiet minutes", .awakeAtNight, [.awakeAtNight]),
            exercise("morning", "Morning reflection", .morningReset, [.morning]),
        ],
        articles: [
            article("steady-bedtime", "Keeping a steady bedtime", [.routine]),
            article("talk-to-a-doctor", "When to talk to a doctor", [.sleepData]),
        ])
}
