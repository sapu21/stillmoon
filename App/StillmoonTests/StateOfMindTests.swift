import Foundation
import Testing
@testable import Stillmoon

struct StateOfMindTests {
    @Test func tensionMapsToTheUsersOwnAnswer() {
        #expect((1...5).map(StateOfMindMapping.valence(tension:)) == [0.6, 0.3, 0, -0.3, -0.6])
        #expect((1...5).map(StateOfMindMapping.feeling(tension:)) == [.calm, .calm, nil, .stressed, .stressed])
        #expect(StateOfMindMapping.valence(tension: 9) == -0.6)
        #expect(StateOfMindMapping.valence(tension: 0) == 0.6)
    }

    @Test func fakeHealthRecordsWhatWasSaved() async throws {
        let health = FakeHealthSource()
        try await health.requestStateOfMindAuthorization()
        try await health.saveStateOfMind(tension: 4, at: TestEnv.d(2026, 10, 4, 22))
        #expect(health.stateOfMindRequested)
        #expect(health.statesOfMind.map(\.tension) == [4])
    }

    @Test func calmCheckSettingsDefaultOffForOlderPayloads() throws {
        let old = #"{"goal":"unwind","weeklyGoal":3,"hasOnboarded":true}"#.data(using: .utf8)!
        let settings = try JSONDecoder().decode(AppSettings.self, from: old)
        #expect(!settings.calmCheckEnabled && !settings.breathListeningEnabled && !settings.stateOfMindEnabled)
        var on = AppSettings()
        on.calmCheckEnabled = true
        on.breathListeningEnabled = true
        on.stateOfMindEnabled = true
        #expect(try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(on)) == on)
    }
}
