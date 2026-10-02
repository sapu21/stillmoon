import Foundation
import Testing
import StillmoonCore
@testable import Stillmoon

struct SettingsTests {
    func freshDefaults() -> UserDefaults { UserDefaults(suiteName: "test-\(UUID().uuidString)")! }

    @Test func defaultsMatchThePRD() {
        let s = SettingsStore(defaults: freshDefaults()).settings
        #expect(s.goal == .unwind)
        #expect(s.bedtime == nil)
        #expect(s.weeklyGoal == 3)
        #expect(!s.hasOnboarded)
        #expect(s.nightModeOverride == .automatic)
    }

    @Test func settingsPersistAcrossInstances() {
        let defaults = freshDefaults()
        let first = SettingsStore(defaults: defaults)
        first.settings.goal = .nightWaking
        first.settings.bedtime = ClockTime(hour: 23, minute: 15)
        first.settings.hasOnboarded = true
        let second = SettingsStore(defaults: defaults)
        #expect(second.settings == first.settings)
    }

    @Test func nightModeFollowsScheduleAndOverride() {
        let store = SettingsStore(defaults: freshDefaults())
        store.settings.bedtime = ClockTime(hour: 23, minute: 0)
        store.settings.wakeTime = ClockTime(hour: 7, minute: 0)
        #expect(!store.isNight(at: TestEnv.d(2026, 10, 2, 21, 59), calendar: TestEnv.cal, sessionActive: false))
        #expect(store.isNight(at: TestEnv.d(2026, 10, 2, 22, 0), calendar: TestEnv.cal, sessionActive: false))
        store.settings.nightModeOverride = .off
        #expect(!store.isNight(at: TestEnv.d(2026, 10, 2, 23, 30), calendar: TestEnv.cal, sessionActive: true))
        store.settings.nightModeOverride = .on
        #expect(store.isNight(at: TestEnv.d(2026, 10, 2, 14), calendar: TestEnv.cal, sessionActive: false))
    }

    @Test func resetRestoresDefaults() {
        let store = SettingsStore(defaults: freshDefaults())
        store.settings.weeklyGoal = 6
        store.reset()
        #expect(store.settings == AppSettings())
    }

    @Test func clockTimeBecomesDateOnDay() {
        let date = ClockTime(hour: 22, minute: 30).date(on: TestEnv.d(2026, 10, 2, 9), calendar: TestEnv.cal)
        #expect(date == TestEnv.d(2026, 10, 2, 22, 30))
    }

    @Test func decodesOlderPayloadWithMissingKeys() throws {
        let defaults = freshDefaults()
        let data = Data(#"{"goal":"nightWaking","hasOnboarded":true}"#.utf8)
        defaults.set(data, forKey: "\(SettingsStore.keyPrefix)\(LocalOwner.id)")
        let s = SettingsStore(defaults: defaults).settings
        #expect(s.goal == .nightWaking)
        #expect(s.hasOnboarded)
        #expect(s.weeklyGoal == 3)
        #expect(s.nightModeOverride == .automatic)
    }

    @Test func ownersHaveSeparateSettings() {
        let defaults = freshDefaults()
        let a = SettingsStore(defaults: defaults, ownerID: "a")
        let b = SettingsStore(defaults: defaults, ownerID: "b")
        a.settings.goal = .nightWaking
        #expect(b.settings.goal == .unwind)
        #expect(SettingsStore(defaults: defaults, ownerID: "b").settings.goal == .unwind)
        #expect(SettingsStore(defaults: defaults, ownerID: "a").settings.goal == .nightWaking)
    }
}
