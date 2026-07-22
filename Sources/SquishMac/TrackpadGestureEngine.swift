import Foundation

enum TrackpadMode: String, CaseIterable, Identifiable, Hashable, Codable {
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

enum TrackpadSoundKind: String, CaseIterable, Equatable, Hashable, Codable {
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

struct TrackpadTuning: Equatable, Codable {
    static let standard = TrackpadTuning(response: 1.0, soundDensity: 1.0)

    let response: Double
    let soundDensity: Double

    init(response: Double, soundDensity: Double) {
        self.response = response.clamped(to: 0.5...1.75)
        self.soundDensity = soundDensity.clamped(to: 0.5...2.0)
    }
}

struct TrackpadGestureTrigger: Equatable {
    let kind: TrackpadSoundKind
    let intensity: Double
    let label: String
}

struct TrackpadGestureEvaluation {
    let liveIntensity: Double
    let trigger: TrackpadGestureTrigger?
}

final class TrackpadGestureEngine {
    private enum WaxStage: Int {
        case idle
        case press
        case crack
        case crush
    }

    private var lastTriggerTimes: [TrackpadSoundKind: TimeInterval] = [:]
    private var previousFingerCount = 0
    private var previousPressure = 0.0
    private var previousSpread = 0.0
    private var waxStage: WaxStage = .idle

    func reset() {
        lastTriggerTimes.removeAll()
        previousFingerCount = 0
        previousPressure = 0
        previousSpread = 0
        waxStage = .idle
    }

    func evaluate(
        mode: TrackpadMode,
        fingerCount: Int,
        pressure: Double,
        movement: Double,
        spread: Double,
        timestamp: TimeInterval,
        tuning: TrackpadTuning = .standard
    ) -> TrackpadGestureEvaluation {
        let clampedPressure = pressure.clamped(to: 0.0...1.0)
        let clampedMovement = movement.clamped(to: 0.0...1.0)
        let clampedSpread = spread.clamped(to: 0.0...1.0)
        let responsivePressure = (clampedPressure * tuning.response).clamped(to: 0.0...1.0)
        let responsiveMovement = (clampedMovement * tuning.response).clamped(to: 0.0...1.0)

        switch mode {
        case .sixFingerSlime:
            return evaluateSlime(
                fingerCount: fingerCount,
                pressure: responsivePressure,
                movement: responsiveMovement,
                spread: clampedSpread,
                timestamp: timestamp,
                soundDensity: tuning.soundDensity
            )
        case .twoThumbWaxCrush:
            return evaluateWaxCrush(
                fingerCount: fingerCount,
                pressure: responsivePressure,
                movement: responsiveMovement,
                spread: clampedSpread,
                timestamp: timestamp,
                soundDensity: tuning.soundDensity
            )
        }
    }

