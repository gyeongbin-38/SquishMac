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
    case slimeBubble
    case slimeStretchFailure
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
        case .slimeBubble:
            return "Slime bar-pung"
        case .slimeStretchFailure:
            return "Stretch too fast"
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

struct TrackpadTuning: Equatable, Hashable, Codable {
    static let standard = TrackpadTuning(response: 1.0, soundDensity: 1.0)

    let response: Double
    let soundDensity: Double

    init(response: Double, soundDensity: Double) {
        self.response = response.clamped(to: 0.5...1.75)
        self.soundDensity = soundDensity.clamped(to: 0.5...2.0)
    }

    func applying(profile recommendation: TrackpadTuning) -> TrackpadTuning {
        TrackpadTuning(
            response: response * recommendation.response,
            soundDensity: soundDensity * recommendation.soundDensity
        )
    }
}

struct TrackpadGestureTrigger: Equatable {
    let kind: TrackpadSoundKind
    let intensity: Double
    let label: String
    let soundPackIDOverride: String?
    let volumeScale: Double

    init(
        kind: TrackpadSoundKind,
        intensity: Double,
        label: String,
        soundPackIDOverride: String? = nil,
        volumeScale: Double = 1.0
    ) {
        self.kind = kind
        self.intensity = intensity
        self.label = label
        self.soundPackIDOverride = soundPackIDOverride
        self.volumeScale = volumeScale.clamped(to: 0.1...1.0)
    }
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
    private var previousWaxSignal = 0.0
    private var waxStage: WaxStage = .idle
    private var slimeStretchFailureLatched = false
    private var slimeBubbleArmTime: TimeInterval?
    private var slimeBubbleMaximumSpread = 0.0
    private var lastInteractionTriggerTime = -Double.infinity
    private var activeMinimumSoundInterval = 0.0

    var isBarPungPrepared: Bool {
        slimeBubbleArmTime != nil
    }

    func reset() {
        lastTriggerTimes.removeAll()
        previousFingerCount = 0
        previousPressure = 0
        previousSpread = 0
        previousWaxSignal = 0
        waxStage = .idle
        slimeStretchFailureLatched = false
        resetSlimeBubble()
        lastInteractionTriggerTime = -Double.infinity
        activeMinimumSoundInterval = 0
    }

    func evaluate(
        mode: TrackpadMode,
        fingerCount: Int,
        pressure: Double,
        movement: Double,
        spread: Double,
        timestamp: TimeInterval,
        tuning: TrackpadTuning = .standard,
        interactionRules: SlimeInteractionRules = .standard
    ) -> TrackpadGestureEvaluation {
        let clampedPressure = pressure.clamped(to: 0.0...1.0)
        let clampedMovement = movement.clamped(to: 0.0...1.0)
        let clampedSpread = spread.clamped(to: 0.0...1.0)
        let responsivePressure = (clampedPressure * tuning.response).clamped(to: 0.0...1.0)
        let responsiveMovement = (clampedMovement * tuning.response).clamped(to: 0.0...1.0)
        activeMinimumSoundInterval = interactionRules.effectiveMinimumSoundInterval

        switch mode {
        case .sixFingerSlime:
            return evaluateSlime(
                fingerCount: fingerCount,
                pressure: responsivePressure,
                movement: responsiveMovement,
                spread: clampedSpread,
                timestamp: timestamp,
                soundDensity: tuning.soundDensity,
                interactionRules: interactionRules
            )
        case .twoThumbWaxCrush:
            return evaluateWaxCrush(
                fingerCount: fingerCount,
                pressure: responsivePressure,
                movement: responsiveMovement,
                spread: clampedSpread,
                timestamp: timestamp,
                soundDensity: tuning.soundDensity,
                interactionRules: interactionRules
            )
        }
    }

