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
}

struct SlimeMaterialProfile: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let displayName: String
    let category: SlimeMaterialCategory
    let outerTexture: String
    let coreTexture: String
    let notes: String
    let isBuiltIn: Bool

    var referenceMode: ReferenceMaterialMode {
        category.referenceMode
    }

    static let builtIn: [SlimeMaterialProfile] = [
        profile("clear", "Clear Slime", .clear, core: "clear elastic gel"),
        profile("thick-glossy", "Thick & Glossy Slime", .thickGlossy, core: "dense glossy slime"),
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
        notes: String = ""
    ) -> SlimeMaterialProfile {
        SlimeMaterialProfile(
            id: id,
            displayName: displayName,
            category: category,
            outerTexture: outer,
            coreTexture: core,
            notes: notes,
            isBuiltIn: true
        )
    }
}
