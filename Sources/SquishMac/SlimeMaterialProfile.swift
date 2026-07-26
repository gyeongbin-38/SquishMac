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
            return .standard
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

    static let pastelClayVideo4 = CameraGestureTuning(
        response: 0.910788,
        soundDensity: 1.123549,
        minimumFingertipCount: 3,
        kneadMovementThreshold: 0.097359,
        stretchMovementThreshold: 0.243057,
        stretchSpreadThreshold: 0.399264,
        pressPressureThreshold: 0.285815,
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

    static let pastelClayVideo4 = SlimeInteractionRules(
        style: .densePutty,
        minimumFingerCount: 3,
        stretchMovementThreshold: 0.18,
        kneadSoundPackID: "pastel-clay-video-4-knead",
        stretchSoundPackID: "pastel-clay-video-4-stretch",
        interactionSummary: "Use small controlled pulls, pinches, folds, and presses. Bar-pung is disabled for this material."
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
    let bubbleGesture: TrackpadBubbleGestureRules?
    let volumeScale: Double?
    let interactionSummary: String

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
        bubbleGesture: TrackpadBubbleGestureRules? = nil,
        volumeScale: Double = 1.0,
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
        self.bubbleGesture = bubbleGesture
        self.volumeScale = volumeScale.clamped(to: 0.1...1.0)
        self.interactionSummary = interactionSummary
    }

    var effectiveVolumeScale: Double {
        (volumeScale ?? 1.0).clamped(to: 0.1...1.0)
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

    static var runtimeSlimeProfiles: [SlimeMaterialProfile] {
        builtIn.filter { $0.category != .waxShell }
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
            "pastel-clay-video-4",
            "Pastel Clay Slime (Video 4)",
            .butterClay,
            outer: "pastel green, white, and lavender matte folds",
            core: "dense clay-rich slime with short elastic pulls and soft folds",
            notes: "Video 4 reference. Product name is not yet confirmed, and bar-pung is disabled.",
            interactionRules: .pastelClayVideo4,
            trackpadTuning: TrackpadTuning(response: 0.90, soundDensity: 0.92),
            cameraTuning: .pastelClayVideo4
        ),
        profile("butter-clay", "Butter / Clay Slime", .butterClay, core: "soft matte clay slime"),
        profile("cloud", "Cloud Slime", .cloud, core: "fluffy drizzling cloud slime"),
        profile("jelly", "Jelly Slime", .jelly, core: "wet jelly-textured slime"),
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
