import AVFAudio
import Foundation
import Observation
import SwiftData
import StillmoonCore

struct PlayerRequest: Identifiable, Hashable {
    let exerciseID: String
    var id: String { exerciseID }
}

/// The app's shared objects, passed through the SwiftUI environment.
/// Shared so the sound controller always reads the environment's current flags.
final class FlagsBox {
    var value = FeatureFlags()
}

@Observable final class AppEnvironment {
    let store: LocalStore
    let settings: SettingsStore
    let catalog: ContentCatalog
    let health: HealthDataSource
    @ObservationIgnored private let flagsBox: FlagsBox
    var flags: FeatureFlags {
        get { flagsBox.value }
        set { flagsBox.value = newValue }
    }
    let sound: SoundSessionController
    /// True while a sound-detection session runs.
    var sessionActive: Bool { sound.isActive }
    /// Set to open the exercise player full screen from anywhere.
    var playerRequest: PlayerRequest?

    init(store: LocalStore, settings: SettingsStore, catalog: ContentCatalog,
         health: HealthDataSource = FakeHealthSource(),
         sound makeSound: ((@escaping () -> FeatureFlags) -> SoundSessionController)? = nil) {
        let box = FlagsBox()
        flagsBox = box
        let flagsReader: () -> FeatureFlags = { box.value }
        self.store = store
        self.settings = settings
        self.catalog = catalog
        self.health = health
        self.sound = makeSound?(flagsReader) ?? SoundSessionController(
            store: store, detector: FakeSoundDetector(), permission: FakeMicrophonePermission(granted: true),
            battery: FakeBattery(), settings: settings, flags: flagsReader)
    }

    /// Asks for Health access. HealthKit never says whether read access was granted,
    /// so "connected" means the user went through the prompt.
    func connectHealth() async -> Bool {
        guard health.isAvailable else { return false }
        do {
            try await health.requestAuthorization()
            settings.settings.healthConnected = true
            return true
        } catch {
            return false
        }
    }

    /// Deletes this owner's local records and resets preferences, keeping onboarding done.
    func deleteAllLocalData() {
        store.deleteAllData()
        settings.reset()
        settings.settings.hasOnboarded = true
    }

    /// `-ui-testing` gives an in-memory store and fresh settings.
    static func live(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppEnvironment {
        let uiTesting = arguments.contains("-ui-testing")
        let container: ModelContainer
        do {
            container = try StillmoonSchema.makeContainer(inMemory: uiTesting)
        } catch {
            fatalError("Could not open the local store: \(error)")
        }
        let defaults: UserDefaults
        if uiTesting {
            let suite = "ui-testing"
            UserDefaults().removePersistentDomain(forName: suite)
            defaults = UserDefaults(suiteName: suite)!
        } else {
            defaults = .standard
        }
        let catalog = (try? ContentStore.loadBundled()) ?? .empty
        let health: HealthDataSource = arguments.contains("-fake-health")
            ? FakeHealthSource(samples: FakeHealthSource.sampleNight(endingOn: .now, calendar: .current))
            : HealthKitService()
        let store = LocalStore(container: container, ownerID: LocalOwner.id)
        store.closeOrphanedSessions()
        let settings = SettingsStore(defaults: defaults, ownerID: LocalOwner.id)
        let fakeSound = arguments.contains("-fake-sound")
        let detector: SoundDetecting = fakeSound
            ? FakeSoundDetector(script: FakeSoundDetector.lastNightScript(now: .now, calendar: .current))
            : SoundAnalysisDetector()
        let permission: MicrophonePermission = fakeSound ? FakeMicrophonePermission(granted: true) : SystemMicrophonePermission()
        let battery: BatteryReading = fakeSound ? FakeBattery() : DeviceBattery()
        let env = AppEnvironment(store: store, settings: settings, catalog: catalog, health: health) { flags in
            SoundSessionController(store: store, detector: detector, permission: permission,
                                   battery: battery, settings: settings, flags: flags)
        }
        let sound = env.sound
        if !fakeSound {
            NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil,
                                                   queue: .main) { [weak sound] note in
                guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
                if type == .ended {
                    let options = AVAudioSession.InterruptionOptions(
                        rawValue: note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
                    guard options.contains(.shouldResume) else { return }
                }
                MainActor.assumeIsolated { sound?.handleInterruption(began: type == .began) }
            }
        }
        return env
    }
}
