import StillmoonCore

/// Decides how Lumi looks and what it says. Pure, so the PRD's rules are testable:
/// rewards habits only, never celebrates at night, never mentions sleep metrics.
enum LumiDirector {
    struct Line: Equatable {
        let mood: LumiMood
        let motion: LumiMotion
        let text: String?
    }

    /// Today's header. Counts wind-downs (a habit), never sleep.
    static func todayHeader(progress: ProgressSummary, hideProgress: Bool, isNight: Bool) -> Line {
        if isNight { return Line(mood: .sleepy, motion: .drift, text: nil) }
        if progress.totalWindDowns == 0 {
            return Line(mood: .wave, motion: .float, text: "Hi! Want to try a few calm minutes?")
        }
        if hideProgress { return Line(mood: .happy, motion: .float, text: "Here whenever you need a calm minute.") }
        if progress.windDownsThisWeek >= progress.weeklyGoal {
            return Line(mood: .happy, motion: .float, text: "This week's moon is full.")
        }
        let left = progress.weeklyGoal - progress.windDownsThisWeek
        return Line(mood: .happy, motion: .float,
                    text: left == 1 ? "One more wind-down fills this week's moon." : "\(left) more wind-downs fill this week's moon.")
    }

    static let checkInLines = [
        "Rough night. Let's go gently today.",
        "Slow mornings are allowed.",
        "Okay is perfectly okay.",
        "Nice. Let's keep tonight calm too.",
        "Wonderful! Hold on to that feeling.",
    ]

    /// Lumi mirrors the chosen restedness (1...5) with comfort, never judgement.
    static func checkIn(level: Int, isNight: Bool) -> Line {
        let i = min(max(level, 1), 5) - 1
        let moods: [LumiMood] = [.concerned, .sleepy, .calm, .happy, .cheer]
        let motion: LumiMotion = isNight ? .drift : (i == 4 ? .bounce : .float)
        return Line(mood: moods[i].effective(isNight: isNight), motion: motion, text: checkInLines[i])
    }

    static func onboarding(_ step: OnboardingModel.Step) -> Line {
        switch step {
        case .welcome: Line(mood: .wave, motion: .float, text: "Hi, I'm Lumi! I'll help you find a calmer next step each night.")
        case .goal: Line(mood: .calm, motion: .float, text: "What would you like a little help with?")
        case .schedule: Line(mood: .calm, motion: .float, text: "When do you usually sleep? I'll dim things down at bedtime.")
        case .health: Line(mood: .calm, motion: .float, text: "Got a watch? I can read its sleep estimates. They stay on this iPhone.")
        case .microphone: Line(mood: .calm, motion: .float, text: "I can listen for snoring or coughing during a session you start. Nothing is recorded.")
        case .privacy: Line(mood: .happy, motion: .float, text: "Your nights stay yours.")
        case .firstExercise: Line(mood: .happy, motion: .float, text: "Want to try a few calm minutes together?")
        }
    }

    /// Every line Lumi can say, for copy checks.
    static var allLines: [String] {
        let weeks = (0...4).map {
            ProgressSummary(windDownsThisWeek: $0, weeklyGoal: 3, goalMet: $0 >= 3, totalWindDowns: $0 + 1, journeyStage: 1)
        }
        let headers = weeks.flatMap { p in
            [false, true].compactMap { todayHeader(progress: p, hideProgress: $0, isNight: false).text }
        }
        let first = ProgressSummary(windDownsThisWeek: 0, weeklyGoal: 3, goalMet: false, totalWindDowns: 0, journeyStage: 0)
        let welcome = todayHeader(progress: first, hideProgress: false, isNight: false).text
        let onboardingLines = OnboardingModel.Step.allCases.compactMap { onboarding($0).text }
        return headers + [welcome].compactMap { $0 } + checkInLines + onboardingLines
    }
}
