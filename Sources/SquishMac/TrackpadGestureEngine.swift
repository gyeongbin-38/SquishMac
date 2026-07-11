import Foundation

enum TrackpadMode: String, CaseIterable, Identifiable, Hashable {
    case sixFingerSlime
    case twoThumbWaxCrush

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sixFingerSlime:
            return "6-Finger Slime"
        case .twoThumbWaxCrush:
            return "2-Thumb Wax Crush"
        }
    }

    var targetFingerCount: Int {
        switch self {
        case .sixFingerSlime:
            return 6
        case .twoThumbWaxCrush:
            return 2
        }
    }
}

enum TrackpadSoundKind: Equatable, Hashable {
    case slimeKnead
    case slimeStretch
    case slimeRelease
    case waxPress
    case waxCrack
    case waxCrush

    var title: String {
        switch self {
        case .slimeKnead:
            return "Slime knead"
        case .slimeStretch:
            return "Slime stretch"
        case .slimeRelease:
            return "Slime release"
        case .waxPress:
            return "Wax press"
        case .waxCrack:
            return "Wax crack"
        case .waxCrush:
            return "Wax crush"
        }
    }
}

struct TrackpadGestureTrigger {
    let kind: TrackpadSoundKind
    let intensity: Double
    let label: String
}

struct TrackpadGestureEvaluation {
    let liveIntensity: Double
    let trigger: TrackpadGestureTrigger?
}

final class TrackpadGestureEngine {
    private var lastTriggerTimes: [TrackpadSoundKind: TimeInterval] = [:]
    private var previousFingerCount = 0
    private var previousPressure = 0.0
    private var previousSpread = 0.0

    func reset() {
        lastTriggerTimes.removeAll()
        previousFingerCount = 0
        previousPressure = 0
        previousSpread = 0
    }

    func evaluate(
        mode: TrackpadMode,
        fingerCount: Int,
        pressure: Double,
        movement: Double,
        spread: Double,
        timestamp: TimeInterval
    ) -> TrackpadGestureEvaluation {
        let clampedPressure = pressure.clamped(to: 0.0...1.0)
        let clampedMovement = movement.clamped(to: 0.0...1.0)
        let clampedSpread = spread.clamped(to: 0.0...1.0)

        switch mode {
        case .sixFingerSlime:
            return evaluateSlime(
                fingerCount: fingerCount,
                pressure: clampedPressure,
                movement: clampedMovement,
                timestamp: timestamp
            )
        case .twoThumbWaxCrush:
            return evaluateWaxCrush(
                fingerCount: fingerCount,
                pressure: clampedPressure,
                movement: clampedMovement,
                spread: clampedSpread,
                timestamp: timestamp
            )
        }
    }

    private func evaluateSlime(
        fingerCount: Int,
        pressure: Double,
        movement: Double,
        timestamp: TimeInterval
    ) -> TrackpadGestureEvaluation {
        let fingerFactor = (Double(min(fingerCount, 6)) / 6.0).clamped(to: 0.0...1.0)
        let liveIntensity = (fingerFactor * 0.40 + pressure * 0.42 + movement * 0.18)
            .clamped(to: 0.0...1.0)

        defer {
            previousFingerCount = fingerCount
            previousPressure = pressure
        }

        if previousFingerCount >= 3 && fingerCount == 0 && previousPressure >= 0.18 {
            let intensity = (previousPressure * 0.80 + 0.20).clamped(to: 0.0...1.0)
            return triggerIfReady(
                kind: .slimeRelease,
                intensity: intensity,
                label: "Slime release",
                liveIntensity: liveIntensity,
                timestamp: timestamp,
                interval: 0.10
            )
        }

        guard fingerCount >= 3, liveIntensity >= 0.28 else {
            return TrackpadGestureEvaluation(liveIntensity: liveIntensity, trigger: nil)
        }

        let isStretching = movement >= 0.16 && pressure <= 0.72 && fingerCount >= 4
        let kind: TrackpadSoundKind = isStretching ? .slimeStretch : .slimeKnead
        let interval = max(0.07, (isStretching ? 0.22 : 0.28) - liveIntensity * 0.16)
        let label = isStretching
            ? "Slime stretch"
            : (fingerCount >= 6 ? "6-finger slime press" : "Slime knead")

        return triggerIfReady(
            kind: kind,
            intensity: liveIntensity,
            label: label,
            liveIntensity: liveIntensity,
            timestamp: timestamp,
            interval: interval
        )
    }

    private func evaluateWaxCrush(
        fingerCount: Int,
        pressure: Double,
        movement: Double,
        spread: Double,
        timestamp: TimeInterval
    ) -> TrackpadGestureEvaluation {
        let fingerMatch = fingerCount == 2 ? 1.0 : 0.0
        let crushShape = max(pressure, movement * 0.70 + (1.0 - spread) * 0.30)
        let liveIntensity = (fingerMatch * 0.22 + crushShape * 0.78).clamped(to: 0.0...1.0)

        defer {
            previousFingerCount = fingerCount
            previousPressure = pressure
            previousSpread = spread
        }

        guard fingerCount == 2, liveIntensity >= 0.48 else {
            return TrackpadGestureEvaluation(liveIntensity: liveIntensity, trigger: nil)
        }

        let pressureJump = pressure - previousPressure
        let kind: TrackpadSoundKind
        if pressure >= 0.78 || pressureJump >= 0.22 {
            kind = .waxCrush
        } else if pressure >= 0.58 || movement >= 0.28 {
            kind = .waxCrack
        } else {
            kind = .waxPress
        }

        let interval: TimeInterval
        switch kind {
        case .waxPress:
            interval = 0.24
        case .waxCrack:
            interval = max(0.13, 0.34 - liveIntensity * 0.18)
        case .waxCrush:
            interval = max(0.11, 0.48 - liveIntensity * 0.25)
        case .slimeKnead, .slimeStretch, .slimeRelease:
            interval = 0.20
        }

        return TrackpadGestureEvaluation(
            liveIntensity: liveIntensity,
            trigger: triggerIfReady(
                kind: kind,
                intensity: liveIntensity,
                label: kind.title,
                liveIntensity: liveIntensity,
                timestamp: timestamp,
                interval: interval
            ).trigger
        )
    }

    private func triggerIfReady(
        kind: TrackpadSoundKind,
        intensity: Double,
        label: String,
        liveIntensity: Double,
        timestamp: TimeInterval,
        interval: TimeInterval
    ) -> TrackpadGestureEvaluation {
        let lastTriggerTime = lastTriggerTimes[kind] ?? -Double.infinity
        guard timestamp - lastTriggerTime >= interval else {
            return TrackpadGestureEvaluation(liveIntensity: liveIntensity, trigger: nil)
        }

        lastTriggerTimes[kind] = timestamp
        return TrackpadGestureEvaluation(
            liveIntensity: liveIntensity,
            trigger: TrackpadGestureTrigger(kind: kind, intensity: intensity, label: label)
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
