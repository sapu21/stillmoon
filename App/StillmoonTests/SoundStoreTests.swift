import Foundation
import SwiftData
import Testing
import StillmoonCore
@testable import Stillmoon

struct SoundStoreTests {
    @Test func storesEventsAndCorrections() throws {
        let store = try TestEnv.store()
        let session = store.startSoundSession(at: TestEnv.d(2026, 10, 1, 23))
        let e1 = SoundEvent(label: .snoringLike, at: TestEnv.d(2026, 10, 2, 2), confidence: 0.8)
        let e2 = SoundEvent(label: .speechLike, at: TestEnv.d(2026, 10, 2, 1), confidence: 0.7)
        store.addSoundEvents([e1, e2], sessionID: session)
        store.setCorrection(.someoneElse, forEvent: e2.id)
        let events = store.soundEvents(from: TestEnv.d(2026, 10, 1, 18), to: TestEnv.d(2026, 10, 2, 12))
        #expect(events.map(\.id) == [e2.id, e1.id])
        #expect(events[0].correction == .someoneElse)
        #expect(events[1].correction == SoundCorrection.none)
    }

    @Test func closeOrphanedSessionsEndsOpenSessions() throws {
        let store = try TestEnv.store()
        let session = store.startSoundSession(at: TestEnv.d(2026, 10, 1, 23))
        store.addSoundEvents([SoundEvent(label: .coughLike, at: TestEnv.d(2026, 10, 2, 3), confidence: 0.9)], sessionID: session)
        #expect(store.openSessionID() == session)
        store.closeOrphanedSessions()
        #expect(store.openSessionID() == nil)
        #expect(store.soundEvents(from: TestEnv.d(2026, 10, 1, 18), to: TestEnv.d(2026, 10, 2, 12)).count == 1)
    }

    @Test func soundDataIsOwnerScopedAndDeleted() throws {
        let container = try TestEnv.container()
        let a = try TestEnv.store(owner: "a", container: container)
        let b = try TestEnv.store(owner: "b", container: container)
        let s = a.startSoundSession(at: TestEnv.d(2026, 10, 1, 23))
        a.addSoundEvents([SoundEvent(label: .snoringLike, at: TestEnv.d(2026, 10, 2, 2), confidence: 0.8)], sessionID: s)
        #expect(b.soundEvents(from: .distantPast, to: .distantFuture).isEmpty)
        #expect(b.openSessionID() == nil)
        a.deleteAllData()
        #expect(a.soundEvents(from: .distantPast, to: .distantFuture).isEmpty)
        #expect(a.openSessionID() == nil)
    }

    @Test func migratesV1StoreOnDisk() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        do {
            let v1 = try StillmoonSchema.makeV1ContainerForTesting(directory: dir)
            let old = LocalStore(container: v1, ownerID: "a")
            old.saveCheckIn(CheckIn(date: TestEnv.d(2026, 10, 1, 8), restedness: 4))
        }
        let v2 = try StillmoonSchema.makeContainer(inMemory: false, directory: dir)
        let store = LocalStore(container: v2, ownerID: "a")
        #expect(store.checkIns().first?.restedness == 4)
        let s = store.startSoundSession(at: TestEnv.d(2026, 10, 1, 23))
        store.addSoundEvents([SoundEvent(label: .snoringLike, at: TestEnv.d(2026, 10, 2, 2), confidence: 0.8)], sessionID: s)
        #expect(store.soundEvents(from: .distantPast, to: .distantFuture).count == 1)
    }
}
