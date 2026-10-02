import Foundation
import StillmoonCore

enum Format {
    /// "45 m", "1 h", "7 h 20 m"
    static func duration(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) m" }
        if m == 0 { return "\(h) h" }
        return "\(h) h \(m) m"
    }

    /// Rounded minutes, at least 1: "5 min"
    static func exerciseLength(seconds: Int) -> String {
        "\(max(1, Int((Double(seconds) / 60).rounded()))) min"
    }

    /// "4:05"
    static func clock(seconds: Int) -> String {
        String(format: "%ld:%02ld", seconds / 60, seconds % 60)
    }
}

extension ExerciseCategory {
    var title: String {
        switch self {
        case .windDown: "Wind Down"
        case .awakeAtNight: "Awake at Night"
        case .morningReset: "Morning Reset"
        case .learn: "Learn"
        }
    }
}

extension Goal {
    var title: String {
        switch self {
        case .unwind: "Unwind before bed"
        case .understandSleep: "Understand my sleep"
        case .nightWaking: "Handle waking at night"
        case .consistency: "Build a steady routine"
        }
    }
}
