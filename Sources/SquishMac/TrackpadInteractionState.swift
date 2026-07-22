import Foundation

final class TrackpadInteractionState: ObservableObject {
    @Published var mode: TrackpadMode {
        didSet {
            guard mode != oldValue else {
                return
            }
            engine.reset()
            clearLiveInput()
        }
    }

    @Published private(set) var fingerCount: Int = 0
    @Published private(set) var pressure: Double = 0
    @Published private(set) var forceStage: Int = 0
    @Published private(set) var movement: Double = 0
    @Published private(set) var spread: Double = 0
    @Published private(set) var liveIntensity: Double = 0
    @Published private(set) var touchPoints: [TrackpadTouchPoint] = []
    @Published private(set) var lastGestureLabel: String = "None"
    @Published private(set) var lastGestureDate: Date?
    @Published private(set) var lastSampleDate: Date?
    @Published private(set) var maxFingerCount: Int = 0
    @Published private(set) var peakPressure: Double = 0
    @Published private(set) var peakIntensity: Double = 0
    @Published private(set) var gestureCount: Int = 0
    @Published private(set) var inputEventCount: Int = 0
    @Published private(set) var pressureEventCount: Int = 0
    @Published private(set) var isRecording = false
    @Published private(set) var recordedSampleCount = 0
    @Published private(set) var recordingAtCapacity = false

    private let engine = TrackpadGestureEngine()
    private let recorder: TrackpadSessionRecorder

    init(mode: TrackpadMode = .sixFingerSlime, recorder: TrackpadSessionRecorder = TrackpadSessionRecorder()) {
        self.mode = mode
        self.recorder = recorder
    }

    var pressureStatus: String {
        if pressureEventCount > 0 {
            return "Force pressure detected"
        }
        if inputEventCount > 0 {
            return "Touches detected; press firmly"
        }
        return "Waiting for trackpad input"
    }

    var hasRecording: Bool {
        recorder.hasRecording
    }

    func update(
        fingerCount: Int,
        pressure: Double,
        forceStage: Int,
        movement: Double,
        spread: Double,
        touchPoints: [TrackpadTouchPoint],
        tuning: TrackpadTuning = .standard,
        isPressureEvent: Bool = false,
        date: Date = Date()
    ) -> TrackpadGestureTrigger? {
        let safeFingerCount = max(0, fingerCount)
        let evaluation = engine.evaluate(
            mode: mode,
            fingerCount: safeFingerCount,
            pressure: pressure,
            movement: movement,
            spread: spread,
            timestamp: date.timeIntervalSinceReferenceDate,
            tuning: tuning
        )

        self.fingerCount = safeFingerCount
        self.pressure = pressure.clamped(to: 0.0...1.0)
        self.forceStage = max(0, forceStage)
        self.movement = movement.clamped(to: 0.0...1.0)
        self.spread = spread.clamped(to: 0.0...1.0)
        self.liveIntensity = evaluation.liveIntensity
        self.touchPoints = touchPoints
        self.lastSampleDate = date
        self.maxFingerCount = max(maxFingerCount, safeFingerCount)
        self.peakPressure = max(peakPressure, self.pressure)
        self.peakIntensity = max(peakIntensity, evaluation.liveIntensity)
        inputEventCount += 1
        if isPressureEvent {
            pressureEventCount += 1
        }

        if let trigger = evaluation.trigger {
            lastGestureLabel = trigger.label
            lastGestureDate = date
            gestureCount += 1
        }

        recorder.append(
            mode: mode,
            fingerCount: safeFingerCount,
            pressure: self.pressure,
            forceStage: self.forceStage,
            movement: self.movement,
            spread: self.spread,
            intensity: evaluation.liveIntensity,
            touches: touchPoints,
            trigger: evaluation.trigger,
            at: date
        )
        syncRecordingState()

        return evaluation.trigger
    }

    func startRecording(tuning: TrackpadTuning, at date: Date = Date()) {
        recorder.start(tuning: tuning, at: date)
        syncRecordingState()
    }

    func stopRecording(at date: Date = Date()) {
        recorder.stop(at: date)
        syncRecordingState()
    }

    func clearRecording() {
        recorder.clear()
        syncRecordingState()
    }

    func encodedRecording() throws -> Data {
        try recorder.encodedSession()
    }

    func cancelCurrentGesture() {
        engine.reset()
        clearLiveInput()
    }

    func reset() {
        engine.reset()
        clearLiveInput()
        lastGestureLabel = "None"
        lastGestureDate = nil
        lastSampleDate = nil
        maxFingerCount = 0
        peakPressure = 0
        peakIntensity = 0
        gestureCount = 0
        inputEventCount = 0
        pressureEventCount = 0
    }

    private func clearLiveInput() {
        fingerCount = 0
        pressure = 0
        forceStage = 0
        movement = 0
        spread = 0
        liveIntensity = 0
        touchPoints = []
    }

    private func syncRecordingState() {
        isRecording = recorder.isRecording
        recordedSampleCount = recorder.samples.count
        recordingAtCapacity = recorder.isAtCapacity
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
