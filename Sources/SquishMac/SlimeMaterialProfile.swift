import Foundation

enum SlimeMaterialCategory: String, CaseIterable, Identifiable, Codable {
    case clear
    case thickGlossy
    case butterClay
    case cloud
    case jelly
    case icee
    case floam
    case crunchy
    case waxShell
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clear:
            return "Clear Slime"
        case .thickGlossy:
            return "Thick & Glossy"
        case .butterClay:
            return "Butter / Clay"
        case .cloud:
            return "Cloud Slime"
        case .jelly:
            return "Jelly Slime"
        case .icee:
            return "Icee Slime"
        case .floam:
            return "Floam / Bead"
        case .crunchy:
            return "Crunchy Slime"
        case .waxShell:
            return "Wax Shell Slime"
        case .other:
            return "Other"
        }
    }

    var referenceMode: ReferenceMaterialMode {
        self == .waxShell ? .wax : .slime
    }

    var defaultInteractionRules: SlimeInteractionRules {
        switch self {
        case .butterClay:
            return SlimeInteractionRules(
                style: .densePutty,
                minimumFingerCount: 3,
                stretchMovementThreshold: 0.18,
                interactionSummary: "Knead with steady pressure and stretch at a controlled speed."
            )
        case .cloud:
            return SlimeInteractionRules(
                style: .softDrizzle,
                minimumFingerCount: 3,
                stretchMovementThreshold: 0.14,
                interactionSummary: "Use broad, slow pulls and light pressure."
            )
        case .floam, .crunchy:
            return SlimeInteractionRules(
                style: .textured,
                minimumFingerCount: 3,
                stretchMovementThreshold: 0.20,
                interactionSummary: "Press and fold to emphasize the textured inclusions."
            )
        case .waxShell:
            return .waxStandard
        case .clear, .thickGlossy, .jelly, .icee, .other:
            return .standard
        }
    }
}

enum SlimeInteractionStyle: String, Codable, Hashable {
    case elastic
    case densePutty
    case softDrizzle
    case textured
}

struct CameraBubbleGestureTuning: Codable, Equatable, Hashable {
    let minimumHandCount: Int
    let minimumFingertipCount: Int
    let armSpreadThreshold: Double
    let minimumSealMovement: Double
    let minimumDownwardTravel: Double
    let minimumRetainedSpreadRatio: Double
    let maximumDuration: TimeInterval
    let cooldown: TimeInterval

    init(
        minimumHandCount: Int = 2,
        minimumFingertipCount: Int = 8,
        armSpreadThreshold: Double = 0.46,
        minimumSealMovement: Double = 0.12,
        minimumDownwardTravel: Double = 0.055,
        minimumRetainedSpreadRatio: Double = 0.72,
        maximumDuration: TimeInterval = 1.40,
        cooldown: TimeInterval = 1.20
    ) {
        self.minimumHandCount = max(1, minimumHandCount)
        self.minimumFingertipCount = max(2, minimumFingertipCount)
        self.armSpreadThreshold = armSpreadThreshold.clamped(to: 0.05...1.0)
        self.minimumSealMovement = minimumSealMovement.clamped(to: 0.01...1.0)
        self.minimumDownwardTravel = minimumDownwardTravel.clamped(to: 0.01...1.0)
        self.minimumRetainedSpreadRatio = minimumRetainedSpreadRatio.clamped(to: 0.25...1.0)
        self.maximumDuration = max(0.25, maximumDuration)
        self.cooldown = max(0.25, cooldown)
    }
}

struct CameraGestureTuning: Codable, Equatable, Hashable {
    static let standard = CameraGestureTuning(
        response: 1.0,
        soundDensity: 1.0,
        minimumFingertipCount: 3,
        kneadMovementThreshold: 0.08,
        stretchMovementThreshold: 0.24,
        stretchSpreadThreshold: 0.34,
        pressPressureThreshold: 0.28,
        bubbleGesture: nil
    )

    static let clearVideo3 = CameraGestureTuning(
        response: 0.95,
        soundDensity: 1.07,
        minimumFingertipCount: 3,
        kneadMovementThreshold: 0.075,
        stretchMovementThreshold: 0.21,
        stretchSpreadThreshold: 0.30,
        pressPressureThreshold: 0.32,
        bubbleGesture: CameraBubbleGestureTuning()
    )

    static let pastelWaxVideo4 = CameraGestureTuning(
        response: 1.08,
        soundDensity: 1.18,
        minimumFingertipCount: 2,
        kneadMovementThreshold: 0.097359,
        stretchMovementThreshold: 0.243057,
        stretchSpreadThreshold: 0.399264,
        pressPressureThreshold: 0.18,
        bubbleGesture: nil
    )

    static let whitePuttyVideo5 = CameraGestureTuning(
        response: 0.92,
        soundDensity: 0.88,
        minimumFingertipCount: 3,
        kneadMovementThreshold: 0.12,
        stretchMovementThreshold: 0.32,
        stretchSpreadThreshold: 0.409636,
        pressPressureThreshold: 0.388291,
        bubbleGesture: nil
    )

    static let denseWhiteClayVideo7 = CameraGestureTuning(
        response: 1.0,
        soundDensity: 0.86,
        minimumFingertipCount: 2,
        kneadMovementThreshold: 0.10,
        stretchMovementThreshold: 0.30,
        stretchSpreadThreshold: 0.48,
        pressPressureThreshold: 0.30,
        bubbleGesture: nil
    )

