import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct PlayerModelTests {
    // TestEnv "breath": steps of 3 s and 2 s.
    func make() throws -> (PlayerModel, LocalStore) {
        let store = try TestEnv.store()
        let model = PlayerModel(exercise: TestEnv.catalog.exercises[0], store: store, now: { TestEnv.d(2026, 10, 2, 22) })
        return (model, store)
    }

    @Test func ticksMoveThroughStepsAndFinish() throws {
        let (m, store) = try make()
        m.play()
        #expect(m.remainingSeconds == 5)
        for _ in 0..<3 { m.tick() }
        #expect(m.stepIndex == 1)
        #expect(m.remainingSeconds == 2)
        for _ in 0..<2 { m.tick() }
        #expect(m.isComplete)
        #expect(!m.isPlaying)
        #expect(m.remainingSeconds == 0)
        #expect(store.completions().map(\.exerciseID) == ["breath"])
        #expect(store.completions().first?.category == .windDown)
    }

    @Test func pausedTicksDoNothing() throws {
        let (m, _) = try make()
        m.tick()
        #expect(m.elapsedInStep == 0)
        m.play()
        m.tick()
        m.pause()
        m.tick()
        #expect(m.elapsedInStep == 1)
    }

    @Test func skipAdvancesAndLastSkipFinishes() throws {
        let (m, store) = try make()
        m.skipStep()
        #expect(m.stepIndex == 1)
        #expect(m.elapsedInStep == 0)
        m.skipStep()
        #expect(m.isComplete)
        #expect(store.completions().count == 1)
    }

    @Test func finishRecordsOnce() throws {
        let (m, store) = try make()
        m.finish()
        m.finish()
        m.skipStep()
        #expect(store.completions().count == 1)
    }

    @Test func endingEarlyRecordsNothing() throws {
        let (m, store) = try make()
        m.play()
        m.tick()
        m.pause()
        #expect(store.completions().isEmpty)
    }
}
