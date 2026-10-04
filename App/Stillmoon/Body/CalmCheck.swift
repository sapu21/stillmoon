import Foundation

/// Before-and-after numbers around one exercise. Body values are phone estimates; `tense` values are the user's own answers.
struct CalmCheck: Identifiable, Equatable, Hashable, Sendable {
    var id = UUID()
    var exerciseID: String
    var at: Date
    var bpmBefore: Double?
    var bpmAfter: Double?
    /// RMSSD in milliseconds.
    var hrvBefore: Double?
    var hrvAfter: Double?
    /// 1 = calm ... 5 = very tense, as reported.
    var tenseBefore: Int?
    var tenseAfter: Int?
    /// Breaths a minute, first and last clear estimate during the exercise.
    var breathsStart: Double?
    var breathsEnd: Double?

    var isEmpty: Bool {
        bpmBefore == nil && bpmAfter == nil && tenseBefore == nil && tenseAfter == nil
            && breathsStart == nil && breathsEnd == nil
    }
}