    static let pinkGummyJellyVideo8 = CameraGestureTuning(
        response: 0.91,
        soundDensity: 0.94,
        minimumFingertipCount: 2,
        kneadMovementThreshold: 0.073017,
        stretchMovementThreshold: 0.190874,
        stretchSpreadThreshold: 0.307321,
        pressPressureThreshold: 0.371956,
        bubbleGesture: nil
    )

    static let aeratedClearVideo6 = CameraGestureTuning(
        response: 0.89,
        soundDensity: 0.95,
        minimumFingertipCount: 2,
        kneadMovementThreshold: 0.063439,
        stretchMovementThreshold: 0.223858,
        stretchSpreadThreshold: 0.262545,
        pressPressureThreshold: 0.350311,
        bubbleGesture: nil
    )

    static let whitePokePuttyVideo9 = CameraGestureTuning(
        response: 0.89,
        soundDensity: 1.08,
        minimumFingertipCount: 2,
        kneadMovementThreshold: 0.12,
        stretchMovementThreshold: 0.32,
        stretchSpreadThreshold: 0.42,
        pressPressureThreshold: 0.46,
        bubbleGesture: nil
    )

    static let orangeGlossyVideo10 = CameraGestureTuning(
        response: 0.95,
        soundDensity: 1.04,
        minimumFingertipCount: 2,
        kneadMovementThreshold: 0.062054,
        stretchMovementThreshold: 0.203659,
        stretchSpreadThreshold: 0.370280,
        pressPressureThreshold: 0.26,
        bubbleGesture: nil
    )

    static let greenMicroBeadVideo11 = CameraGestureTuning(
        response: 0.89,
        soundDensity: 1.12,
        minimumFingertipCount: 2,
        kneadMovementThreshold: 0.12,
        stretchMovementThreshold: 0.309732,
        stretchSpreadThreshold: 0.345576,
        pressPressureThreshold: 0.46,
        bubbleGesture: nil
    )

    let response: Double
    let soundDensity: Double
    let minimumFingertipCount: Int
    let kneadMovementThreshold: Double
    let stretchMovementThreshold: Double
    let stretchSpreadThreshold: Double
    let pressPressureThreshold: Double
    let bubbleGesture: CameraBubbleGestureTuning?

    init(
        response: Double,
        soundDensity: Double,
        minimumFingertipCount: Int,
        kneadMovementThreshold: Double,
        stretchMovementThreshold: Double,
        stretchSpreadThreshold: Double,
        pressPressureThreshold: Double,
        bubbleGesture: CameraBubbleGestureTuning? = nil
    ) {
        self.response = min(max(response, 0.5), 1.75)
        self.soundDensity = min(max(soundDensity, 0.5), 2.0)
        self.minimumFingertipCount = max(1, minimumFingertipCount)
        let safeKneadThreshold = min(max(kneadMovementThreshold, 0.01), 1)
        self.kneadMovementThreshold = safeKneadThreshold
        self.stretchMovementThreshold = min(
            max(stretchMovementThreshold, safeKneadThreshold),
            1
        )
        self.stretchSpreadThreshold = min(max(stretchSpreadThreshold, 0.01), 1)
        self.pressPressureThreshold = min(max(pressPressureThreshold, 0.01), 1)
        self.bubbleGesture = bubbleGesture
    }
}

struct TrackpadBubbleGestureRules: Codable, Equatable, Hashable {
    let minimumFingerCount: Int
    let armSpreadThreshold: Double
    let minimumSealMovement: Double
    let minimumSealPressure: Double
    let minimumSpreadDrop: Double
    let maximumDuration: TimeInterval
    let cooldown: TimeInterval
    let soundPackID: String?
    let gestureLabel: String

    private enum CodingKeys: String, CodingKey {
        case minimumFingerCount
        case armSpreadThreshold
        case minimumSealMovement
        case minimumSealPressure
        case minimumSpreadDrop
        case maximumDuration
        case cooldown
        case soundPackID = "soundPackId"
        case gestureLabel
    }

    init(
        minimumFingerCount: Int = 5,
        armSpreadThreshold: Double = 0.60,
        minimumSealMovement: Double = 0.10,
        minimumSealPressure: Double = 0.30,
        minimumSpreadDrop: Double = 0.16,
        maximumDuration: TimeInterval = 1.25,
        cooldown: TimeInterval = 1.20,
        soundPackID: String? = nil,
        gestureLabel: String = "Bar-pung seal"
    ) {
        self.minimumFingerCount = max(2, minimumFingerCount)
        self.armSpreadThreshold = armSpreadThreshold.clamped(to: 0.05...1.0)
        self.minimumSealMovement = minimumSealMovement.clamped(to: 0.01...1.0)
        self.minimumSealPressure = minimumSealPressure.clamped(to: 0.01...1.0)
        self.minimumSpreadDrop = minimumSpreadDrop.clamped(to: 0.01...1.0)
        self.maximumDuration = max(0.25, maximumDuration)
        self.cooldown = max(0.25, cooldown)
        self.soundPackID = soundPackID
        self.gestureLabel = gestureLabel
    }
}

struct WaxInteractionRules: Codable, Equatable, Hashable {
    static let standard = WaxInteractionRules()