    private func evaluateSlime(
        fingerCount: Int,
        pressure: Double,
        movement: Double,
        spread: Double,
        timestamp: TimeInterval,
        soundDensity: Double,
        interactionRules: SlimeInteractionRules
    ) -> TrackpadGestureEvaluation {
        let fingerFactor = (Double(min(fingerCount, 6)) / 6.0).clamped(to: 0.0...1.0)
        let liveIntensity = (fingerFactor * 0.40 + pressure * 0.42 + movement * 0.18)
            .clamped(to: 0.0...1.0)
        let pressureDelta = abs(pressure - previousPressure)
        let spreadDelta = abs(spread - previousSpread)
        let minimumFingerCount = interactionRules.minimumFingerCount
        let isInitialContact = previousFingerCount < minimumFingerCount
            && fingerCount >= minimumFingerCount

        defer {
            previousFingerCount = fingerCount
            previousPressure = pressure
            previousSpread = spread
        }

        if fingerCount < minimumFingerCount
            || movement <= interactionRules.fastStretchFailureResetThreshold {
            slimeStretchFailureLatched = false
        }

        if let bubbleRules = interactionRules.bubbleGesture {
            if let armTime = slimeBubbleArmTime,
               timestamp - armTime > bubbleRules.maximumDuration {
                resetSlimeBubble()
            }

            if fingerCount < bubbleRules.minimumFingerCount {
                resetSlimeBubble()
            } else if let armTime = slimeBubbleArmTime {
                slimeBubbleMaximumSpread = max(slimeBubbleMaximumSpread, spread)
                let spreadDrop = max(0, slimeBubbleMaximumSpread - spread)
                let isSeal = timestamp > armTime
                    && movement >= bubbleRules.minimumSealMovement
                    && pressure >= bubbleRules.minimumSealPressure
                    && spreadDrop >= bubbleRules.minimumSpreadDrop
                if isSeal {
                    let sealProgress = (
                        spreadDrop / max(bubbleRules.minimumSpreadDrop, 0.01)
                    ).clamped(to: 0.0...1.0)
                    let intensity = (
                        pressure * 0.42 + movement * 0.33 + sealProgress * 0.25
                    ).clamped(to: 0.0...1.0)
                    resetSlimeBubble()
                    return triggerIfReady(
                        kind: .slimeBubble,
                        intensity: intensity,
                        label: bubbleRules.gestureLabel,
                        liveIntensity: liveIntensity,
                        timestamp: timestamp,
                        interval: densityAdjusted(
                            bubbleRules.cooldown,
                            soundDensity: soundDensity
                        ),
                        soundPackIDOverride: bubbleRules.soundPackID,
                        volumeScale: interactionRules.effectiveVolumeScale
                    )
                }
            } else if spread >= bubbleRules.armSpreadThreshold {
                slimeBubbleArmTime = timestamp
                slimeBubbleMaximumSpread = spread
            }
        } else {
            resetSlimeBubble()
        }

        if previousFingerCount >= minimumFingerCount
            && fingerCount == 0
            && previousPressure >= 0.18 {
            let intensity = (previousPressure * 0.80 + 0.20).clamped(to: 0.0...1.0)
            return triggerIfReady(
                kind: .slimeRelease,
                intensity: intensity,
                label: "Slime release",
                liveIntensity: liveIntensity,
                timestamp: timestamp,
                interval: densityAdjusted(0.10, soundDensity: soundDensity),
                soundPackIDOverride: interactionRules.releaseSoundPackID,
                volumeScale: interactionRules.effectiveVolumeScale
            )
        }

        guard fingerCount >= minimumFingerCount, liveIntensity >= 0.28 else {
            return TrackpadGestureEvaluation(liveIntensity: liveIntensity, trigger: nil)
        }

        let hasTextureChange = isInitialContact
            || movement >= 0.025
            || pressureDelta >= 0.018
            || spreadDelta >= 0.025
        guard hasTextureChange else {
            return TrackpadGestureEvaluation(liveIntensity: liveIntensity, trigger: nil)
        }

        let isStretching = movement >= interactionRules.stretchMovementThreshold
            && pressure <= 0.72
            && fingerCount >= max(4, minimumFingerCount)
        if isStretching,
           let failureThreshold = interactionRules.fastStretchFailureMovementThreshold,
           movement >= failureThreshold,
           !slimeStretchFailureLatched {
            let failureProgress = (
                (movement - failureThreshold) / max(0.01, 1 - failureThreshold)
            ).clamped(to: 0.0...1.0)
            let evaluation = triggerIfReady(
                kind: .slimeStretchFailure,
                intensity: (0.70 + failureProgress * 0.30).clamped(to: 0.0...1.0),
                label: interactionRules.failureGestureLabel,
                liveIntensity: liveIntensity,
                timestamp: timestamp,
                interval: densityAdjusted(
                    interactionRules.fastStretchFailureCooldown,
                    soundDensity: soundDensity
                ),
                soundPackIDOverride: interactionRules.failureSoundPackID,
                volumeScale: interactionRules.effectiveVolumeScale
            )
            if evaluation.trigger != nil {
                slimeStretchFailureLatched = true
            }
            return evaluation
        }

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
            interval: densityAdjusted(baseInterval, soundDensity: soundDensity),
            soundPackIDOverride: interactionRules.soundPackID(for: kind),
            volumeScale: interactionRules.effectiveVolumeScale
        )
    }

    private func evaluateWaxCrush(
        fingerCount: Int,
        pressure: Double,
        movement: Double,
        spread: Double,
        timestamp: TimeInterval,
        soundDensity: Double,
        interactionRules: SlimeInteractionRules
    ) -> TrackpadGestureEvaluation {
        let waxRules = interactionRules.effectiveWaxInteraction
        let hasRequiredContacts = fingerCount == waxRules.minimumContactCount
        let closingSpeed = previousFingerCount == waxRules.minimumContactCount
            ? max(0, previousSpread - spread)
            : 0
        let deformationSignal = (
            movement * 0.52
                + min(1, closingSpeed * 2.4) * 0.34
                + (1.0 - spread) * 0.14
        ).clamped(to: 0.0...1.0)
        let waxSignal = max(pressure, deformationSignal)
        let contactFactor = hasRequiredContacts ? 1.0 : 0.0
        let liveIntensity = (
            contactFactor * 0.18 + waxSignal * 0.82
        ).clamped(to: 0.0...1.0)
        let pressureJump = previousFingerCount == waxRules.minimumContactCount
            ? max(pressure - previousPressure, waxSignal - previousWaxSignal)
            : 0

        defer {
            previousFingerCount = fingerCount
            previousPressure = pressure
            previousSpread = spread
            previousWaxSignal = waxSignal
        }

        guard hasRequiredContacts else {
            if fingerCount == 0, pressure <= 0.05 {
                waxStage = .idle
            }
            return TrackpadGestureEvaluation(liveIntensity: liveIntensity, trigger: nil)
        }

        let nextStage: WaxStage
        if waxSignal >= waxRules.crushPressureThreshold
            || pressureJump >= waxRules.crushPressureJumpThreshold
            || (
                closingSpeed >= waxRules.crushClosingThreshold
                    && pressure >= waxRules.crackPressureThreshold
            ) {
            nextStage = .crush
        } else if waxSignal >= waxRules.crackPressureThreshold
            || movement >= waxRules.crackMovementThreshold
            || closingSpeed >= waxRules.crackClosingThreshold {
            nextStage = .crack
        } else if waxSignal >= waxRules.pressPressureThreshold {
            nextStage = .press
        } else {
            return TrackpadGestureEvaluation(liveIntensity: liveIntensity, trigger: nil)
        }

        if nextStage == .crack, waxStage == .crack {
            let repeatedCrackImpulse = max(
                max(pressureJump, closingSpeed),
                abs(waxSignal - previousWaxSignal)
            )
            guard repeatedCrackImpulse >= waxRules.repeatedCrackImpulseThreshold else {
                return TrackpadGestureEvaluation(liveIntensity: liveIntensity, trigger: nil)
            }
            return triggerIfReady(
                kind: .waxCrack,
                intensity: liveIntensity,
                label: "Wax micro-crack",
                liveIntensity: liveIntensity,
                timestamp: timestamp,
                interval: densityAdjusted(
                    waxRules.repeatedCrackCooldown,
                    soundDensity: soundDensity
                ),
                soundPackIDOverride: waxRules.crackSoundPackID,
                volumeScale: interactionRules.effectiveVolumeScale
            )
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
            interval: densityAdjusted(baseInterval, soundDensity: soundDensity),
            soundPackIDOverride: waxRules.soundPackID(for: kind),
            volumeScale: interactionRules.effectiveVolumeScale
        )
    }

    private func triggerIfReady(
        kind: TrackpadSoundKind,
        intensity: Double,
        label: String,
        liveIntensity: Double,
        timestamp: TimeInterval,
        interval: TimeInterval,
        soundPackIDOverride: String? = nil,
        volumeScale: Double = 1.0
    ) -> TrackpadGestureEvaluation {
        let lastTriggerTime = lastTriggerTimes[kind] ?? -Double.infinity
        guard timestamp - lastTriggerTime >= interval,
              timestamp - lastInteractionTriggerTime >= activeMinimumSoundInterval else {
            return TrackpadGestureEvaluation(liveIntensity: liveIntensity, trigger: nil)
        }

        lastTriggerTimes[kind] = timestamp
        lastInteractionTriggerTime = timestamp
        return TrackpadGestureEvaluation(
            liveIntensity: liveIntensity,
            trigger: TrackpadGestureTrigger(
                kind: kind,
                intensity: intensity,
                label: label,
                soundPackIDOverride: soundPackIDOverride,
                volumeScale: volumeScale
            )
        )
    }

    private func resetSlimeBubble() {
        slimeBubbleArmTime = nil
        slimeBubbleMaximumSpread = 0
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
