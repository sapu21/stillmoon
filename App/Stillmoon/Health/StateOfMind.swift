import Foundation

/// The user's own "How tense do you feel?" answer, as Apple Health State of Mind values.
/// The label is what they told us, never an inference (PRD principle 6).
enum StateOfMindMapping {
    enum Feeling: Equatable { case calm, stressed }

    private static func clamped(_ tension: Int) -> Int { min(max(tension, 1), 5) }

    /// -1 (very unpleasant) ... 1 (very pleasant).
    static func valence(tension: Int) -> Double {
        [0.6, 0.3, 0, -0.3, -0.6][clamped(tension) - 1]
    }

    static func feeling(tension: Int) -> Feeling? {
        switch clamped(tension) {
        case 1, 2: .calm
        case 4, 5: .stressed
        default: nil
        }
    }
}
