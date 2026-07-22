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
}
