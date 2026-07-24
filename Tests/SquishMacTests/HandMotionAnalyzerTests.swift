import XCTest
@testable import SquishMac

final class HandMotionAnalyzerTests: XCTestCase {
    func testFeatureExtractorTracksMovementAndCompression() {
        var extractor = HandMotionFeatureExtractor()
        let first = extractor.process(sample(timestamp: 0, xOffset: 0))
        let second = extractor.process(sample(timestamp: 0.1, xOffset: 0.08))

        XCTAssertEqual(first.fingertipCount, 5)
        XCTAssertEqual(first.movement, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(first.pressureEstimate, 0.7)
        XCTAssertGreaterThan(second.movement, 0.3)
    }

    func testSlimeReleaseIsInferredAfterFingerLift() {
        let engine = ReferenceGestureInferenceEngine(mode: .slime)
        let contact = motionFrame(
            timestamp: 0,
            handCount: 1,
            fingertipCount: 5,
            movement: 0.12,
            spread: 0.4,
            pressure: 0.65
        )
        let release = motionFrame(
            timestamp: 0.2,
            handCount: 0,
            fingertipCount: 0,
            movement: 0,
            spread: 0,
            pressure: 0
        )

        XCTAssertNotNil(engine.process(contact))
        XCTAssertEqual(engine.process(release)?.kind, .slimeRelease)
    }

    func testWaxInferenceAdvancesThroughPressCrackAndCrush() {
        let engine = ReferenceGestureInferenceEngine(mode: .wax)
        let press = engine.process(motionFrame(
            timestamp: 0,
            handCount: 1,
            fingertipCount: 2,
            movement: 0,
            spread: 0.2,
            pressure: 0.30
        ))
        let crack = engine.process(motionFrame(
            timestamp: 0.2,
            handCount: 1,
            fingertipCount: 2,
            movement: 0,
            spread: 0.15,
            pressure: 0.60
        ))
        let crush = engine.process(motionFrame(
            timestamp: 0.4,
            handCount: 1,
            fingertipCount: 2,
            movement: 0,
            spread: 0.10,
            pressure: 0.90
        ))

        XCTAssertEqual(press?.kind, .waxPress)
        XCTAssertEqual(crack?.kind, .waxCrack)
        XCTAssertEqual(crush?.kind, .waxCrush)
    }

    private func sample(timestamp: TimeInterval, xOffset: Double) -> HandPoseSample {
        let wrist = NormalizedPosePoint(x: 0.45 + xOffset, y: 0.45, confidence: 1)
        let joints: [HandJointName: NormalizedPosePoint] = [
            .wrist: wrist,
            .thumbTip: NormalizedPosePoint(x: 0.46 + xOffset, y: 0.50, confidence: 1),
            .indexTip: NormalizedPosePoint(x: 0.47 + xOffset, y: 0.51, confidence: 1),
            .middleTip: NormalizedPosePoint(x: 0.48 + xOffset, y: 0.52, confidence: 1),
            .ringTip: NormalizedPosePoint(x: 0.49 + xOffset, y: 0.51, confidence: 1),
            .littleTip: NormalizedPosePoint(x: 0.50 + xOffset, y: 0.50, confidence: 1)
        ]
        return HandPoseSample(
            timestamp: timestamp,
            hands: [DetectedHandPose(id: 0, joints: joints)]
        )
    }

    private func motionFrame(
        timestamp: TimeInterval,
        handCount: Int,
        fingertipCount: Int,
        movement: Double,
        spread: Double,
        pressure: Double
    ) -> HandMotionFrame {
        HandMotionFrame(
            timestamp: timestamp,
            handCount: handCount,
            fingertipCount: fingertipCount,
            centroidX: 0.5,
            centroidY: 0.5,
            movement: movement,
            spread: spread,
            openness: 0.2,
            pinch: pressure,
            pressureEstimate: pressure,
            hands: []
        )
    }
}
