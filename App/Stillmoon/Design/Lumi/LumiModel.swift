import CoreGraphics
import Foundation

/// Lumi's expressions (spec "Lumi"). Pick one through `LumiDirector`.
enum LumiMood: String, CaseIterable, Sendable {
    case calm, wave, happy, cheer, sleepy, concerned

    /// Night never celebrates (PRD §2).
    func effective(isNight: Bool) -> LumiMood {
        isNight && self == .cheer ? .happy : self
    }
}

enum LumiMotion: Equatable, Sendable {
    case float, drift, bounce, still
    /// Grows on the in-breath; `period` is one full breath in seconds.
    case breathe(period: Double)

    /// What actually plays: nothing with Reduce Motion, never a bounce at night.
    func effective(reduceMotion: Bool, isNight: Bool) -> LumiMotion {
        if reduceMotion { return .still }
        if isNight && self == .bounce { return .drift }
        return self
    }
}

/// Which parts of the drawing a mood shows.
struct LumiPose: Equatable {
    enum Eyes: Equatable { case open, happy, sleepy }
    enum Mouth: Equatable { case smile, open, o, wobble }

    var eyes: Eyes
    var mouth: Mouth
    var brows = false
    var leftArmUp = false
    var rightArmUp = false
    var zzz = false
    var sparkles = false

    static func of(_ mood: LumiMood) -> LumiPose {
        switch mood {
        case .calm: LumiPose(eyes: .open, mouth: .smile)
        case .wave: LumiPose(eyes: .open, mouth: .open, rightArmUp: true)
        case .happy: LumiPose(eyes: .happy, mouth: .open)
        case .cheer: LumiPose(eyes: .happy, mouth: .open, leftArmUp: true, rightArmUp: true, sparkles: true)
        case .sleepy: LumiPose(eyes: .sleepy, mouth: .o, zzz: true)
        case .concerned: LumiPose(eyes: .open, mouth: .wobble, brows: true)
        }
    }
}

/// Pure animation curves over time `t` in seconds (any reference). Kept here so they are testable.
enum LumiAnimation {
    struct Transform: Equatable {
        var dy: CGFloat = 0
        var scaleX: CGFloat = 1
        var scaleY: CGFloat = 1
    }

    struct Drift: Equatable {
        var dx: CGFloat
        var dy: CGFloat
        var opacity: Double
    }

    /// 0 → 1 → 0 over `period`, easing in and out; 0 at t = 0.
    static func wave(_ t: Double, period: Double) -> Double {
        (1 - cos(2 * .pi * t / period)) / 2
    }

    static func transform(_ motion: LumiMotion, at t: Double) -> Transform {
        switch motion {
        case .still:
            return Transform()
        case .float:
            return Transform(dy: -7 * wave(t, period: 4))
        case .drift:
            return Transform(dy: -4 * wave(t, period: 7))
        case .breathe(let period):
            let s = 0.92 + 0.14 * wave(t, period: period)
            return Transform(scaleX: s, scaleY: s)
        case .bounce:
            let p = (t / 1.6).truncatingRemainder(dividingBy: 1)
            if p < 0.5 { return Transform(dy: -18 * sin(p * 2 * .pi)) }
            let squash = p < 0.7 ? 0.06 * sin((p - 0.5) / 0.2 * .pi) : 0
            return Transform(scaleX: 1 + squash, scaleY: 1 - squash)
        }
    }

    /// Vertical eye scale: a quick blink near the end of every 5 s.
    static func eyeScale(at t: Double) -> CGFloat {
        let p = (t / 5).truncatingRemainder(dividingBy: 1)
        guard p > 0.93 && p < 0.99 else { return 1 }
        return 1 - 0.9 * sin((p - 0.93) / 0.06 * .pi)
    }

    /// Pom-pom sway in degrees.
    static func pomAngle(at t: Double) -> Double { 10 * wave(t, period: 3) }

    /// A "z" rising and fading over 3 s.
    static func zDrift(at t: Double) -> Drift {
        let p = (t / 3).truncatingRemainder(dividingBy: 1)
        let opacity = p < 0.25 ? p / 0.25 : 1 - (p - 0.25) / 0.75
        return Drift(dx: 10 * p, dy: 6 - 24 * p, opacity: opacity)
    }

    /// Sparkle scale, staggered by index.
    static func sparkleScale(at t: Double, index: Int) -> CGFloat {
        0.6 + 0.5 * wave(t + 0.3 * Double(index), period: 1.4)
    }
}
