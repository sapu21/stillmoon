import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct ExercisesModelTests {
    func model() throws -> ExercisesModel {
        let m = ExercisesModel(store: try TestEnv.store(), catalog: TestEnv.catalog, now: { TestEnv.d(2026, 10, 2, 9) })
        m.refresh()
        return m
    }

    @Test func allShowsEverything() throws {
        let m = try model()
        #expect(m.exercises.count == 4)
        #expect(m.articles.count == 2)
    }

    @Test func categoryFilters() throws {
        let m = try model()
        m.filter = .category(.windDown)
        #expect(m.exercises.map(\.id) == ["breath", "scan"])
        #expect(m.articles.isEmpty)
        m.filter = .category(.learn)
        #expect(m.exercises.isEmpty)
        #expect(m.articles.count == 2)
    }

    @Test func searchIgnoresCase() throws {
        let m = try model()
        m.query = "BREATH"
        #expect(m.exercises.map(\.id) == ["breath"])
        #expect(m.articles.isEmpty)
        m.query = "doctor"
        #expect(m.articles.map(\.id) == ["talk-to-a-doctor"])
    }

    @Test func savedFilterAndToggle() throws {
        let m = try model()
        m.toggleSaved("scan")
        m.toggleSaved("steady-bedtime")
        m.filter = .saved
        #expect(m.exercises.map(\.id) == ["scan"])
        #expect(m.articles.map(\.id) == ["steady-bedtime"])
        m.toggleSaved("scan")
        #expect(!m.isSaved("scan"))
        #expect(m.exercises.isEmpty)
    }
}
