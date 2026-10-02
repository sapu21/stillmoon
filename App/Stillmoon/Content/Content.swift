import Foundation
import StillmoonCore

enum ExerciseFormat: String, Codable { case text, audio }
enum ContentTier: String, Codable { case free, premium }

struct ExerciseStep: Codable, Hashable {
    var text: String
    var seconds: Int
}

struct Exercise: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var summary: String
    var category: ExerciseCategory
    var format: ExerciseFormat
    var tags: Set<ContentTag>
    var steps: [ExerciseStep]
    var audioFile: String?
    var tier: ContentTier
    /// Where the technique comes from (PRD §8), shown as "Based on".
    var techniqueSource: String
    var licence: String

    var durationSeconds: Int { steps.reduce(0) { $0 + $1.seconds } }
}

struct SourceLink: Codable, Hashable {
    var title: String
    var url: URL
}

struct Article: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var summary: String
    /// Paragraphs separated by a blank line; inline Markdown allowed.
    var body: String
    var tags: Set<ContentTag>
    var sources: [SourceLink]
    var reviewedOn: String
    var nextReview: String
    var tier: ContentTier

    var paragraphs: [String] {
        body.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct ContentCatalog: Codable, Hashable {
    var exercises: [Exercise]
    var articles: [Article]

    static let empty = ContentCatalog(exercises: [], articles: [])

    /// Exercises first, then articles, each in editorial order (recommendation tie-break order).
    var catalogItems: [CatalogItem] {
        exercises.map { CatalogItem(id: $0.id, kind: .exercise, title: $0.title, tags: $0.tags) }
            + articles.map { CatalogItem(id: $0.id, kind: .article, title: $0.title, tags: $0.tags) }
    }

    func exercise(id: String) -> Exercise? { exercises.first { $0.id == id } }
    func article(id: String) -> Article? { articles.first { $0.id == id } }
    func title(for id: String) -> String? { exercise(id: id)?.title ?? article(id: id)?.title }
}

enum ContentStore {
    static func load(from data: Data) throws -> ContentCatalog {
        try JSONDecoder().decode(ContentCatalog.self, from: data)
    }

    static func loadBundled(bundle: Bundle = .main) throws -> ContentCatalog {
        guard let url = bundle.url(forResource: "catalog", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try load(from: Data(contentsOf: url))
    }
}
