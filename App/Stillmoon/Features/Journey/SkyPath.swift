import CoreGraphics
import StillmoonCore

/// One star per wind-down on the Journey path. Stars only ever light, never unlight (PRD §8).
struct SkyStar: Identifiable, Equatable {
    enum State: Equatable { case lit, next, locked }
    let index: Int
    let state: State
    var id: Int { index }
}

struct SkyStage: Identifiable, Equatable {
    let number: Int
    let name: String
    let stars: [SkyStar]
    var id: Int { number }
    var litCount: Int { stars.filter { $0.state == .lit }.count }
}

enum SkyPath {
    /// Stage k (1...6) holds the stars between thresholds k-1 and k.
    static func stages(totalWindDowns: Int, names: [String] = JourneyModel.stageNames,
                       thresholds: [Int] = ProgressCalculator.stageThresholds) -> [SkyStage] {
        (1..<thresholds.count).map { n in
            let stars = (thresholds[n - 1]..<thresholds[n]).map { i in
                SkyStar(index: i, state: i < totalWindDowns ? .lit : (i == totalWindDowns ? .next : .locked))
            }
            return SkyStage(number: n, name: names[n], stars: stars)
        }
    }

    /// The stage holding the star at `index`, or nil outside the sky.
    static func stage(ofStar index: Int, thresholds: [Int] = ProgressCalculator.stageThresholds) -> Int? {
        (1..<thresholds.count).first { index >= thresholds[$0 - 1] && index < thresholds[$0] }
    }

    /// Lumi beside the next star: sleepy and drifting at night (PRD §2: no celebration at night).
    static func lumi(isNight: Bool) -> LumiDirector.Line {
        isNight ? LumiDirector.Line(mood: .sleepy, motion: .drift, text: nil)
                : LumiDirector.Line(mood: .happy, motion: .float, text: nil)
    }

    /// Star shimmer and the next-star pulse: daytime only, never with Reduce Motion.
    static func animatesStars(isNight: Bool, reduceMotion: Bool) -> Bool { !isNight && !reduceMotion }

    /// Horizontal offset from the path's center line: a gentle zigzag.
    static func xOffset(forStar index: Int) -> CGFloat {
        let pattern: [CGFloat] = [0, -60, -90, -60, 0, 60, 90, 60]
        return pattern[index % pattern.count]
    }
}
