import XCTest
@testable import SquishMac

final class ImpactAnalyzerTests: XCTestCase {
    func testFirstSampleCalibratesWithoutTriggering() {
        let analyzer = ImpactAnalyzer()

        let result = analyzer.process(
            sample: AccelerationVector(x: 0, y: 0, z: 1),
            sensitivity: 0.2,
            cooldown: 0.8,
            timestamp: 10
        )

        XCTAssertEqual(result.currentStrength, 0, accuracy: 0.0001)
        XCTAssertNil(result.impactStrength)
    }

    func testImpactTriggersWhenStrengthExceedsSensitivity() {
        let analyzer = ImpactAnalyzer()
        _ = analyzer.process(
            sample: AccelerationVector(x: 0, y: 0, z: 1),
            sensitivity: 0.2,
            cooldown: 0.8,
            timestamp: 10
        )

        let result = analyzer.process(
            sample: AccelerationVector(x: 0.45, y: 0, z: 1),
            sensitivity: 0.2,
            cooldown: 0.8,
            timestamp: 11
        )

        XCTAssertGreaterThan(result.currentStrength, 0.2)
        XCTAssertNotNil(result.impactStrength)
    }

    func testCooldownSuppressesRepeatedImpacts() {
        let analyzer = ImpactAnalyzer()
        _ = analyzer.process(
            sample: AccelerationVector(x: 0, y: 0, z: 1),
            sensitivity: 0.2,
            cooldown: 1.0,
            timestamp: 10
        )

        let firstImpact = analyzer.process(
            sample: AccelerationVector(x: 0.45, y: 0, z: 1),
            sensitivity: 0.2,
            cooldown: 1.0,
            timestamp: 11
        )
        let suppressedImpact = analyzer.process(
            sample: AccelerationVector(x: -0.45, y: 0, z: 1),
            sensitivity: 0.2,
            cooldown: 1.0,
            timestamp: 11.2
        )
        let laterImpact = analyzer.process(
            sample: AccelerationVector(x: 0.50, y: 0, z: 1),
            sensitivity: 0.2,
            cooldown: 1.0,
            timestamp: 12.2
        )

        XCTAssertNotNil(firstImpact.impactStrength)
        XCTAssertNil(suppressedImpact.impactStrength)
        XCTAssertNotNil(laterImpact.impactStrength)
    }

    func testResetRequiresFreshCalibration() {
        let analyzer = ImpactAnalyzer()
        _ = analyzer.process(
            sample: AccelerationVector(x: 0, y: 0, z: 1),
            sensitivity: 0.2,
            cooldown: 0.8,
            timestamp: 10
        )

        analyzer.reset()

        let result = analyzer.process(
            sample: AccelerationVector(x: 1, y: 1, z: 1),
            sensitivity: 0.2,
            cooldown: 0.8,
            timestamp: 11
        )

        XCTAssertEqual(result.currentStrength, 0, accuracy: 0.0001)
        XCTAssertNil(result.impactStrength)
    }
}
