import Foundation

enum ReferenceMaterialMode: String, CaseIterable, Identifiable, Codable {
    case slime
    case wax

    var id: String { rawValue }

    var title: String {
        switch self {
        case .slime:
            return "Slime"
        case .wax:
            return "Wax Squish"
        }
    }
}

enum HandJointName: String, CaseIterable, Codable {
    case wrist
    case thumbTip
    case indexTip
    case middleTip
    case ringTip
    case littleTip

    var isFingertip: Bool {
        self != .wrist
    }
}

struct NormalizedPosePoint: Codable, Equatable {
    let x: Double
    let y: Double
    let confidence: Double

    init(x: Double, y: Double, confidence: Double) {
        self.x = x.clamped(to: 0.0...1.0)
        self.y = y.clamped(to: 0.0...1.0)
        self.confidence = confidence.clamped(to: 0.0...1.0)
    }
}

struct DetectedHandPose: Codable, Equatable {
    let id: Int
    let joints: [HandJointName: NormalizedPosePoint]
}

struct HandPoseSample: Codable, Equatable {
    let timestamp: TimeInterval
    let hands: [DetectedHandPose]
}

struct HandMotionFrame: Codable, Equatable {
    let timestamp: TimeInterval
    let handCount: Int
    let fingertipCount: Int
    let centroidX: Double
    let centroidY: Double
    let movement: Double
    let spread: Double
    let openness: Double
    let pinch: Double
    let pressureEstimate: Double
    let hands: [DetectedHandPose]
}

enum ReferenceAudioTexture: String, CaseIterable, Codable {
    case wetFriction
    case bubbleCluster
    case suctionPop
    case puttySoftCrackle
    case stretchTooFastFailure
    case softCompression
    case brittleCrack
    case crushBody
    case unknown
}

enum ReferenceGestureKind: String, CaseIterable, Codable {
    case slimePress
    case slimeKnead
    case slimeStretch
    case slimeStretchFailure
    case slimeRelease
    case waxPress
    case waxCrack
    case waxCrush

    var title: String {
        switch self {
        case .slimePress:
            return "Slime press"
        case .slimeKnead:
            return "Slime knead"
        case .slimeStretch:
            return "Slime stretch"
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

    var soundKind: TrackpadSoundKind {
        switch self {
        case .slimePress, .slimeKnead:
            return .slimeKnead
        case .slimeStretch:
            return .slimeStretch
        case .slimeStretchFailure:
            return .slimeStretchFailure
        case .slimeRelease:
            return .slimeRelease
        case .waxPress:
            return .waxPress
        case .waxCrack:
            return .waxCrack
        case .waxCrush:
            return .waxCrush
        }
    }
}

struct ReferenceAudioEvent: Codable, Equatable {
    let timestamp: TimeInterval
    let rms: Double
    let peak: Double
    let zeroCrossingRate: Double
    let crestFactor: Double
    let suggestedTexture: ReferenceAudioTexture
    let suggestedClipStart: TimeInterval
    let suggestedClipEnd: TimeInterval
}

struct ReferenceGestureEvent: Codable, Equatable {
    let timestamp: TimeInterval
    let kind: ReferenceGestureKind
    let intensity: Double
    let audioEventIndex: Int?
}

struct SoundParameterRange: Codable, Equatable {
    let minimum: Double
    let maximum: Double
}

struct SoundLayerRecipe: Codable, Equatable {
    let role: String
    let sourcePackID: String
    let probability: Double
    let volume: SoundParameterRange
    let playbackRate: SoundParameterRange
    let delayMilliseconds: SoundParameterRange
    let canBeSynthesizedWhenMissing: Bool

    private enum CodingKeys: String, CodingKey {
        case role
        case sourcePackID = "sourcePackId"
        case probability
        case volume
        case playbackRate
        case delayMilliseconds
        case canBeSynthesizedWhenMissing
    }
}

struct GestureSoundRecipe: Codable, Equatable {
    let gesture: ReferenceGestureKind
    let layers: [SoundLayerRecipe]
}

struct LearnedGestureProfile: Codable, Equatable {
    let movementMedian: Double
    let movementHigh: Double
    let pressureMedian: Double
    let pressureHigh: Double
    let spreadMedian: Double
    let suggestedResponse: Double
    let suggestedSoundDensity: Double
}

struct ReferenceVideoAnalysis: Codable, Equatable {
    let schemaVersion: Int
    let datasetID: String
    let sourceFileName: String
    let materialProfile: SlimeMaterialProfile
    let mode: ReferenceMaterialMode
    let duration: TimeInterval
    let analyzedFramesPerSecond: Double
    let motionFrames: [HandMotionFrame]
    let audioEvents: [ReferenceAudioEvent]
    let gestureEvents: [ReferenceGestureEvent]
    let learnedProfile: LearnedGestureProfile
    let soundRecipes: [GestureSoundRecipe]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case datasetID = "datasetId"
        case sourceFileName
        case materialProfile
        case mode
        case duration
        case analyzedFramesPerSecond
        case motionFrames
        case audioEvents
        case gestureEvents
        case learnedProfile
        case soundRecipes
    }

    func encodedJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try encoder.encode(self)
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
