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

    @Test func pausingOnLastStepThenTickingRecordsNothing() throws {
        let (m, store) = try make()
        m.play()
        m.skipStep()
        m.tick()
        #expect(m.remainingSeconds == 1)
        m.pause()
        m.tick()
        #expect(!m.isComplete)
        #expect(store.completions().isEmpty)
    }

    @Test func onFinishCalledOnceWithInterval() throws {
        var finished: [DateInterval] = []
        var clock = TestEnv.d(2026, 10, 2, 22)
        let m = PlayerModel(exercise: TestEnv.catalog.exercises[0], store: try TestEnv.store(),
                            now: { clock }, onFinish: { finished.append($0) })
        m.play()
        clock = TestEnv.d(2026, 10, 2, 22, 5)
        m.skipStep()
        m.skipStep()
        m.finish()
        #expect(finished == [DateInterval(start: TestEnv.d(2026, 10, 2, 22), end: TestEnv.d(2026, 10, 2, 22, 5))])
    }

    @Test func onFinishNotCalledWhenEndedEarly() throws {
        var calls = 0
        let m = PlayerModel(exercise: TestEnv.catalog.exercises[0], store: try TestEnv.store(),
                            now: { TestEnv.d(2026, 10, 2, 22) }, onFinish: { _ in calls += 1 })
        m.play()
        m.tick()
        m.pause()
        #expect(calls == 0)
    }
}
