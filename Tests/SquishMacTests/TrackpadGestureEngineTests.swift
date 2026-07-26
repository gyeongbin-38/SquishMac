import XCTest
@testable import SquishMac

final class TrackpadGestureEngineTests: XCTestCase {
    func testSixFingerSlimeTriggersWithSeveralFingersAndPressure() {
        let engine = TrackpadGestureEngine()

        let evaluation = engine.evaluate(
            mode: .sixFingerSlime,
            fingerCount: 6,
            pressure: 0.45,
            movement: 0.08,
            spread: 0.8,
            timestamp: 1
        )

        XCTAssertGreaterThan(evaluation.liveIntensity, 0.5)
        XCTAssertEqual(evaluation.trigger?.kind, .slimeKnead)
    }

    func testSlimeIgnoresTooFewFingers() {
        let engine = TrackpadGestureEngine()

        let evaluation = engine.evaluate(
            mode: .sixFingerSlime,
            fingerCount: 1,
            pressure: 0.9,
            movement: 0.9,
            spread: 0.2,
            timestamp: 1
        )

        XCTAssertNil(evaluation.trigger)
    }

    func testWaxCrushRequiresTwoFingersAndPressure() {
        let engine = TrackpadGestureEngine()

        let evaluation = engine.evaluate(
            mode: .twoThumbWaxCrush,
            fingerCount: 2,
            pressure: 0.82,
            movement: 0.15,
            spread: 0.25,
            timestamp: 1
        )

        XCTAssertGreaterThan(evaluation.liveIntensity, 0.5)
        XCTAssertEqual(evaluation.trigger?.kind, .waxCrush)
    }

    func testWaxPressAndCrackUseLowerIntensityStages() {
        let engine = TrackpadGestureEngine()

        let press = engine.evaluate(
            mode: .twoThumbWaxCrush,
            fingerCount: 2,
            pressure: 0.52,
            movement: 0.10,
            spread: 0.35,
            timestamp: 1
        )
        let crack = engine.evaluate(
            mode: .twoThumbWaxCrush,
            fingerCount: 2,
            pressure: 0.62,
            movement: 0.34,
            spread: 0.25,
            timestamp: 1.5
        )

        XCTAssertEqual(press.trigger?.kind, .waxPress)
        XCTAssertEqual(crack.trigger?.kind, .waxCrack)
    }

    func testSlimeStretchAndReleaseAreDistinctGestures() {
        let engine = TrackpadGestureEngine()

        let stretch = engine.evaluate(
            mode: .sixFingerSlime,
            fingerCount: 5,
            pressure: 0.42,
            movement: 0.32,
            spread: 0.70,
            timestamp: 1
        )
        let release = engine.evaluate(
            mode: .sixFingerSlime,
            fingerCount: 0,
            pressure: 0,
            movement: 0,
            spread: 0,
            timestamp: 1.5
        )

        XCTAssertEqual(stretch.trigger?.kind, .slimeStretch)
        XCTAssertEqual(release.trigger?.kind, .slimeRelease)
    }

    func testTrackpadCooldownSuppressesImmediateRepeats() {
        let engine = TrackpadGestureEngine()

        let first = engine.evaluate(
            mode: .twoThumbWaxCrush,
            fingerCount: 2,
            pressure: 0.9,
            movement: 0.4,
            spread: 0.1,
            timestamp: 1
        )
        let suppressed = engine.evaluate(
            mode: .twoThumbWaxCrush,
            fingerCount: 2,
            pressure: 0.9,
            movement: 0.4,
            spread: 0.1,
            timestamp: 1.05
        )

        XCTAssertNotNil(first.trigger)
        XCTAssertNil(suppressed.trigger)
    }

    func testStationarySlimeDoesNotRepeatWithoutTextureChange() {
        let engine = TrackpadGestureEngine()

        let first = engine.evaluate(
            mode: .sixFingerSlime,
            fingerCount: 6,
            pressure: 0.5,
            movement: 0.1,
            spread: 0.7,
            timestamp: 1
        )
        let stationary = engine.evaluate(
            mode: .sixFingerSlime,
            fingerCount: 6,
            pressure: 0.5,
            movement: 0,
            spread: 0.7,
            timestamp: 2
        )

        XCTAssertNotNil(first.trigger)
        XCTAssertNil(stationary.trigger)
    }

    func testWaxCrushStageDoesNotRepeatUntilTouchCycleEnds() {
        let engine = TrackpadGestureEngine()

        let firstCrush = engine.evaluate(
            mode: .twoThumbWaxCrush,
            fingerCount: 2,
            pressure: 0.9,
            movement: 0.3,
            spread: 0.2,
            timestamp: 1
        )
        let heldCrush = engine.evaluate(
            mode: .twoThumbWaxCrush,
            fingerCount: 2,
            pressure: 0.95,
            movement: 0.4,
            spread: 0.1,
            timestamp: 2
        )
        _ = engine.evaluate(
            mode: .twoThumbWaxCrush,
            fingerCount: 0,
            pressure: 0,
            movement: 0,
            spread: 0,
            timestamp: 2.2
        )
        let nextCrush = engine.evaluate(
            mode: .twoThumbWaxCrush,
            fingerCount: 2,
            pressure: 0.9,
            movement: 0.3,
            spread: 0.2,
            timestamp: 3
        )

        XCTAssertEqual(firstCrush.trigger?.kind, .waxCrush)
        XCTAssertNil(heldCrush.trigger)
        XCTAssertEqual(nextCrush.trigger?.kind, .waxCrush)
    }

