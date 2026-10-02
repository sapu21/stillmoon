import Foundation
import Observation
import StillmoonCore

enum LibraryFilter: Hashable {
    case all
    case category(ExerciseCategory)
    case saved
}

@Observable final class ExercisesModel {
    @ObservationIgnored private let store: LocalStore
    @ObservationIgnored let catalog: ContentCatalog
    @ObservationIgnored private let now: () -> Date
    var query = ""
    var filter: LibraryFilter = .all
    private(set) var savedIDs: Set<String> = []

    init(store: LocalStore, catalog: ContentCatalog, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.catalog = catalog
        self.now = now
    }

    func refresh() {
        savedIDs = store.savedItemIDs()
    }

    var exercises: [Exercise] {
        catalog.exercises.filter { exercise in
            switch filter {
            case .all: true
            case .category(let category): exercise.category == category
            case .saved: savedIDs.contains(exercise.id)
            }
        }
        .filter { matches($0.title, $0.summary) }
    }

    /// Articles live under Learn.
    var articles: [Article] {
        catalog.articles.filter { article in
            switch filter {
            case .all, .category(.learn): true
            case .category: false
            case .saved: savedIDs.contains(article.id)
            }
        }
        .filter { matches($0.title, $0.summary) }
    }

    func isSaved(_ id: String) -> Bool { savedIDs.contains(id) }

    func toggleSaved(_ id: String) {
        store.setSaved(id, !isSaved(id), at: now())
        refresh()
    }

    private func matches(_ texts: String...) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty || texts.contains { $0.localizedStandardContains(q) }
    }
}
