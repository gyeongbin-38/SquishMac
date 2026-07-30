import XCTest
@testable import SquishMac

final class AudioResponseTests: XCTestCase {
    func testInteractionResponseUsesExpectedSoundPacks() {
        XCTAssertEqual(
            AudioResponseCurve.interaction(kind: .slimeKnead, intensity: 0.5, masterVolume: 1).packID,
            "slime"
        )
        XCTAssertEqual(
            AudioResponseCurve.interaction(kind: .slimeRelease, intensity: 0.5, masterVolume: 1).packID,
            "pop"
        )
        XCTAssertEqual(
            AudioResponseCurve.interaction(kind: .slimeBubble, intensity: 0.5, masterVolume: 1).packID,
            "bubble"
        )
        XCTAssertEqual(
            AudioResponseCurve.interaction(
                kind: .slimeStretchFailure,
                intensity: 0.5,
                masterVolume: 1
            ).packID,
            "pop"
        )
        XCTAssertEqual(
            AudioResponseCurve.interaction(kind: .waxPress, intensity: 0.5, masterVolume: 1).packID,
            "squishy"
        )
        XCTAssertEqual(
            AudioResponseCurve.interaction(kind: .waxCrush, intensity: 0.5, masterVolume: 1).packID,
            "wax"
        )
    }

    func testMasterVolumeScalesInteractionAndImpactVolume() {
        let full = AudioResponseCurve.interaction(kind: .waxCrush, intensity: 0.8, masterVolume: 1)
        let half = AudioResponseCurve.interaction(kind: .waxCrush, intensity: 0.8, masterVolume: 0.5)
        let fullImpact = AudioResponseCurve.impactVolume(
            impactStrength: 0.8,
            sensitivity: 0.3,
            masterVolume: 1
        )
        let halfImpact = AudioResponseCurve.impactVolume(
            impactStrength: 0.8,
            sensitivity: 0.3,
            masterVolume: 0.5
        )

        XCTAssertEqual(half.volume, full.volume * 0.5, accuracy: 0.0001)
        XCTAssertEqual(halfImpact, fullImpact * 0.5, accuracy: 0.0001)
    }

    func testReferencePackRateStaysCloseToRecordedPitch() {
        XCTAssertEqual(
            AudioResponseCurve.referencePackRate(intensity: 0),
            0.96,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            AudioResponseCurve.referencePackRate(intensity: 1),
            1.02,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            AudioResponseCurve.referencePackRate(intensity: 2),
            1.02,
            accuracy: 0.0001
        )
    }

    func testShuffleBagUsesEverySoundBeforeRepeating() {
        var selector = SoundVariationSelector()
        let urls = (1...5).map { URL(fileURLWithPath: "/sound-\($0).wav") }
        let firstCycle = (1...5).compactMap { _ in
            selector.nextURL(from: urls, key: "slime")
        }

        XCTAssertEqual(Set(firstCycle), Set(urls))
        XCTAssertEqual(firstCycle.count, urls.count)
        XCTAssertNotEqual(
            selector.nextURL(from: urls, key: "slime"),
            firstCycle.last
        )
    }

    func testMaterialLayerPlanRespectsIntensityProbabilityAndBounds() {
        let rules = InteractionSoundLayerRules(
            soundPackID: "material-texture",
            minimumIntensity: 0.30,
            probabilityAtMinimum: 0.20,
            probabilityAtMaximum: 0.80,
            volumeScaleAtMinimum: 0.10,
            volumeScaleAtMaximum: 0.40,
            minimumDelayMilliseconds: 8,
            maximumDelayMilliseconds: 28,
            rateOffset: 0.02
        )

        XCTAssertNil(
            rules.plan(intensity: 0.29, probabilitySample: 0, delaySample: 0)
        )
        XCTAssertNil(
            rules.plan(intensity: 0.30, probabilitySample: 0.21, delaySample: 0)
        )

        let quiet = rules.plan(
            intensity: 0.30,
            probabilitySample: 0.20,
            delaySample: 0
        )
        XCTAssertEqual(quiet?.soundPackID, "material-texture")
        XCTAssertEqual(quiet?.volumeScale ?? 0, 0.10, accuracy: 0.0001)
        XCTAssertEqual(quiet?.delayMilliseconds ?? 0, 8, accuracy: 0.0001)

        let strong = rules.plan(
            intensity: 1,
            probabilitySample: 0.80,
            delaySample: 1
        )
        XCTAssertEqual(strong?.volumeScale ?? 0, 0.40, accuracy: 0.0001)
        XCTAssertEqual(strong?.delayMilliseconds ?? 0, 28, accuracy: 0.0001)
        XCTAssertEqual(strong?.rateOffset ?? 0, 0.02, accuracy: 0.0001)
    }
}
