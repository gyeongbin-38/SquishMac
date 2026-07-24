import XCTest
@testable import SquishMac

final class TrackpadInputAccumulatorTests: XCTestCase {
    func testPressureEventKeepsExistingTwoFingerTouches() {
        var accumulator = TrackpadInputAccumulator()
        let touches = [
            TrackpadTouchPoint(id: "left", x: 0.2, y: 0.5),
            TrackpadTouchPoint(id: "right", x: 0.8, y: 0.5)
        ]

        _ = accumulator.updateTouches(touches)
        let pressureFrame = accumulator.updatePressure(0.7, forceStage: 1)

        XCTAssertEqual(pressureFrame.touchPoints, touches)
        XCTAssertEqual(pressureFrame.touchPoints.count, 2)
        XCTAssertEqual(pressureFrame.pressure, 0.7, accuracy: 0.0001)
        XCTAssertEqual(pressureFrame.forceStage, 1)
    }

    func testPartialReleaseKeepsRemainingTouchAndPressure() {
        var accumulator = TrackpadInputAccumulator()
        _ = accumulator.updateTouches([
            TrackpadTouchPoint(id: "one", x: 0.2, y: 0.5),
            TrackpadTouchPoint(id: "two", x: 0.8, y: 0.5)
        ])
        _ = accumulator.updatePressure(0.5, forceStage: 1)

        let frame = accumulator.updateTouches([
            TrackpadTouchPoint(id: "two", x: 0.8, y: 0.5)
        ])

        XCTAssertEqual(frame.touchPoints.count, 1)
        XCTAssertEqual(frame.pressure, 0.5, accuracy: 0.0001)
    }

    func testFinalReleaseClearsPressureAndStage() {
        var accumulator = TrackpadInputAccumulator()
        _ = accumulator.updateTouches([
            TrackpadTouchPoint(id: "one", x: 0.5, y: 0.5)
        ])
        _ = accumulator.updatePressure(0.8, forceStage: 2)

        let frame = accumulator.updateTouches([])

        XCTAssertTrue(frame.touchPoints.isEmpty)
        XCTAssertEqual(frame.pressure, 0)
        XCTAssertEqual(frame.forceStage, 0)
    }

    func testPressureAndTouchValuesAreClamped() {
        var accumulator = TrackpadInputAccumulator()
        let frame = accumulator.updatePressure(4, forceStage: -2)

        XCTAssertEqual(frame.pressure, 1)
        XCTAssertEqual(frame.forceStage, 0)
    }
}
