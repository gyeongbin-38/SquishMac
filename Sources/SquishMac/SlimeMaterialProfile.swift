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

    let style: SlimeInteractionStyle
    let minimumFingerCount: Int
    let stretchMovementThreshold: Double
    let fastStretchFailureMovementThreshold: Double?
    let fastStretchFailureResetThreshold: Double
    let fastStretchFailureCooldown: TimeInterval
    let failureSoundPackID: String?
    let failureGestureLabel: String
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
        self.interactionSummary = interactionSummary
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

    init(
        id: String,
        displayName: String,
        category: SlimeMaterialCategory,
        outerTexture: String,
        coreTexture: String,
        notes: String,
        isBuiltIn: Bool,
        interactionRules: SlimeInteractionRules? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.category = category
        self.outerTexture = outerTexture
        self.coreTexture = coreTexture
        self.notes = notes
        self.isBuiltIn = isBuiltIn
        self.interactionRules = interactionRules
    }

    var referenceMode: ReferenceMaterialMode {
        category.referenceMode
    }

    var effectiveInteractionRules: SlimeInteractionRules {
        interactionRules ?? category.defaultInteractionRules
    }

    static let defaultSlimeProfileID = "doctor-putty-pink"

    static var runtimeSlimeProfiles: [SlimeMaterialProfile] {
        builtIn.filter { $0.category != .waxShell }
    }

    static let builtIn: [SlimeMaterialProfile] = [
        profile("clear", "Clear Slime", .clear, core: "clear elastic gel"),
        profile("thick-glossy", "Thick & Glossy Slime", .thickGlossy, core: "dense glossy slime"),
        profile(
            "doctor-putty-pink",
            "Doctor Putty (Pastel Pink)",
            .butterClay,
            core: "dense stretchy low-gloss putty",
            notes: "Video 2 reference. Fast stretching causes a material-specific failure snap.",
            interactionRules: .doctorPutty
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
        interactionRules: SlimeInteractionRules? = nil
    ) -> SlimeMaterialProfile {
        SlimeMaterialProfile(
            id: id,
            displayName: displayName,
            category: category,
            outerTexture: outer,
            coreTexture: core,
            notes: notes,
            isBuiltIn: true,
            interactionRules: interactionRules
        )
    }
}
