import Foundation

public struct ProgressSummary: Sendable, Equatable {
    public let windDownsThisWeek: Int
    public let weeklyGoal: Int
    public let goalMet: Bool
    public let totalWindDowns: Int
    /// 0 = the empty path before the first wind-down; 1...6 = the six illustrated journey stages (PRD §2).
    public let journeyStage: Int

    public init(windDownsThisWeek: Int, weeklyGoal: Int, goalMet: Bool, totalWindDowns: Int, journeyStage: Int) {
        self.windDownsThisWeek = windDownsThisWeek
        self.weeklyGoal = weeklyGoal
        self.goalMet = goalMet
        self.totalWindDowns = totalWindDowns
        self.journeyStage = journeyStage
    }
}

public enum ProgressCalculator {
    /// Total wind-downs needed to reach each journey stage.
    public static let stageThresholds = [0, 1, 3, 6, 10, 15, 21]

    public static func summary(completions: [ExerciseCompletion], weeklyGoal: Int,
                               now: Date, calendar: Calendar) -> ProgressSummary {
        var seen = Set<UUID>()
        let windDowns = completions.filter { $0.category == .windDown && seen.insert($0.id).inserted }

        let week = calendar.dateInterval(of: .weekOfYear, for: now)!
        let thisWeek = windDowns.filter { $0.completedAt >= week.start && $0.completedAt < week.end }.count
        let goal = max(1, weeklyGoal)
        let stage = stageThresholds.lastIndex { windDowns.count >= $0 }!

        return ProgressSummary(
            windDownsThisWeek: thisWeek,
            weeklyGoal: goal,
            goalMet: thisWeek >= goal,
            totalWindDowns: windDowns.count,
            journeyStage: stage
        )
    }
}