    func testResponseTuningCanRecognizeAQuieterWaxPress() {
        let standardEngine = TrackpadGestureEngine()
        let responsiveEngine = TrackpadGestureEngine()

        let standard = standardEngine.evaluate(
            mode: .twoThumbWaxCrush,
            fingerCount: 2,
            pressure: 0.25,
            movement: 0,
            spread: 0.9,
            timestamp: 1
        )
        let responsive = responsiveEngine.evaluate(
            mode: .twoThumbWaxCrush,
            fingerCount: 2,
            pressure: 0.25,
            movement: 0,
            spread: 0.9,
            timestamp: 1,
            tuning: TrackpadTuning(response: 1.75, soundDensity: 1)
        )

        XCTAssertNil(standard.trigger)
        XCTAssertEqual(responsive.trigger?.kind, .waxPress)
    }

    func testDoctorPuttyFastStretchTriggersMaterialSpecificFailure() {
        let engine = TrackpadGestureEngine()

        let failure = engine.evaluate(
            mode: .sixFingerSlime,
            fingerCount: 6,
            pressure: 0.42,
            movement: 0.82,
            spread: 0.75,
            timestamp: 1,
            interactionRules: .doctorPutty
        )

        XCTAssertEqual(failure.trigger?.kind, .slimeStretchFailure)
        XCTAssertEqual(failure.trigger?.soundPackIDOverride, "doctor-putty-failure")
        XCTAssertGreaterThanOrEqual(failure.trigger?.intensity ?? 0, 0.7)
    }

    func testGenericSlimeDoesNotUseDoctorPuttyFailureRule() {
        let engine = TrackpadGestureEngine()

        let stretch = engine.evaluate(
            mode: .sixFingerSlime,
            fingerCount: 6,
            pressure: 0.42,
            movement: 0.82,
            spread: 0.75,
            timestamp: 1,
            interactionRules: .standard
        )

        XCTAssertEqual(stretch.trigger?.kind, .slimeStretch)
        XCTAssertNil(stretch.trigger?.soundPackIDOverride)
    }

    func testVideo3ClearSlimeRoutesKneadAndStretchToSeparatePacks() {
        let kneadEngine = TrackpadGestureEngine()
        let stretchEngine = TrackpadGestureEngine()

        let knead = kneadEngine.evaluate(
            mode: .sixFingerSlime,
            fingerCount: 5,
            pressure: 0.55,
            movement: 0.08,
            spread: 0.45,
            timestamp: 1,
            interactionRules: .clearVideo3
        )
        let stretch = stretchEngine.evaluate(
            mode: .sixFingerSlime,
            fingerCount: 6,
            pressure: 0.42,
            movement: 0.30,
            spread: 0.70,
            timestamp: 1,
            interactionRules: .clearVideo3
        )

        XCTAssertEqual(knead.trigger?.kind, .slimeKnead)
        XCTAssertEqual(knead.trigger?.soundPackIDOverride, "clear-video-3-knead")
        XCTAssertEqual(stretch.trigger?.kind, .slimeStretch)
        XCTAssertEqual(stretch.trigger?.soundPackIDOverride, "clear-video-3-stretch")
    }

    func testDoctorPuttyFailureRequiresMovementResetBeforeRepeating() {
        let engine = TrackpadGestureEngine()

        let first = engine.evaluate(
            mode: .sixFingerSlime,
            fingerCount: 6,
            pressure: 0.42,
            movement: 0.82,
            spread: 0.75,
            timestamp: 1,
            interactionRules: .doctorPutty
        )
        let held = engine.evaluate(
            mode: .sixFingerSlime,
            fingerCount: 6,
            pressure: 0.40,
            movement: 0.90,
            spread: 0.80,
            timestamp: 2,
            interactionRules: .doctorPutty
        )
        _ = engine.evaluate(
            mode: .sixFingerSlime,
            fingerCount: 6,
            pressure: 0.35,
            movement: 0.20,
            spread: 0.72,
            timestamp: 2.2,
            interactionRules: .doctorPutty
        )
        let next = engine.evaluate(
            mode: .sixFingerSlime,
            fingerCount: 6,
            pressure: 0.42,
            movement: 0.84,
            spread: 0.82,
            timestamp: 3,
            interactionRules: .doctorPutty
        )

        XCTAssertEqual(first.trigger?.kind, .slimeStretchFailure)
        XCTAssertNotEqual(held.trigger?.kind, .slimeStretchFailure)
        XCTAssertEqual(next.trigger?.kind, .slimeStretchFailure)
    }
}
