import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct CalmCheckStoreTests {
    let at = TestEnv.d(2026, 10, 4, 22)

    @Test func savesAndUpdatesOneCheck() throws {
        let store = try TestEnv.store()
        var check = CalmCheck(exerciseID: "breath", at: at)
        check.bpmBefore = 78
        check.tenseBefore = 4
        store.saveCalmCheck(check)
        check.bpmAfter = 66
        check.tenseAfter = 2
        check.breathsStart = 14
        check.breathsEnd = 8
        store.saveCalmCheck(check)
        let saved = store.calmChecks(from: at.addingTimeInterval(-60), to: at.addingTimeInterval(60))
        #expect(saved == [check])
        #expect(store.calmChecks(from: at.addingTimeInterval(60), to: .distantFuture).isEmpty)
    }

    @Test func checksBelongToTheirOwner() throws {
        let container = try TestEnv.container()
        let a = try TestEnv.store(owner: "a", container: container)
        let b = try TestEnv.store(owner: "b", container: container)
        a.saveCalmCheck(CalmCheck(exerciseID: "breath", at: at))
        #expect(b.calmChecks(from: .distantPast, to: .distantFuture).isEmpty)
        b.deleteAllData()
        #expect(a.calmChecks(from: .distantPast, to: .distantFuture).count == 1)
        a.deleteAllData()
        #expect(a.calmChecks(from: .distantPast, to: .distantFuture).isEmpty)
    }

    @Test func versionTwoStoreOpensWithCalmChecks() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("v2-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        do {
            let v2 = try StillmoonSchema.makeV2ContainerForTesting(directory: dir)
            let old = LocalStore(container: v2, ownerID: "a")
            old.saveCheckIn(CheckIn(date: TestEnv.d(2026, 10, 1, 8), restedness: 2))
            let s = old.startSoundSession(at: TestEnv.d(2026, 10, 1, 23))
            old.addSoundEvents([SoundEvent(label: .coughLike, at: TestEnv.d(2026, 10, 2, 1), confidence: 0.7)], sessionID: s)
        }
        let store = LocalStore(container: try StillmoonSchema.makeContainer(inMemory: false, directory: dir), ownerID: "a")
        #expect(store.checkIns().first?.restedness == 2)
        #expect(store.soundEvents(from: .distantPast, to: .distantFuture).count == 1)
        store.saveCalmCheck(CalmCheck(exerciseID: "breath", at: at))
        #expect(store.calmChecks(from: .distantPast, to: .distantFuture).count == 1)
    }
}
