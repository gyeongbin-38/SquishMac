import XCTest
@testable import SquishMac

final class ReferenceAnalysisTests: XCTestCase {
    func testEveryRuntimeGestureHasLayeredSoundRecipe() {
        for kind in TrackpadSoundKind.allCases {
            let recipe = GestureSoundRecipeLibrary.recipe(for: kind)

            XCTAssertFalse(recipe.layers.isEmpty)
            XCTAssertEqual(recipe.layers.first?.probability, 1)
            XCTAssertTrue(recipe.layers.allSatisfy { !$0.sourcePackID.isEmpty })
            XCTAssertTrue(recipe.layers.allSatisfy {
                $0.playbackRate.minimum <= $0.playbackRate.maximum
            })
        }
    }

    func testReferenceAnalysisJSONRoundTrip() throws {
        let analysis = ReferenceVideoAnalysis(
            schemaVersion: 2,
            datasetID: "clear__test-dataset",
            sourceFileName: "owned-reference.mov",
            materialProfile: SlimeMaterialProfile.builtIn[0],
            mode: .slime,
            duration: 1.5,
            analyzedFramesPerSecond: 15,
            motionFrames: [],
            audioEvents: [
                ReferenceAudioEvent(
                    timestamp: 0.4,
                    rms: 0.2,
                    peak: 0.8,
                    zeroCrossingRate: 0.12,
                    crestFactor: 4,
                    suggestedTexture: .suctionPop,
                    suggestedClipStart: 0.32,
                    suggestedClipEnd: 0.78
                )
            ],
            gestureEvents: [
                ReferenceGestureEvent(
                    timestamp: 0.42,
                    kind: .slimeKnead,
                    intensity: 0.7,
                    audioEventIndex: 0
                )
            ],
            learnedProfile: LearnedGestureProfile(
                movementMedian: 0.1,
                movementHigh: 0.4,
                pressureMedian: 0.3,
                pressureHigh: 0.8,
                spreadMedian: 0.5,
                suggestedResponse: 1.1,
                suggestedSoundDensity: 1.2
            ),
            soundRecipes: GestureSoundRecipeLibrary.all
        )

        let data = try analysis.encodedJSON()
        let decoded = try ReferenceVideoAnalysis.decoder().decode(
            ReferenceVideoAnalysis.self,
            from: data
        )

        XCTAssertEqual(decoded, analysis)
        XCTAssertEqual(decoded.gestureEvents.first?.audioEventIndex, 0)
    }

    func testDoctorPuttyKeepsMaterialSpecificInteractionRules() throws {
        let profile = try XCTUnwrap(
            SlimeMaterialProfile.builtIn.first { $0.id == "doctor-putty-pink" }
        )

        XCTAssertEqual(profile.category, .butterClay)
        XCTAssertEqual(
            profile.effectiveInteractionRules.fastStretchFailureMovementThreshold,
            0.72
        )
        XCTAssertEqual(
            profile.effectiveInteractionRules.failureSoundPackID,
            "doctor-putty-failure"
        )
        XCTAssertNil(
            SlimeMaterialProfile.builtIn
                .first { $0.id == "butter-clay" }?
                .effectiveInteractionRules
                .fastStretchFailureMovementThreshold
        )
    }

    func testVideo3ClearSlimeKeepsInputSpecificTuningAndSoundMappings() throws {
        let profile = try XCTUnwrap(
            SlimeMaterialProfile.builtIn.first { $0.id == "clear-video-3" }
        )

        XCTAssertEqual(profile.category, .clear)
        XCTAssertEqual(profile.effectiveTrackpadTuning.response, 0.96)
        XCTAssertEqual(profile.effectiveTrackpadTuning.soundDensity, 1.08)
        XCTAssertEqual(
            profile.effectiveCameraTuning.stretchMovementThreshold,
            0.21
        )
        XCTAssertEqual(
            profile.effectiveInteractionRules.soundPackID(for: .slimeKnead),
            "clear-video-3-knead"
        )
        XCTAssertEqual(
            profile.effectiveInteractionRules.soundPackID(for: .slimeStretch),
            "clear-video-3-stretch"
        )
        XCTAssertEqual(
            profile.effectiveInteractionRules.soundPackID(for: .slimeBubble),
            "clear-video-3-stretch"
        )
        XCTAssertEqual(
            profile.effectiveInteractionRules.effectiveVolumeScale,
            0.86,
            accuracy: 0.0001
        )
        XCTAssertNotNil(profile.effectiveInteractionRules.bubbleGesture)
        XCTAssertNotNil(profile.effectiveCameraTuning.bubbleGesture)
    }
}
