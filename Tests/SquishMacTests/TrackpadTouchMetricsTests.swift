import XCTest
@testable import SquishMac

final class TrackpadTouchMetricsTests: XCTestCase {
    func testMovementMatchesTouchesByIdentityInsteadOfArrayOrder() {
        let previous = [
            TrackpadTouchPoint(id: "left", x: 0.2, y: 0.3),
            TrackpadTouchPoint(id: "right", x: 0.8, y: 0.3)
        ]
        let reordered = [
            TrackpadTouchPoint(id: "right", x: 0.8, y: 0.3),
            TrackpadTouchPoint(id: "left", x: 0.2, y: 0.3)
        ]

        XCTAssertEqual(
            TrackpadTouchMetrics.movement(current: reordered, previous: previous),
            0,
            accuracy: 0.0001
        )
    }

    func testPartialFingerReleaseDoesNotCreateFalseMovement() {
        let previous = [
            TrackpadTouchPoint(id: "one", x: 0.1, y: 0.1),
            TrackpadTouchPoint(id: "two", x: 0.9, y: 0.9)
        ]
        let current = [TrackpadTouchPoint(id: "two", x: 0.9, y: 0.9)]

        XCTAssertEqual(
            TrackpadTouchMetrics.movement(current: current, previous: previous),
            0,
            accuracy: 0.0001
        )
    }

    func testSpreadUsesFarthestPair() {
        let touches = [
            TrackpadTouchPoint(id: "one", x: 0.1, y: 0.1),
            TrackpadTouchPoint(id: "two", x: 0.4, y: 0.1),
            TrackpadTouchPoint(id: "three", x: 0.9, y: 0.1)
        ]

        XCTAssertEqual(TrackpadTouchMetrics.spread(touches), 0.8, accuracy: 0.0001)
    }
}