    static let pastelWaxVideo4 = WaxInteractionRules(
        minimumContactCount: 2,
        pressPressureThreshold: 0.18,
        crackPressureThreshold: 0.43,
        crushPressureThreshold: 0.74,
        crackMovementThreshold: 0.16,
        crackClosingThreshold: 0.06,
        crushClosingThreshold: 0.14,
        crackPressureJumpThreshold: 0.09,
        crushPressureJumpThreshold: 0.26,
        repeatedCrackImpulseThreshold: 0.08,
        repeatedCrackCooldown: 0.14,
        pressSoundPackID: "pastel-wax-video-4-press",
        crackSoundPackID: "pastel-wax-video-4-crack",
        crushSoundPackID: "pastel-wax-video-4-crush"
    )

    let minimumContactCount: Int
    let pressPressureThreshold: Double
    let crackPressureThreshold: Double
    let crushPressureThreshold: Double
    let crackMovementThreshold: Double
    let crackClosingThreshold: Double
    let crushClosingThreshold: Double
    let crackPressureJumpThreshold: Double
    let crushPressureJumpThreshold: Double
    let repeatedCrackImpulseThreshold: Double
    let repeatedCrackCooldown: TimeInterval
    let pressSoundPackID: String?
    let crackSoundPackID: String?
    let crushSoundPackID: String?

    private enum CodingKeys: String, CodingKey {
        case minimumContactCount
        case pressPressureThreshold
        case crackPressureThreshold
        case crushPressureThreshold
        case crackMovementThreshold
        case crackClosingThreshold
        case crushClosingThreshold
        case crackPressureJumpThreshold
        case crushPressureJumpThreshold
        case repeatedCrackImpulseThreshold
        case repeatedCrackCooldown
        case pressSoundPackID = "pressSoundPackId"
        case crackSoundPackID = "crackSoundPackId"
        case crushSoundPackID = "crushSoundPackId"
    }

    init(
        minimumContactCount: Int = 2,
        pressPressureThreshold: Double = 0.30,
        crackPressureThreshold: Double = 0.55,
        crushPressureThreshold: Double = 0.78,
        crackMovementThreshold: Double = 0.28,
        crackClosingThreshold: Double = 0.10,
        crushClosingThreshold: Double = 0.20,
        crackPressureJumpThreshold: Double = 0.12,
        crushPressureJumpThreshold: Double = 0.35,
        repeatedCrackImpulseThreshold: Double = 0.10,
        repeatedCrackCooldown: TimeInterval = 0.16,
        pressSoundPackID: String? = nil,
        crackSoundPackID: String? = nil,
        crushSoundPackID: String? = nil
    ) {
        let safePress = pressPressureThreshold.clamped(to: 0.01...0.90)
        let safeCrack = crackPressureThreshold.clamped(to: safePress...0.95)
        self.minimumContactCount = max(2, minimumContactCount)
        self.pressPressureThreshold = safePress
        self.crackPressureThreshold = safeCrack
        self.crushPressureThreshold = crushPressureThreshold.clamped(
            to: safeCrack...1.0
        )
        self.crackMovementThreshold = crackMovementThreshold.clamped(to: 0.01...1.0)
        self.crackClosingThreshold = crackClosingThreshold.clamped(to: 0.01...1.0)
        self.crushClosingThreshold = max(
            self.crackClosingThreshold,
            crushClosingThreshold.clamped(to: 0.01...1.0)
        )
        self.crackPressureJumpThreshold = crackPressureJumpThreshold.clamped(
            to: 0.01...1.0
        )
        self.crushPressureJumpThreshold = max(
            self.crackPressureJumpThreshold,
            crushPressureJumpThreshold.clamped(to: 0.01...1.0)
        )
        self.repeatedCrackImpulseThreshold = repeatedCrackImpulseThreshold.clamped(
            to: 0.01...1.0
        )
        self.repeatedCrackCooldown = max(0.08, repeatedCrackCooldown)
        self.pressSoundPackID = pressSoundPackID
        self.crackSoundPackID = crackSoundPackID
        self.crushSoundPackID = crushSoundPackID
    }

    func soundPackID(for kind: TrackpadSoundKind) -> String? {
        switch kind {
        case .waxPress:
            return pressSoundPackID
        case .waxCrack:
            return crackSoundPackID
        case .waxCrush:
            return crushSoundPackID
        case .slimeKnead, .slimeStretch, .slimeBubble,
             .slimeStretchFailure, .slimeRelease:
            return nil
        }
    }
}

struct InteractionSoundLayerPlan: Equatable {
    let soundPackID: String
    let volumeScale: Double
    let delayMilliseconds: Double
    let rateOffset: Double
}

struct InteractionSoundLayerRules: Codable, Equatable, Hashable {
    let soundPackID: String
    let minimumIntensity: Double
    let probabilityAtMinimum: Double
    let probabilityAtMaximum: Double
    let volumeScaleAtMinimum: Double
    let volumeScaleAtMaximum: Double
    let minimumDelayMilliseconds: Double
    let maximumDelayMilliseconds: Double
    let rateOffset: Double

