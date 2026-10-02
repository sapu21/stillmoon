import Foundation

extension SoundLabel {
    /// Maps Apple's built-in sound classifier identifiers to the three labels Stillmoon keeps.
    public init?(classifierIdentifier: String) {
        switch classifierIdentifier {
        case "snoring": self = .snoringLike
        case "speech": self = .speechLike
        case "cough": self = .coughLike
        default: return nil
        }
    }
}

public struct SoundObservationInput: Sendable, Equatable {
    public let label: SoundLabel
    public let confidence: Double
    public let time: Date

    public init(label: SoundLabel, confidence: Double, time: Date) {
        self.label = label
        self.confidence = confidence
        self.time = time
    }
}

/// Turns a stream of classifier observations into a few events (PRD FR-06).
public struct SoundEventDebouncer: Sendable {
    public static let minimumConfidence = 0.6
    public static let mergeWindow: TimeInterval = 30

    private struct Open: Sendable {
        var event: SoundEvent
        var lastSeen: Date
    }

    private var open: [SoundLabel: Open] = [:]

    public init() {}

    /// Feeds one observation; returns the events this closed, oldest first.
    public mutating func add(_ input: SoundObservationInput) -> [SoundEvent] {
        guard input.confidence >= Self.minimumConfidence else { return [] }
        var closed: [SoundEvent] = []
        let staleLabels = open.keys.filter { input.time.timeIntervalSince(open[$0]!.lastSeen) > Self.mergeWindow }
        for label in staleLabels {
            closed.append(open[label]!.event)
            open[label] = nil
        }
        if var current = open[input.label] {
            current.lastSeen = input.time
            current.event.confidence = max(current.event.confidence, input.confidence)
            open[input.label] = current
        } else {
            open[input.label] = Open(event: SoundEvent(label: input.label, at: input.time, confidence: input.confidence),
                                     lastSeen: input.time)
        }
        return closed.sorted { $0.at < $1.at }
    }

    /// Closes events whose last observation is older than the merge window, oldest first.
    public mutating func closeStale(now: Date) -> [SoundEvent] {
        let stale = open.filter { now.timeIntervalSince($0.value.lastSeen) > Self.mergeWindow }
        for label in stale.keys { open[label] = nil }
        return stale.values.map(\.event).sorted { $0.at < $1.at }
    }

    /// Closes every open event, oldest first.
    public mutating func flush() -> [SoundEvent] {
        let all = open.values.map(\.event).sorted { $0.at < $1.at }
        open.removeAll()
        return all
    }
}
