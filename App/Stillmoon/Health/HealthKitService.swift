import Foundation
import HealthKit
import StillmoonCore

enum SleepStageMapping {
    static func stage(forHealthKitValue value: Int) -> SleepStage? {
        switch HKCategoryValueSleepAnalysis(rawValue: value) {
        case .inBed: .inBed
        case .awake: .awake
        case .asleepCore: .core
        case .asleepDeep: .deep
        case .asleepREM: .rem
        case .asleepUnspecified: .asleepUnspecified
        default: nil
        }
    }
}

final class HealthKitService: HealthDataSource {
    private let store = HKHealthStore()
    private let sleepType = HKCategoryType(.sleepAnalysis)
    private let mindfulType = HKCategoryType(.mindfulSession)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthError.unavailable }
        try await store.requestAuthorization(toShare: [mindfulType], read: [sleepType])
    }

    func sleepSamples(from start: Date, to end: Date) async throws -> [SleepSample] {
        guard isAvailable else { throw HealthError.unavailable }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)])
        let samples = try await descriptor.result(for: store)
        return samples.compactMap { sample in
            guard let stage = SleepStageMapping.stage(forHealthKitValue: sample.value) else { return nil }
            return SleepSample(stage: stage, start: sample.startDate, end: sample.endDate,
                               sourceName: sample.sourceRevision.source.name)
        }
    }

    func saveMindfulSession(start: Date, end: Date) async throws {
        guard isAvailable else { throw HealthError.unavailable }
        let sample = HKCategorySample(type: mindfulType, value: HKCategoryValue.notApplicable.rawValue,
                                      start: start, end: end)
        try await store.save(sample)
    }

    func requestStateOfMindAuthorization() async throws {
        guard isAvailable else { throw HealthError.unavailable }
        guard #available(iOS 18, *) else { return }
        try await store.requestAuthorization(toShare: [HKObjectType.stateOfMindType()], read: [])
    }

    func saveStateOfMind(tension: Int, at date: Date) async throws {
        guard isAvailable else { throw HealthError.unavailable }
        guard #available(iOS 18, *) else { return }
        let labels: [HKStateOfMind.Label] = switch StateOfMindMapping.feeling(tension: tension) {
        case .calm: [.calm]
        case .stressed: [.stressed]
        case nil: []
        }
        let state = HKStateOfMind(date: date, kind: .momentaryEmotion,
                                  valence: StateOfMindMapping.valence(tension: tension),
                                  labels: labels, associations: [.health])
        try await store.save(state)
    }
}