    init(
        soundPackID: String,
        minimumIntensity: Double,
        probabilityAtMinimum: Double,
        probabilityAtMaximum: Double,
        volumeScaleAtMinimum: Double,
        volumeScaleAtMaximum: Double,
        minimumDelayMilliseconds: Double,
        maximumDelayMilliseconds: Double,
        rateOffset: Double = 0
    ) {
        self.soundPackID = soundPackID
        self.minimumIntensity = minimumIntensity.clamped(to: 0.0...1.0)
        self.probabilityAtMinimum = probabilityAtMinimum.clamped(to: 0.0...1.0)
        self.probabilityAtMaximum = probabilityAtMaximum.clamped(to: 0.0...1.0)
        self.volumeScaleAtMinimum = volumeScaleAtMinimum.clamped(to: 0.0...1.0)
        self.volumeScaleAtMaximum = volumeScaleAtMaximum.clamped(to: 0.0...1.0)
        let minimumDelay = minimumDelayMilliseconds.clamped(to: 0.0...120.0)
        self.minimumDelayMilliseconds = minimumDelay
        self.maximumDelayMilliseconds = maximumDelayMilliseconds.clamped(
            to: minimumDelay...120.0
        )
        self.rateOffset = rateOffset.clamped(to: -0.25...0.25)
    }

    func plan(
        intensity: Double,
        probabilitySample: Double,
        delaySample: Double
    ) -> InteractionSoundLayerPlan? {
        let safeIntensity = intensity.clamped(to: 0.0...1.0)
        guard safeIntensity >= minimumIntensity else {
            return nil
        }

        let progress = ((safeIntensity - minimumIntensity) / max(0.001, 1 - minimumIntensity))
            .clamped(to: 0.0...1.0)
        let probability = probabilityAtMinimum
            + (probabilityAtMaximum - probabilityAtMinimum) * progress
        guard probabilitySample.clamped(to: 0.0...1.0) <= probability else {
            return nil
        }

        return InteractionSoundLayerPlan(
            soundPackID: soundPackID,
            volumeScale: volumeScaleAtMinimum
                + (volumeScaleAtMaximum - volumeScaleAtMinimum) * progress,
            delayMilliseconds: minimumDelayMilliseconds
                + (maximumDelayMilliseconds - minimumDelayMilliseconds)
                    * delaySample.clamped(to: 0.0...1.0),
            rateOffset: rateOffset
        )
    }
}

struct SlimeInteractionRules: Codable, Equatable, Hashable {
    static let standard = SlimeInteractionRules(
        style: .elastic,
        minimumFingerCount: 3,
        stretchMovementThreshold: 0.16,
        interactionSummary: "Knead, press, and stretch with three to six fingers."
    )

    static let doctorPutty = SlimeInteractionRules(
        style: .densePutty,
        minimumFingerCount: 3,
        stretchMovementThreshold: 0.16,
        fastStretchFailureMovementThreshold: 0.72,
        fastStretchFailureResetThreshold: 0.38,
        fastStretchFailureCooldown: 0.90,
        failureSoundPackID: "doctor-putty-failure",
        failureGestureLabel: "Doctor Putty snapped: stretch too fast",
        interactionSummary: "Stretch slowly. Pulling too fast breaks the putty and plays a failure snap."
    )

    static let clearVideo3 = SlimeInteractionRules(
        style: .elastic,
        minimumFingerCount: 3,
        stretchMovementThreshold: 0.14,
        kneadSoundPackID: "clear-video-3-knead",
        stretchSoundPackID: "clear-video-3-stretch",
        bubbleGesture: TrackpadBubbleGestureRules(
            soundPackID: "clear-video-3-stretch"
        ),
        volumeScale: 0.86,
        interactionSummary: "Press with three to six fingers, stretch broadly, then close and press to seal a bar-pung."
    )

    static let waxStandard = SlimeInteractionRules(
        style: .densePutty,
        minimumFingerCount: 2,
        stretchMovementThreshold: 0.18,
        waxInteraction: .standard,
        interactionSummary: "Press inward with two opposing contacts, then increase pressure to crack and crush the wax shell."
    )

    static let pastelWaxVideo4 = SlimeInteractionRules(
        style: .densePutty,
        minimumFingerCount: 2,
        stretchMovementThreshold: 0.18,
        waxInteraction: .pastelWaxVideo4,
        volumeScale: 0.92,
        interactionSummary: "Use two opposing contacts. A light hold presses the shell, rising pressure makes repeated fine cracks, and a firm inward squeeze crushes it."
    )

    static let whitePuttyVideo5 = SlimeInteractionRules(
        style: .densePutty,
        minimumFingerCount: 3,
        stretchMovementThreshold: 0.20,
        kneadSoundPackID: "white-putty-video-5-knead",
        stretchSoundPackID: "white-putty-video-5-stretch",
        releaseSoundPackID: "white-putty-video-5-stretch",
        volumeScale: 0.68,
        minimumSoundInterval: 0.38,
        interactionSummary: "Use compact pinches, controlled short pulls, folds, and firm thumb-like presses. Bar-pung is disabled for this dense putty."
    )

    static let denseWhiteClayVideo7 = SlimeInteractionRules(
        style: .densePutty,
        minimumFingerCount: 2,
        stretchMovementThreshold: 0.16,
        kneadSoundPackID: "dense-white-clay-video-7-knead",
        stretchSoundPackID: "dense-white-clay-video-7-stretch",
        releaseSoundPackID: "dense-white-clay-video-7-stretch",
        volumeScale: 0.66,
        minimumSoundInterval: 0.32,
        interactionSummary: "Press inward with two opposing contacts, make short controlled pulls with four or more contacts, and fold the dense clay slowly. Bar-pung is disabled because the reference does not form a sheet."
    )

