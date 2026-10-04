import StillmoonCore

enum CompletionStyle: Equatable {
    /// Daytime wind-down: Lumi cheers, the weekly moon fills, a star lights.
    case celebrate
    /// Night, or any other exercise: the player's quiet "Well done. Rest now." (PRD §7: no reward at night).
    case quiet

    static func style(for category: ExerciseCategory, isNight: Bool) -> CompletionStyle {
        category == .windDown && !isNight ? .celebrate : .quiet
    }
}

/// What the celebration shows, from progress that already includes this completion.
struct CompletionSummary: Equatable {
    struct Star: Equatable {
        let stageName: String
        let litInStage: Int
        let starsInStage: Int
    }

    let minutes: Int
    let windDownsThisWeek: Int
    let weeklyGoal: Int
    /// The star this completion lit; nil once the sky is full.
    let star: Star?
    let savedToHealth: Bool
    /// False when the user hid progress in Settings (PRD §8): no counts, moons or stars.
    let showsProgress: Bool

    /// Health writes are fire-and-forget, so this never claims a confirmed save.
    var healthLine: String? { savedToHealth ? "Mindful Minutes go to Apple Health when you've allowed it." : nil }

    init(progress: ProgressSummary, playedSeconds: Int, savedToHealth: Bool, hideProgress: Bool = false,
         names: [String] = JourneyModel.stageNames, thresholds: [Int] = ProgressCalculator.stageThresholds) {
        minutes = max(1, Int((Double(playedSeconds) / 60).rounded()))
        windDownsThisWeek = progress.windDownsThisWeek
        weeklyGoal = progress.weeklyGoal
        self.savedToHealth = savedToHealth
        showsProgress = !hideProgress
        let index = progress.totalWindDowns - 1
        if !hideProgress, let stage = SkyPath.stage(ofStar: index, thresholds: thresholds) {
            star = Star(stageName: names[stage], litInStage: index - thresholds[stage - 1] + 1,
                        starsInStage: thresholds[stage] - thresholds[stage - 1])
        } else {
            star = nil
        }
    }
}
