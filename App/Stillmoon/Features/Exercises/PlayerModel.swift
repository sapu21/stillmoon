import Foundation
import Observation
import StillmoonCore

/// Drives a step-by-step exercise. The view calls `tick()` once a second.
@Observable final class PlayerModel {
    let exercise: Exercise
    @ObservationIgnored private let store: LocalStore
    @ObservationIgnored private let now: () -> Date
    private(set) var stepIndex = 0
    private(set) var elapsedInStep = 0
    private(set) var isPlaying = false
    private(set) var isComplete = false

    init(exercise: Exercise, store: LocalStore, now: @escaping () -> Date = Date.init) {
        precondition(!exercise.steps.isEmpty, "Exercise \(exercise.id) has no steps")
        self.exercise = exercise
        self.store = store
        self.now = now
    }

    var currentStep: ExerciseStep { exercise.steps[stepIndex] }

    var remainingSeconds: Int {
        guard !isComplete else { return 0 }
        let later = exercise.steps.dropFirst(stepIndex + 1).reduce(0) { $0 + $1.seconds }
        return max(0, currentStep.seconds - elapsedInStep) + later
    }

    func play() {
        guard !isComplete else { return }
        isPlaying = true
    }

    func pause() { isPlaying = false }

    func togglePlay() { isPlaying ? pause() : play() }

    func tick() {
        guard isPlaying, !isComplete else { return }
        elapsedInStep += 1
        if elapsedInStep >= currentStep.seconds { advance() }
    }

    func skipStep() {
        guard !isComplete else { return }
        advance()
    }

    /// Records the completion exactly once. Leaving early never calls this.
    func finish() {
        guard !isComplete else { return }
        isComplete = true
        isPlaying = false
        store.addCompletion(ExerciseCompletion(exerciseID: exercise.id, category: exercise.category, completedAt: now()))
    }

    private func advance() {
        if stepIndex + 1 < exercise.steps.count {
            stepIndex += 1
            elapsedInStep = 0
        } else {
            finish()
        }
    }
}