    static let pinkGummyJellyVideo8 = SlimeInteractionRules(
        style: .elastic,
        minimumFingerCount: 2,
        stretchMovementThreshold: 0.14,
        kneadSoundPackID: "pink-gummy-jelly-video-8-knead",
        stretchSoundPackID: "pink-gummy-jelly-video-8-stretch",
        releaseSoundPackID: "pink-gummy-jelly-video-8-stretch",
        volumeScale: 0.68,
        minimumSoundInterval: 0.30,
        interactionSummary: "Pinch and pop the sticky jelly with two or more contacts, then use four or more contacts for controlled long or short pulls, twists, and folds. Bar-pung is disabled because the reference does not inflate one."
    )

    static let aeratedClearVideo6 = SlimeInteractionRules(
        style: .elastic,
        minimumFingerCount: 2,
        stretchMovementThreshold: 0.14,
        kneadSoundPackID: "aerated-clear-video-6-knead",
        stretchSoundPackID: "aerated-clear-video-6-stretch",
        releaseSoundPackID: "aerated-clear-video-6-stretch",
        volumeScale: 0.72,
        minimumSoundInterval: 0.24,
        interactionSummary: "Poke trapped bubbles with two or more contacts, press and fold the aerated gel, and pull broadly to form a thin clear membrane. Bar-pung is disabled because the reference does not inflate one."
    )

    static let whitePokePuttyVideo9 = SlimeInteractionRules(
        style: .densePutty,
        minimumFingerCount: 2,
        stretchMovementThreshold: 0.18,
        kneadSoundPackID: "white-poke-putty-video-9-body",
        stretchSoundPackID: "white-poke-putty-video-9-texture",
        releaseSoundPackID: "white-poke-putty-video-9-texture",
        kneadSecondarySoundLayer: InteractionSoundLayerRules(
            soundPackID: "white-poke-putty-video-9-texture",
            minimumIntensity: 0.28,
            probabilityAtMinimum: 0.16,
            probabilityAtMaximum: 0.72,
            volumeScaleAtMinimum: 0.18,
            volumeScaleAtMaximum: 0.42,
            minimumDelayMilliseconds: 9,
            maximumDelayMilliseconds: 30,
            rateOffset: 0.015
        ),
        stretchSecondarySoundLayer: InteractionSoundLayerRules(
            soundPackID: "white-poke-putty-video-9-body",
            minimumIntensity: 0.34,
            probabilityAtMinimum: 0.12,
            probabilityAtMaximum: 0.46,
            volumeScaleAtMinimum: 0.14,
            volumeScaleAtMaximum: 0.30,
            minimumDelayMilliseconds: 14,
            maximumDelayMilliseconds: 38,
            rateOffset: -0.02
        ),
        volumeScale: 0.66,
        minimumSoundInterval: 0.28,
        interactionSummary: "Use two to six contacts for deep pokes, broad presses, short folds, and controlled pulls. Stronger pressure adds same-material clay snaps and suction detail."
    )

    static let orangeGlossyVideo10 = SlimeInteractionRules(
        style: .elastic,
        minimumFingerCount: 2,
        stretchMovementThreshold: 0.16,
        kneadSoundPackID: "orange-glossy-video-10-pop",
        stretchSoundPackID: "orange-glossy-video-10-pop",
        releaseSoundPackID: "orange-glossy-video-10-snap",
        kneadSecondarySoundLayer: InteractionSoundLayerRules(
            soundPackID: "orange-glossy-video-10-snap",
            minimumIntensity: 0.42,
            probabilityAtMinimum: 0.10,
            probabilityAtMaximum: 0.58,
            volumeScaleAtMinimum: 0.16,
            volumeScaleAtMaximum: 0.34,
            minimumDelayMilliseconds: 7,
            maximumDelayMilliseconds: 24,
            rateOffset: -0.01
        ),
        stretchSecondarySoundLayer: InteractionSoundLayerRules(
            soundPackID: "orange-glossy-video-10-snap",
            minimumIntensity: 0.48,
            probabilityAtMinimum: 0.12,
            probabilityAtMaximum: 0.52,
            volumeScaleAtMinimum: 0.16,
            volumeScaleAtMaximum: 0.32,
            minimumDelayMilliseconds: 10,
            maximumDelayMilliseconds: 28,
            rateOffset: -0.015
        ),
        volumeScale: 0.64,
        minimumSoundInterval: 0.26,
        interactionSummary: "Fold and squeeze with two or more contacts, then make repeated fingertip pokes. Firm pressure adds an occasional same-material glossy snap."
    )

