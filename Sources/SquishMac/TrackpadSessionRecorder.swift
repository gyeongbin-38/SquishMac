import Foundation

struct TrackpadTouchPoint: Identifiable, Codable, Equatable {
    let id: String
    let x: Double
    let y: Double

    init(id: String, x: Double, y: Double) {
        self.id = id
        self.x = x.clamped(to: 0.0...1.0)
        self.y = y.clamped(to: 0.0...1.0)
    }
}

struct TrackpadSessionSample: Codable, Equatable {
    let relativeTime: TimeInterval
    let mode: TrackpadMode
    let fingerCount: Int
    let pressure: Double
    let forceStage: Int
    let movement: Double
    let spread: Double
    let intensity: Double
    let touches: [TrackpadTouchPoint]
}

struct TrackpadSessionEvent: Codable, Equatable {
    let relativeTime: TimeInterval
    let kind: TrackpadSoundKind
    let intensity: Double
}

struct TrackpadSessionFile: Codable, Equatable {
    let schemaVersion: Int
    let appVersion: String
    let osVersion: String
    let architecture: String
    let startedAt: Date
    let endedAt: Date
    let tuning: TrackpadTuning
    let samples: [TrackpadSessionSample]
    let events: [TrackpadSessionEvent]
}

final class TrackpadSessionRecorder {
    private(set) var isRecording = false
    private(set) var isAtCapacity = false
    private(set) var samples: [TrackpadSessionSample] = []
    private(set) var events: [TrackpadSessionEvent] = []

    private let maximumSampleCount: Int
    private var startedAt: Date?
    private var endedAt: Date?
    private var tuning: TrackpadTuning = .standard

    init(maximumSampleCount: Int = 36_000) {
        self.maximumSampleCount = max(1, maximumSampleCount)
    }

    var hasRecording: Bool {
        !samples.isEmpty
    }

    func start(tuning: TrackpadTuning, at date: Date = Date()) {
        samples.removeAll(keepingCapacity: true)
        events.removeAll(keepingCapacity: true)
        startedAt = date
        endedAt = nil
        self.tuning = tuning
        isAtCapacity = false
        isRecording = true
    }

    func stop(at date: Date = Date()) {
        guard startedAt != nil else {
            return
        }

        endedAt = date
        isRecording = false
    }

    func clear() {
        isRecording = false
        isAtCapacity = false
        samples.removeAll(keepingCapacity: false)
        events.removeAll(keepingCapacity: false)
        startedAt = nil
        endedAt = nil
    }

    func append(
        mode: TrackpadMode,
        fingerCount: Int,
        pressure: Double,
        forceStage: Int,
        movement: Double,
        spread: Double,
        intensity: Double,
        touches: [TrackpadTouchPoint],
        trigger: TrackpadGestureTrigger?,
        at date: Date = Date()
    ) {
        guard isRecording, let startedAt else {
            return
        }

        let relativeTime = max(0, date.timeIntervalSince(startedAt))
        samples.append(TrackpadSessionSample(
            relativeTime: relativeTime,
            mode: mode,
            fingerCount: max(0, fingerCount),
            pressure: pressure.clamped(to: 0.0...1.0),
            forceStage: max(0, forceStage),
            movement: movement.clamped(to: 0.0...1.0),
            spread: spread.clamped(to: 0.0...1.0),
            intensity: intensity.clamped(to: 0.0...1.0),
            touches: touches,
        ))

        if let trigger {
            events.append(TrackpadSessionEvent(
                relativeTime: relativeTime,
                kind: trigger.kind,
                intensity: trigger.intensity.clamped(to: 0.0...1.0)
            ))
        }

        if samples.count >= maximumSampleCount {
            isAtCapacity = true
            stop(at: date)
        }
    }

    func encodedSession() throws -> Data {
        guard let startedAt, !samples.isEmpty else {
            throw TrackpadSessionRecorderError.noSamples
        }

        let file = TrackpadSessionFile(
            schemaVersion: 1,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: Self.architecture,
            startedAt: startedAt,
            endedAt: endedAt ?? Date(),
            tuning: tuning,
            samples: samples,
            events: events
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try encoder.encode(file)
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    private static var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}

enum TrackpadSessionRecorderError: LocalizedError, Equatable {
    case noSamples

    var errorDescription: String? {
        switch self {
        case .noSamples:
            return "There are no recorded trackpad samples to export."
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
