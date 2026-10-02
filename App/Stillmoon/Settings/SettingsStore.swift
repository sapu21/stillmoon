import Foundation
import Observation
import StillmoonCore

enum NightModeOverride: String, Codable, CaseIterable {
    case automatic, on, off
}

struct AppSettings: Codable, Equatable {
    var goal: Goal = .unwind
    var bedtime: ClockTime?
    var wakeTime: ClockTime?
    var weeklyGoal: Int = 3
    var hasOnboarded = false
    var hideProgress = false
    var nightModeOverride: NightModeOverride = .automatic
    var snoringNoteShown = false
}

@Observable final class SettingsStore {
    static let key = "settings.v1"
    @ObservationIgnored private let defaults: UserDefaults

    var settings: AppSettings {
        didSet { persist() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let stored = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = stored
        } else {
            settings = AppSettings()
        }
    }

    var manualOverride: Bool? {
        switch settings.nightModeOverride {
        case .automatic: nil
        case .on: true
        case .off: false
        }
    }

    func isNight(at now: Date, calendar: Calendar, sessionActive: Bool) -> Bool {
        NightModeResolver.isNight(at: now, calendar: calendar, bedtime: settings.bedtime, wake: settings.wakeTime,
                                  sessionActive: sessionActive, manualOverride: manualOverride)
    }

    func reset() {
        settings = AppSettings()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

extension ClockTime {
    func date(on day: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }
}