    static let greenMicroBeadVideo11 = SlimeInteractionRules(
        style: .textured,
        minimumFingerCount: 2,
        stretchMovementThreshold: 0.16,
        kneadSoundPackID: "green-micro-bead-video-11-body",
        stretchSoundPackID: "green-micro-bead-video-11-pop",
        releaseSoundPackID: "green-micro-bead-video-11-pop",
        kneadSecondarySoundLayer: InteractionSoundLayerRules(
            soundPackID: "green-micro-bead-video-11-pop",
            minimumIntensity: 0.24,
            probabilityAtMinimum: 0.18,
            probabilityAtMaximum: 0.76,
            volumeScaleAtMinimum: 0.16,
            volumeScaleAtMaximum: 0.38,
            minimumDelayMilliseconds: 6,
            maximumDelayMilliseconds: 22,
            rateOffset: 0.025
        ),
        stretchSecondarySoundLayer: InteractionSoundLayerRules(
            soundPackID: "green-micro-bead-video-11-body",
            minimumIntensity: 0.32,
            probabilityAtMinimum: 0.10,
            probabilityAtMaximum: 0.40,
            volumeScaleAtMinimum: 0.12,
            volumeScaleAtMaximum: 0.26,
            minimumDelayMilliseconds: 12,
            maximumDelayMilliseconds: 34,
            rateOffset: -0.02
        ),
        volumeScale: 0.62,
        minimumSoundInterval: 0.24,
        interactionSummary: "Use precise two-contact pinches and short presses for the small bead slime. Higher pressure adds compact bead pops without turning into a broad impact sound."
    )

    let style: SlimeInteractionStyle
    let minimumFingerCount: Int
    let stretchMovementThreshold: Double
    let fastStretchFailureMovementThreshold: Double?
    let fastStretchFailureResetThreshold: Double
    let fastStretchFailureCooldown: TimeInterval
    let failureSoundPackID: String?
    let failureGestureLabel: String
    let kneadSoundPackID: String?
    let stretchSoundPackID: String?
    let releaseSoundPackID: String?
    let kneadSecondarySoundLayer: InteractionSoundLayerRules?
    let stretchSecondarySoundLayer: InteractionSoundLayerRules?
    let releaseSecondarySoundLayer: InteractionSoundLayerRules?
    let bubbleGesture: TrackpadBubbleGestureRules?
    let waxInteraction: WaxInteractionRules?
    let volumeScale: Double?
    let minimumSoundInterval: TimeInterval?
    let interactionSummary: String

    private enum CodingKeys: String, CodingKey {
        case style
        case minimumFingerCount
        case stretchMovementThreshold
        case fastStretchFailureMovementThreshold
        case fastStretchFailureResetThreshold
        case fastStretchFailureCooldown
        case failureSoundPackID = "failureSoundPackId"
        case failureGestureLabel
        case kneadSoundPackID = "kneadSoundPackId"
        case stretchSoundPackID = "stretchSoundPackId"
        case releaseSoundPackID = "releaseSoundPackId"
        case kneadSecondarySoundLayer
        case stretchSecondarySoundLayer
        case releaseSecondarySoundLayer
        case bubbleGesture
        case waxInteraction
        case volumeScale
        case minimumSoundInterval
        case interactionSummary
    }

    init(
        style: SlimeInteractionStyle,
        minimumFingerCount: Int,
        stretchMovementThreshold: Double,
        fastStretchFailureMovementThreshold: Double? = nil,
        fastStretchFailureResetThreshold: Double = 0.38,
        fastStretchFailureCooldown: TimeInterval = 0.90,
        failureSoundPackID: String? = nil,
        failureGestureLabel: String = "Stretch too fast",
        kneadSoundPackID: String? = nil,
        stretchSoundPackID: String? = nil,
        releaseSoundPackID: String? = nil,
        kneadSecondarySoundLayer: InteractionSoundLayerRules? = nil,
        stretchSecondarySoundLayer: InteractionSoundLayerRules? = nil,
        releaseSecondarySoundLayer: InteractionSoundLayerRules? = nil,
        bubbleGesture: TrackpadBubbleGestureRules? = nil,
        waxInteraction: WaxInteractionRules? = nil,
        volumeScale: Double = 1.0,
        minimumSoundInterval: TimeInterval? = nil,
        interactionSummary: String
    ) {
        let safeStretchThreshold = min(max(stretchMovementThreshold, 0.01), 1)
        let safeFailureThreshold = fastStretchFailureMovementThreshold.map {
            min(max($0, safeStretchThreshold), 1)
        }
        self.style = style
        self.minimumFingerCount = max(1, minimumFingerCount)
        self.stretchMovementThreshold = safeStretchThreshold
        self.fastStretchFailureMovementThreshold = safeFailureThreshold
        self.fastStretchFailureResetThreshold = min(
            max(fastStretchFailureResetThreshold, 0),
            safeFailureThreshold ?? 1
        )
        self.fastStretchFailureCooldown = max(0.1, fastStretchFailureCooldown)
        self.failureSoundPackID = failureSoundPackID
        self.failureGestureLabel = failureGestureLabel
        self.kneadSoundPackID = kneadSoundPackID
        self.stretchSoundPackID = stretchSoundPackID
        self.releaseSoundPackID = releaseSoundPackID
        self.kneadSecondarySoundLayer = kneadSecondarySoundLayer
        self.stretchSecondarySoundLayer = stretchSecondarySoundLayer
        self.releaseSecondarySoundLayer = releaseSecondarySoundLayer
        self.bubbleGesture = bubbleGesture
        self.waxInteraction = waxInteraction
        self.volumeScale = volumeScale.clamped(to: 0.1...1.0)
        self.minimumSoundInterval = minimumSoundInterval.map {
            $0.clamped(to: 0.0...2.0)
        }
        self.interactionSummary = interactionSummary
    }

