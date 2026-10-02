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
    var healthConnected = false

    enum CodingKeys: String, CodingKey {
        case goal, bedtime, wakeTime, weeklyGoal, hasOnboarded, hideProgress, nightModeOverride, snoringNoteShown, healthConnected
    }

    init() {}

    /// Tolerates payloads written by older versions: missing keys fall back to defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        goal = try c.decodeIfPresent(Goal.self, forKey: .goal) ?? .unwind
        bedtime = try c.decodeIfPresent(ClockTime.self, forKey: .bedtime)
        wakeTime = try c.decodeIfPresent(ClockTime.self, forKey: .wakeTime)
        weeklyGoal = try c.decodeIfPresent(Int.self, forKey: .weeklyGoal) ?? 3
        hasOnboarded = try c.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? false
        hideProgress = try c.decodeIfPresent(Bool.self, forKey: .hideProgress) ?? false
        nightModeOverride = try c.decodeIfPresent(NightModeOverride.self, forKey: .nightModeOverride) ?? .automatic
        snoringNoteShown = try c.decodeIfPresent(Bool.self, forKey: .snoringNoteShown) ?? false
        healthConnected = try c.decodeIfPresent(Bool.self, forKey: .healthConnected) ?? false
    }
}

@Observable final class SettingsStore {
    static let keyPrefix = "settings.v1."
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key: String

    var settings: AppSettings {
        didSet { persist() }
    }

    init(defaults: UserDefaults = .standard, ownerID: String = LocalOwner.id) {
        self.defaults = defaults
        self.key = Self.keyPrefix + ownerID
        if let data = defaults.data(forKey: key),
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
        defaults.set(data, forKey: key)
    }
}

extension ClockTime {
    func date(on day: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}
