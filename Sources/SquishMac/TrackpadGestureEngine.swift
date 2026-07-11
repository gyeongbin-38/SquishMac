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

enum TrackpadSoundKind: Equatable {
    case slimeKnead
    case waxCrush
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
    private var lastTriggerTime = -Double.infinity

    func reset() {
        lastTriggerTime = -Double.infinity
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

        guard fingerCount >= 3, liveIntensity >= 0.28 else {
            return TrackpadGestureEvaluation(liveIntensity: liveIntensity, trigger: nil)
        }

        let interval = max(0.07, 0.28 - liveIntensity * 0.16)
        guard timestamp - lastTriggerTime >= interval else {
            return TrackpadGestureEvaluation(liveIntensity: liveIntensity, trigger: nil)
        }

        lastTriggerTime = timestamp
        let label = fingerCount >= 6 ? "6-finger slime press" : "Slime knead"
        return TrackpadGestureEvaluation(
            liveIntensity: liveIntensity,
            trigger: TrackpadGestureTrigger(kind: .slimeKnead, intensity: liveIntensity, label: label)
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

        guard fingerCount == 2, liveIntensity >= 0.48 else {
            return TrackpadGestureEvaluation(liveIntensity: liveIntensity, trigger: nil)
        }

        let interval = max(0.10, 0.42 - liveIntensity * 0.22)
        guard timestamp - lastTriggerTime >= interval else {
            return TrackpadGestureEvaluation(liveIntensity: liveIntensity, trigger: nil)
        }

        lastTriggerTime = timestamp
        return TrackpadGestureEvaluation(
            liveIntensity: liveIntensity,
            trigger: TrackpadGestureTrigger(kind: .waxCrush, intensity: liveIntensity, label: "Wax squish crush")
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
