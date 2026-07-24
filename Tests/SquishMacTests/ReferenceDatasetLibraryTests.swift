import XCTest
@testable import SquishMac

final class ReferenceDatasetLibraryTests: XCTestCase {
    func testDatasetsAreSeparatedByMaterialProfileAndDatasetID() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let library = ReferenceDatasetLibrary(rootURL: root)
        let clearAnalysis = makeAnalysis(
            datasetID: "clear-video-1",
            profile: SlimeMaterialProfile.builtIn[0]
        )
        let waxProfile = try XCTUnwrap(
            SlimeMaterialProfile.builtIn.first { $0.category == .waxShell }
        )
        let waxAnalysis = makeAnalysis(
            datasetID: "wax-video-1",
            profile: waxProfile
        )

        let clearURL = try library.save(clearAnalysis)
        let waxURL = try library.save(waxAnalysis)

        XCTAssertNotEqual(clearURL.deletingLastPathComponent(), waxURL.deletingLastPathComponent())
        XCTAssertEqual(library.datasetCount(for: clearAnalysis.materialProfile.id), 1)
        XCTAssertEqual(library.datasetCount(for: waxProfile.id), 1)
        XCTAssertEqual(try library.load(from: clearURL), clearAnalysis)
        XCTAssertEqual(try library.load(from: waxURL), waxAnalysis)
    }

    private func makeAnalysis(
        datasetID: String,
        profile: SlimeMaterialProfile
    ) -> ReferenceVideoAnalysis {
        ReferenceVideoAnalysis(
            schemaVersion: 2,
            datasetID: datasetID,
            sourceFileName: "\(datasetID).mov",
            materialProfile: profile,
            mode: profile.referenceMode,
            duration: 1,
            analyzedFramesPerSecond: 15,
            motionFrames: [],
            audioEvents: [],
            gestureEvents: [],
            learnedProfile: LearnedGestureProfile(
                movementMedian: 0,
                movementHigh: 0,
                pressureMedian: 0,
                pressureHigh: 0,
                spreadMedian: 0,
                suggestedResponse: 1,
                suggestedSoundDensity: 1
            ),
            soundRecipes: GestureSoundRecipeLibrary.all
        )
    }
}
