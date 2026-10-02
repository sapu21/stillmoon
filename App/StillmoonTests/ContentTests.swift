import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct ContentTests {
    @Test func bundledCatalogLoads() throws {
        let catalog = try ContentStore.loadBundled()
        #expect(catalog.exercises.count >= 4)
        #expect(catalog.articles.count >= 3)
    }

    @Test func bundledCatalogIsWellFormed() throws {
        let catalog = try ContentStore.loadBundled()
        let ids = catalog.exercises.map(\.id) + catalog.articles.map(\.id)
        #expect(Set(ids).count == ids.count, "ids must be unique")
        for e in catalog.exercises {
            #expect(!e.steps.isEmpty, "\(e.id) needs steps")
            #expect(e.steps.allSatisfy { $0.seconds > 0 }, "\(e.id) step seconds")
            #expect(!e.tags.isEmpty, "\(e.id) needs tags")
            #expect(!e.techniqueSource.isEmpty && !e.licence.isEmpty, "\(e.id) needs provenance")
        }
        for a in catalog.articles {
            #expect(!a.sources.isEmpty, "\(a.id) needs sources")
        }
        #expect(catalog.exercise(id: "gentle-breathing") != nil)
        #expect(catalog.article(id: "talk-to-a-doctor") != nil)
        #expect(catalog.exercises.contains { $0.category == .awakeAtNight })
    }

    @Test func catalogItemsCoverExercisesThenArticles() {
        let items = TestEnv.catalog.catalogItems
        #expect(items.map(\.id) == ["breath", "scan", "awake", "morning", "steady-bedtime", "talk-to-a-doctor"])
        #expect(items[0].kind == .exercise)
        #expect(items[4].kind == .article)
        #expect(TestEnv.catalog.title(for: "steady-bedtime") == "Keeping a steady bedtime")
        #expect(TestEnv.catalog.title(for: "missing") == nil)
    }

    @Test func durationAndParagraphs() {
        #expect(TestEnv.catalog.exercises[0].durationSeconds == 5)
        #expect(TestEnv.catalog.articles[0].paragraphs == ["First paragraph.", "Second paragraph."])
    }

    @Test func uiTestingEnvironmentStartsEmpty() {
        let env = AppEnvironment.live(arguments: ["-ui-testing"])
        #expect(!env.settings.settings.hasOnboarded)
        #expect(env.store.checkIns().isEmpty)
        #expect(!env.catalog.exercises.isEmpty)
        #expect(env.store.ownerID == LocalOwner.id)
    }
}
