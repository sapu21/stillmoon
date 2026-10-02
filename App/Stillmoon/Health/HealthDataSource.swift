import Foundation
import StillmoonCore

enum HealthError: Error, Equatable {
    case unavailable
}

/// Where sleep estimates come from. Samples are read on demand and never stored by Stillmoon.
protocol HealthDataSource: AnyObject {
    var isAvailable: Bool { get }
    func requestAuthorization() async throws
    /// Samples overlapping [start, end), from every source.
    func sleepSamples(from start: Date, to end: Date) async throws -> [SleepSample]
    func saveMindfulSession(start: Date, end: Date) async throws
}

extension SleepStage {
    var title: String {
        switch self {
        case .inBed: "In bed"
        case .awake: "Awake"
        case .core: "Core"
        case .deep: "Deep"
        case .rem: "REM"
        case .asleepUnspecified: "Asleep"
        }
    }
}