    var effectiveVolumeScale: Double {
        (volumeScale ?? 1.0).clamped(to: 0.1...1.0)
    }

    var effectiveMinimumSoundInterval: TimeInterval {
        (minimumSoundInterval ?? 0).clamped(to: 0.0...2.0)
    }

    var effectiveWaxInteraction: WaxInteractionRules {
        waxInteraction ?? .standard
    }

    func soundPackID(for kind: TrackpadSoundKind) -> String? {
        switch kind {
        case .slimeKnead:
            return kneadSoundPackID
        case .slimeStretch:
            return stretchSoundPackID
        case .slimeBubble:
            return bubbleGesture?.soundPackID
        case .slimeRelease:
            return releaseSoundPackID
        case .slimeStretchFailure:
            return failureSoundPackID
        case .waxPress, .waxCrack, .waxCrush:
            return effectiveWaxInteraction.soundPackID(for: kind)
        }
    }

    func secondarySoundLayer(for kind: TrackpadSoundKind) -> InteractionSoundLayerRules? {
        switch kind {
        case .slimeKnead:
            return kneadSecondarySoundLayer
        case .slimeStretch:
            return stretchSecondarySoundLayer
        case .slimeRelease:
            return releaseSecondarySoundLayer
        case .slimeBubble, .slimeStretchFailure, .waxPress, .waxCrack, .waxCrush:
            return nil
        }
    }
}

