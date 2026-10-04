import Foundation
import Observation

/// "How tense do you feel?" from 1 (calm) to 5 (very tense).
enum TensionScale {
    static let labels = ["Calm", "A little tense", "Somewhat tense", "Tense", "Very tense"]

    static func label(_ level: Int) -> String { labels[min(max(level, 1), 5) - 1] }
}

/// The before / exercise / after steps of one calm check. Pure state, so the rules are testable:
/// unclear readings never become numbers, and nothing is saved when every step was skipped.
@Observable final class CalmCheckFlow {
    enum Step: Equatable { case before, exercise, after, done }

    let isEnabled: Bool
    private(set) var step: Step
    private(set) var check: CalmCheck

    init(exerciseID: String, at: Date, enabled: Bool) {
        isEnabled = enabled
        step = enabled ? .before : .exercise
        check = CalmCheck(exerciseID: exerciseID, at: at)
    }

    /// "Check again" is offered once the exercise is over, if calm checks are on.
    var offersCheckAgain: Bool { isEnabled && step == .exercise }

    var savable: CalmCheck? { check.isEmpty ? nil : check }

    func recordTension(_ level: Int) {
        switch step {
        case .before: check.tenseBefore = level
        case .after: check.tenseAfter = level
        case .exercise, .done: break
        }
    }

    func recordPulse(_ result: PulseResult) {
        guard case .reading(let bpm, let hrv) = result else { return }
        switch step {
        case .before: check.bpmBefore = bpm; check.hrvBefore = hrv
        case .after: check.bpmAfter = bpm; check.hrvAfter = hrv
        case .exercise, .done: break
        }
    }

    /// Breathing estimates during the exercise: keeps the first and the latest clear one.
    func recordBreathing(_ perMinute: Double?) {
        guard let perMinute else { return }
        if check.breathsStart == nil { check.breathsStart = perMinute }
        check.breathsEnd = perMinute
    }

    func finishBefore() { if step == .before { step = .exercise } }
    func startAfter() { if offersCheckAgain { step = .after } }
    func finishAfter() { if step == .after { step = .done } }
}

/// One result line; estimates and the user's own answers are always labelled apart (PRD principle 3).
struct CalmCheckLine: Equatable, Hashable {
    enum Source: Equatable, Hashable {
        case camera, microphone, you

        var label: String {
            switch self {
            case .camera: "Estimate from your phone's camera"
            case .microphone: "Estimate from your microphone"
            case .you: "What you told us"
            }
        }
    }

    let text: String
    let source: Source

    static func lines(for c: CalmCheck) -> [CalmCheckLine] {
        var lines: [CalmCheckLine] = []
        if let text = pair(c.bpmBefore.map(whole), c.bpmAfter.map(whole), prefix: "Heart rate ", unit: " bpm") {
            lines.append(CalmCheckLine(text: text, source: .camera))
        }
        if let a = c.breathsStart.map(whole), let b = c.breathsEnd.map(whole) {
            lines.append(CalmCheckLine(text: a == b ? "Breathing about \(a) a minute" : "Breathing about \(a) → \(b) a minute",
                                       source: .microphone))
        }
        let before = c.tenseBefore.map { TensionScale.label($0).lowercased() }
        let after = c.tenseAfter.map { TensionScale.label($0).lowercased() }
        if let text = pair(before, after, prefix: "You felt ", unit: "") {
            lines.append(CalmCheckLine(text: text, source: .you))
        }
        return lines
    }

    private static func whole(_ x: Double) -> String { String(Int(x.rounded())) }

    private static func pair(_ before: String?, _ after: String?, prefix: String, unit: String) -> String? {
        switch (before, after) {
        case let (b?, a?): "\(prefix)\(b) → \(a)\(unit)"
        case let (b?, nil): "\(prefix)\(b)\(unit) before"
        case let (nil, a?): "\(prefix)\(a)\(unit) after"
        case (nil, nil): nil
        }
    }
}