    private func evaluateSlime(
        fingerCount: Int,
        pressure: Double,
        movement: Double,
        spread: Double,
        timestamp: TimeInterval,
        soundDensity: Double
    ) -> TrackpadGestureEvaluation {
        let fingerFactor = (Double(min(fingerCount, 6)) / 6.0).clamped(to: 0.0...1.0)
        let liveIntensity = (fingerFactor * 0.40 + pressure * 0.42 + movement * 0.18)
            .clamped(to: 0.0...1.0)
        let pressureDelta = abs(pressure - previousPressure)
        let spreadDelta = abs(spread - previousSpread)
        let isInitialContact = previousFingerCount < 3 && fingerCount >= 3

        defer {
            previousFingerCount = fingerCount
            previousPressure = pressure
            previousSpread = spread
        }

        if previousFingerCount >= 3 && fingerCount == 0 && previousPressure >= 0.18 {
            let intensity = (previousPressure * 0.80 + 0.20).clamped(to: 0.0...1.0)
            return triggerIfReady(
                kind: .slimeRelease,
                intensity: intensity,
                label: "Slime release",
                liveIntensity: liveIntensity,
                timestamp: timestamp,
                interval: densityAdjusted(0.10, soundDensity: soundDensity)
            )
        }

        guard fingerCount >= 3, liveIntensity >= 0.28 else {
            return TrackpadGestureEvaluation(liveIntensity: liveIntensity, trigger: nil)
        }

        let hasTextureChange = isInitialContact
            || movement >= 0.025
            || pressureDelta >= 0.018
            || spreadDelta >= 0.025
        guard hasTextureChange else {
            return TrackpadGestureEvaluation(liveIntensity: liveIntensity, trigger: nil)
        }

        let isStretching = movement >= 0.16 && pressure <= 0.72 && fingerCount >= 4
        let kind: TrackpadSoundKind = isStretching ? .slimeStretch : .slimeKnead
        let baseInterval = max(0.07, (isStretching ? 0.22 : 0.28) - liveIntensity * 0.16)
        let label = isStretching
            ? "Slime stretch"
            : (fingerCount >= 6 ? "6-finger slime press" : "Slime knead")

        return triggerIfReady(
            kind: kind,
            intensity: liveIntensity,
            label: label,
            liveIntensity: liveIntensity,
            timestamp: timestamp,
            interval: densityAdjusted(baseInterval, soundDensity: soundDensity)
        )
    }

    private func evaluateWaxCrush(
        fingerCount: Int,
        pressure: Double,
        movement: Double,
        spread: Double,
        timestamp: TimeInterval,
        soundDensity: Double
    ) -> TrackpadGestureEvaluation {
        let fingerMatch = fingerCount == 2 ? 1.0 : 0.0
        let closingSpeed = previousFingerCount == 2 ? max(0, previousSpread - spread) : 0
        let crushShape = max(pressure, movement * 0.64 + closingSpeed * 0.22 + (1.0 - spread) * 0.14)
        let liveIntensity = (fingerMatch * 0.22 + crushShape * 0.78).clamped(to: 0.0...1.0)

        defer {
            previousFingerCount = fingerCount
            previousPressure = pressure
            previousSpread = spread
        }

        guard fingerCount == 2, liveIntensity >= 0.48 else {
            if fingerCount == 0 {
                waxStage = .idle
            }
            return TrackpadGestureEvaluation(liveIntensity: liveIntensity, trigger: nil)
        }

        let pressureJump = previousFingerCount == 2 ? pressure - previousPressure : 0
        let nextStage: WaxStage
        if pressure >= 0.78 || pressureJump >= 0.22 || (closingSpeed >= 0.20 && pressure >= 0.55) {
            nextStage = .crush
        } else if pressure >= 0.58 || movement >= 0.28 || closingSpeed >= 0.10 {
            nextStage = .crack
        } else {
            nextStage = .press
        }

        guard nextStage.rawValue > waxStage.rawValue else {
            return TrackpadGestureEvaluation(liveIntensity: liveIntensity, trigger: nil)
        }
        waxStage = nextStage

        let kind: TrackpadSoundKind
        let baseInterval: TimeInterval
        switch nextStage {
        case .idle:
            return TrackpadGestureEvaluation(liveIntensity: liveIntensity, trigger: nil)
        case .press:
            kind = .waxPress
            baseInterval = 0.24
        case .crack:
            kind = .waxCrack
            baseInterval = max(0.13, 0.34 - liveIntensity * 0.18)
        case .crush:
            kind = .waxCrush
            baseInterval = max(0.11, 0.48 - liveIntensity * 0.25)
        }

        return triggerIfReady(
            kind: kind,
            intensity: liveIntensity,
            label: kind.title,
            liveIntensity: liveIntensity,
            timestamp: timestamp,
            interval: densityAdjusted(baseInterval, soundDensity: soundDensity)
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

    private func densityAdjusted(_ interval: TimeInterval, soundDensity: Double) -> TimeInterval {
        interval / soundDensity.clamped(to: 0.5...2.0)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
