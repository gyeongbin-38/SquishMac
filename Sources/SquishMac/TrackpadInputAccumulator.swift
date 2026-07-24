import Foundation

struct TrackpadInputFrame: Equatable {
    let touchPoints: [TrackpadTouchPoint]
    let pressure: Double
    let forceStage: Int
    let movement: Double
    let spread: Double
}

struct TrackpadInputAccumulator {
    private(set) var touchPoints: [TrackpadTouchPoint] = []
    private(set) var pressure = 0.0
    private(set) var forceStage = 0

    mutating func updateTouches(_ points: [TrackpadTouchPoint]) -> TrackpadInputFrame {
        let sortedPoints = points.sorted { $0.id < $1.id }
        let movement = TrackpadTouchMetrics.movement(current: sortedPoints, previous: touchPoints)
        touchPoints = sortedPoints

        if sortedPoints.isEmpty {
            pressure = 0
            forceStage = 0
        }

        return frame(movement: movement)
    }

    mutating func updatePressure(_ pressure: Double, forceStage: Int) -> TrackpadInputFrame {
        self.pressure = pressure.clamped(to: 0.0...1.0)
        self.forceStage = max(0, forceStage)
        return frame(movement: 0)
    }

    mutating func clear() {
        touchPoints.removeAll()
        pressure = 0
        forceStage = 0
    }

    private func frame(movement: Double) -> TrackpadInputFrame {
        TrackpadInputFrame(
            touchPoints: touchPoints,
            pressure: pressure,
            forceStage: forceStage,
            movement: movement,
            spread: TrackpadTouchMetrics.spread(touchPoints)
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
