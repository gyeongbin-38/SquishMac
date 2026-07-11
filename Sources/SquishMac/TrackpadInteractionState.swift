import Foundation

final class TrackpadInteractionState: ObservableObject {
    @Published var mode: TrackpadMode = .sixFingerSlime {
        didSet { engine.reset() }
    }

    @Published private(set) var fingerCount: Int = 0
    @Published private(set) var pressure: Double = 0
    @Published private(set) var movement: Double = 0
    @Published private(set) var spread: Double = 0
    @Published private(set) var liveIntensity: Double = 0
    @Published private(set) var lastGestureLabel: String = "None"
    @Published private(set) var lastGestureDate: Date?
    @Published private(set) var maxFingerCount: Int = 0
    @Published private(set) var peakPressure: Double = 0
    @Published private(set) var peakIntensity: Double = 0
    @Published private(set) var gestureCount: Int = 0

    private let engine = TrackpadGestureEngine()

    func update(
        fingerCount: Int,
        pressure: Double,
        movement: Double,
        spread: Double,
        date: Date = Date()
    ) -> TrackpadGestureTrigger? {
        let evaluation = engine.evaluate(
            mode: mode,
            fingerCount: fingerCount,
            pressure: pressure,
            movement: movement,
            spread: spread,
            timestamp: date.timeIntervalSinceReferenceDate
        )

        self.fingerCount = fingerCount
        self.pressure = pressure.clamped(to: 0.0...1.0)
        self.movement = movement.clamped(to: 0.0...1.0)
        self.spread = spread.clamped(to: 0.0...1.0)
        self.liveIntensity = evaluation.liveIntensity
        self.maxFingerCount = max(maxFingerCount, fingerCount)
        self.peakPressure = max(peakPressure, self.pressure)
        self.peakIntensity = max(peakIntensity, evaluation.liveIntensity)

        if let trigger = evaluation.trigger {
            lastGestureLabel = trigger.label
            lastGestureDate = date
            gestureCount += 1
            return trigger
        }

        return nil
    }

    func reset() {
        engine.reset()
        fingerCount = 0
        pressure = 0
        movement = 0
        spread = 0
        liveIntensity = 0
        lastGestureLabel = "None"
        lastGestureDate = nil
        maxFingerCount = 0
        peakPressure = 0
        peakIntensity = 0
        gestureCount = 0
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
