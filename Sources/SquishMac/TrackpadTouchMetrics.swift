import Foundation

enum TrackpadTouchMetrics {
    static func movement(
        current: [TrackpadTouchPoint],
        previous: [TrackpadTouchPoint]
    ) -> Double {
        let previousByID = Dictionary(
            previous.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let sharedTouches = current.compactMap { touch -> (TrackpadTouchPoint, TrackpadTouchPoint)? in
            guard let previousTouch = previousByID[touch.id] else {
                return nil
            }
            return (touch, previousTouch)
        }

        guard !sharedTouches.isEmpty else {
            return 0
        }

        let total = sharedTouches.reduce(0.0) { partial, pair in
            partial + distance(pair.0, pair.1)
        }
        return (total / Double(sharedTouches.count) * 10.0).clamped(to: 0.0...1.0)
    }

    static func spread(_ touches: [TrackpadTouchPoint]) -> Double {
        guard touches.count >= 2 else {
            return 0
        }

        var maximumDistance = 0.0
        for leftIndex in 0..<touches.count {
            for rightIndex in (leftIndex + 1)..<touches.count {
                maximumDistance = max(
                    maximumDistance,
                    distance(touches[leftIndex], touches[rightIndex])
                )
            }
        }

        return maximumDistance.clamped(to: 0.0...1.0)
    }

    private static func distance(_ lhs: TrackpadTouchPoint, _ rhs: TrackpadTouchPoint) -> Double {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return sqrt(dx * dx + dy * dy)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