struct SlimeMaterialProfile: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let displayName: String
    let category: SlimeMaterialCategory
    let outerTexture: String
    let coreTexture: String
    let notes: String
    let isBuiltIn: Bool
    let interactionRules: SlimeInteractionRules?
    let trackpadTuning: TrackpadTuning?
    let cameraTuning: CameraGestureTuning?

    init(
        id: String,
        displayName: String,
        category: SlimeMaterialCategory,
        outerTexture: String,
        coreTexture: String,
        notes: String,
        isBuiltIn: Bool,
        interactionRules: SlimeInteractionRules? = nil,
        trackpadTuning: TrackpadTuning? = nil,
        cameraTuning: CameraGestureTuning? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.category = category
        self.outerTexture = outerTexture
        self.coreTexture = coreTexture
        self.notes = notes
        self.isBuiltIn = isBuiltIn
        self.interactionRules = interactionRules
        self.trackpadTuning = trackpadTuning
        self.cameraTuning = cameraTuning
    }

    var referenceMode: ReferenceMaterialMode {
        category.referenceMode
    }

    var effectiveInteractionRules: SlimeInteractionRules {
        interactionRules ?? category.defaultInteractionRules
    }

    var effectiveTrackpadTuning: TrackpadTuning {
        trackpadTuning ?? .standard
    }

    var effectiveCameraTuning: CameraGestureTuning {
        cameraTuning ?? .standard
    }

    static let defaultSlimeProfileID = "doctor-putty-pink"
    static let defaultWaxProfileID = "pastel-wax-shell-video-4"

    static var runtimeSlimeProfiles: [SlimeMaterialProfile] {
        builtIn.filter { $0.category != .waxShell }
    }

    static var runtimeWaxProfiles: [SlimeMaterialProfile] {
        builtIn.filter { $0.category == .waxShell }
    }

    static let builtIn: [SlimeMaterialProfile] = [
        profile("clear", "Clear Slime", .clear, core: "clear elastic gel"),
        profile(
            "clear-video-3",
            "Clear Slime (Video 3)",
            .clear,
            outer: "transparent glossy surface with trapped micro-bubbles",
            core: "clear elastic gel with wet folds and bubble pockets",
            notes: "Video 3 reference. Product name is not yet confirmed.",
            interactionRules: .clearVideo3,
            trackpadTuning: TrackpadTuning(response: 0.96, soundDensity: 1.08),
            cameraTuning: .clearVideo3
        ),
        profile(
            "aerated-clear-slime-video-6",
            "Aerated Clear Slime (Video 6)",
            .clear,
            outer: "transparent glossy surface densely filled with fine air bubbles",
            core: "elastic clear gel that forms thin membranes and aerated folds",
            notes: "Video 6 reference. Product name is not yet confirmed. One source-clipped transient was excluded, and no inflated bar-pung was observed.",
            interactionRules: .aeratedClearVideo6,
            trackpadTuning: TrackpadTuning(response: 0.96, soundDensity: 0.95),
            cameraTuning: .aeratedClearVideo6
        ),
        profile("thick-glossy", "Thick & Glossy Slime", .thickGlossy, core: "dense glossy slime"),
        profile(
            "doctor-putty-pink",
            "Doctor Putty (Pastel Pink)",
            .butterClay,
            core: "dense stretchy low-gloss putty",
            notes: "Video 2 reference. Fast stretching causes a material-specific failure snap.",
            interactionRules: .doctorPutty
        ),
        profile(
            "white-dense-putty-video-5",
            "White Dense Putty (Video 5)",
            .butterClay,
            outer: "white matte low-gloss surface",
            core: "dense smooth putty with short elastic pulls and compact folds",
            notes: "Video 5 reference. Product name is not yet confirmed, and no bar-pung motion was observed.",
            interactionRules: .whitePuttyVideo5,
            trackpadTuning: TrackpadTuning(response: 0.92, soundDensity: 0.88),
            cameraTuning: .whitePuttyVideo5
        ),
        profile(
            "dense-white-clay-slime-video-7",
            "Dense White Clay Slime (Video 7)",
            .butterClay,
            outer: "opaque white matte surface with a smooth compact body",
            core: "dense clay-like slime with deep presses, short pulls, and rounded folds",
            notes: "Video 7 reference. Product name is not yet confirmed, no inflated bar-pung was observed, and one low-confidence voice-like candidate was excluded.",
            interactionRules: .denseWhiteClayVideo7,
            trackpadTuning: TrackpadTuning(response: 1.0, soundDensity: 0.86),
            cameraTuning: .denseWhiteClayVideo7
        ),
        profile(
            "pastel-wax-shell-video-4",
            "Pastel Wax Shell Slime (Video 4)",
            .waxShell,
            outer: "pastel green and white brittle wax shell",
            core: "lavender elastic slime with soft folds and short pulls",
            notes: "Video 4 reference. The opening sequence is a two-contact wax-shell crush, followed by exposed slime-core handling.",
            interactionRules: .pastelWaxVideo4,
            trackpadTuning: TrackpadTuning(response: 1.08, soundDensity: 1.18),
            cameraTuning: .pastelWaxVideo4
        ),
        profile("butter-clay", "Butter / Clay Slime", .butterClay, core: "soft matte clay slime"),
        profile("cloud", "Cloud Slime", .cloud, core: "fluffy drizzling cloud slime"),
        profile("jelly", "Jelly Slime", .jelly, core: "wet jelly-textured slime"),
        profile(
            "pink-gummy-jelly-slime-video-8",
            "Pink Gummy Jelly Slime (Video 8)",
            .jelly,
            outer: "translucent pink glossy surface",
            core: "sticky elastic jelly with long strings, short pulls, twists, and compact folds",
            notes: "Video 8 reference. Product name is not yet confirmed, no inflated bar-pung was observed, and all accepted sounds align with visible jelly handling.",
            interactionRules: .pinkGummyJellyVideo8,
            trackpadTuning: TrackpadTuning(response: 0.96, soundDensity: 0.94),
            cameraTuning: .pinkGummyJellyVideo8
        ),
        profile(
            "white-poke-putty-video-9",
            "White Poke Putty (Video 9)",
            .butterClay,
            outer: "opaque white matte surface with a smooth dense skin",
            core: "dense putty with deep fingertip pockets, short folds, and suction recovery",
            notes: "Video 9 reference. Product name is not yet confirmed, and all accepted sounds align with visible material handling.",
            interactionRules: .whitePokePuttyVideo9,
            trackpadTuning: TrackpadTuning(response: 0.90, soundDensity: 0.92),
            cameraTuning: .whitePokePuttyVideo9
        ),
        profile(
            "orange-glossy-slime-video-10",
            "Orange Glossy Slime (Video 10)",
            .thickGlossy,
            outer: "opaque orange glossy surface with sparse dark inclusions",
            core: "dense glossy slime shaped by folds, squeezes, and repeated fingertip pokes",
            notes: "Video 10 reference. Product name is not yet confirmed, and all accepted sounds align with visible material handling.",
            interactionRules: .orangeGlossyVideo10,
            trackpadTuning: TrackpadTuning(response: 1.0, soundDensity: 1.0),
            cameraTuning: .orangeGlossyVideo10
        ),
        profile(
            "green-micro-bead-floam-video-11",
            "Green Micro-Bead Floam (Video 11)",
            .floam,
            outer: "small translucent green body with visible bead-like inclusions",
            core: "compact textured gel that responds to precise pinches and short presses",
            notes: "Video 11 reference. Product name is not yet confirmed. Classification was finalized as Floam / Bead after frame review.",
            interactionRules: .greenMicroBeadVideo11,
            trackpadTuning: TrackpadTuning(response: 1.0, soundDensity: 1.0),
            cameraTuning: .greenMicroBeadVideo11
        ),
        profile("icee", "Icee Slime", .icee, core: "snowy granular slime"),
        profile("floam", "Floam / Bead Slime", .floam, core: "slime with foam beads"),
        profile("crunchy", "Crunchy Slime", .crunchy, core: "crunchy inclusion slime"),
        profile(
            "wax-shell-dark-brown-yellow",
            "Dark Brown Wax Shell / Yellow Slime Core",
            .waxShell,
            outer: "dark-brown glossy brittle wax shell",
            core: "bright-yellow elastic sticky slime",
            notes: "Reference profile introduced with video 1."
        ),
        profile(
            "wax-shell",
            "Generic Wax Shell Slime",
            .waxShell,
            outer: "brittle wax shell",
            core: "elastic slime core"
        )
    ]

    private static func profile(
        _ id: String,
        _ displayName: String,
        _ category: SlimeMaterialCategory,
        outer: String = "",
        core: String,
        notes: String = "",
        interactionRules: SlimeInteractionRules? = nil,
        trackpadTuning: TrackpadTuning? = nil,
        cameraTuning: CameraGestureTuning? = nil
    ) -> SlimeMaterialProfile {
        SlimeMaterialProfile(
            id: id,
            displayName: displayName,
            category: category,
            outerTexture: outer,
            coreTexture: core,
            notes: notes,
            isBuiltIn: true,
            interactionRules: interactionRules,
            trackpadTuning: trackpadTuning,
            cameraTuning: cameraTuning
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
