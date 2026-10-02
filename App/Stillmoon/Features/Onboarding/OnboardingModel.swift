import Foundation
import Observation
import StillmoonCore

/// PRD §5 onboarding. Sign-in (Plan 5), Apple Health (Plan 3) and microphone (Plan 4) steps are added later.
@Observable final class OnboardingModel {
    enum Step: Int, CaseIterable {
        case welcome, goal, schedule, health, microphone, privacy, firstExercise
    }

    static let firstExerciseID = "gentle-breathing"

    @ObservationIgnored private let settings: SettingsStore
    private(set) var step: Step = .welcome
    var goal: Goal = .unwind
    var bedtime = ClockTime(hour: 22, minute: 0)
    var wakeTime = ClockTime(hour: 7, minute: 0)

    init(settings: SettingsStore) {
        self.settings = settings
        goal = settings.settings.goal
    }

    var canGoBack: Bool { step != .welcome }

    func next() {
        if step == .schedule {
            settings.settings.bedtime = bedtime
            settings.settings.wakeTime = wakeTime
        }
        move(by: 1)
    }

    func back() { move(by: -1) }

    func chooseGoal(_ goal: Goal) {
        self.goal = goal
        settings.settings.goal = goal
        move(by: 1)
    }

    func skipSchedule() {
        settings.settings.bedtime = nil
        settings.settings.wakeTime = nil
        move(by: 1)
    }

    func finish() {
        settings.settings.hasOnboarded = true
    }

    private func move(by offset: Int) {
        let raw = min(max(step.rawValue + offset, 0), Step.allCases.count - 1)
        step = Step(rawValue: raw)!
    }
}
