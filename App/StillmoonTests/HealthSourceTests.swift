import Foundation
import HealthKit
import Testing
import StillmoonCore
@testable import Stillmoon

struct HealthSourceTests {
    @Test func mapsEverySleepValue() {
        #expect(SleepStageMapping.stage(forHealthKitValue: HKCategoryValueSleepAnalysis.inBed.rawValue) == .inBed)
        #expect(SleepStageMapping.stage(forHealthKitValue: HKCategoryValueSleepAnalysis.awake.rawValue) == .awake)
        #expect(SleepStageMapping.stage(forHealthKitValue: HKCategoryValueSleepAnalysis.asleepCore.rawValue) == .core)
        #expect(SleepStageMapping.stage(forHealthKitValue: HKCategoryValueSleepAnalysis.asleepDeep.rawValue) == .deep)
        #expect(SleepStageMapping.stage(forHealthKitValue: HKCategoryValueSleepAnalysis.asleepREM.rawValue) == .rem)
        #expect(SleepStageMapping.stage(forHealthKitValue: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue) == .asleepUnspecified)
        #expect(SleepStageMapping.stage(forHealthKitValue: 999) == nil)
    }

    @Test func stageTitles() {
        #expect(SleepStage.rem.title == "REM")
        #expect(SleepStage.asleepUnspecified.title == "Asleep")
        #expect(SleepStage.inBed.title == "In bed")
    }

    @Test func sampleNightIsAStagedNight() {
        let samples = FakeHealthSource.sampleNight(endingOn: TestEnv.d(2026, 10, 2, 9), calendar: TestEnv.cal)
        let report = SleepReportBuilder.build(samples: samples,
                                              window: NightWindow.forMorning(of: TestEnv.d(2026, 10, 2, 9), calendar: TestEnv.cal))
        #expect(report?.primarySource == "Apple Watch")
        #expect(report?.estimatedAsleep == TimeInterval(7 * 3600 + 20 * 60))
        #expect(report?.hasStageDetail == true)
    }

    @Test func fakeFiltersByRangeAndCanFail() async throws {
        let fake = FakeHealthSource(samples: FakeHealthSource.sampleNight(endingOn: TestEnv.d(2026, 10, 2, 9), calendar: TestEnv.cal))
        #expect(try await fake.sleepSamples(from: TestEnv.d(2026, 10, 2, 12), to: TestEnv.d(2026, 10, 2, 20)).isEmpty)
        #expect(try await fake.sleepSamples(from: TestEnv.d(2026, 10, 1, 18), to: TestEnv.d(2026, 10, 2, 12)).count == 5)
        fake.failReads = true
        await #expect(throws: HealthError.unavailable) {
            try await fake.sleepSamples(from: TestEnv.d(2026, 10, 1, 18), to: TestEnv.d(2026, 10, 2, 12))
        }
    }

    @Test func connectHealthSetsSettingOnlyWhenAvailable() async throws {
        let fake = FakeHealthSource()
        let env = AppEnvironment(store: try TestEnv.store(), settings: TestEnv.settings(), catalog: TestEnv.catalog, health: fake)
        #expect(await env.connectHealth())
        #expect(fake.authorizationRequested)
        #expect(env.settings.settings.healthConnected)

        let offline = FakeHealthSource()
        offline.isAvailable = false
        let env2 = AppEnvironment(store: try TestEnv.store(), settings: TestEnv.settings(), catalog: TestEnv.catalog, health: offline)
        #expect(await env2.connectHealth() == false)
        #expect(!env2.settings.settings.healthConnected)
    }

    @Test func healthConnectedDecodesFromOlderPayload() throws {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        defaults.set(Data(#"{"hasOnboarded":true}"#.utf8), forKey: SettingsStore.keyPrefix + LocalOwner.id)
        #expect(SettingsStore(defaults: defaults).settings.healthConnected == false)
    }
}
