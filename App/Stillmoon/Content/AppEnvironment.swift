import Foundation
import Observation
import SwiftData
import StillmoonCore

struct PlayerRequest: Identifiable, Hashable {
    let exerciseID: String
    var id: String { exerciseID }
}

/// The app's shared objects, passed through the SwiftUI environment.
@Observable final class AppEnvironment {
    let store: LocalStore
    let settings: SettingsStore
    let catalog: ContentCatalog
    let health: HealthDataSource
    /// True while a sound-detection session runs (Plan 4).
    var sessionActive = false
    /// Set to open the exercise player full screen from anywhere.
    var playerRequest: PlayerRequest?

    init(store: LocalStore, settings: SettingsStore, catalog: ContentCatalog,
         health: HealthDataSource = FakeHealthSource()) {
        self.store = store
        self.settings = settings
        self.catalog = catalog
        self.health = health
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
        return AppEnvironment(store: store,
                              settings: SettingsStore(defaults: defaults, ownerID: LocalOwner.id), catalog: catalog,
                              health: health)
    }
}
