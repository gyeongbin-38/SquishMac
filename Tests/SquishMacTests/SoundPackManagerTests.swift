import XCTest
@testable import SquishMac

final class SoundPackManagerTests: XCTestCase {
    func testEveryBundledPackContainsPlayableSounds() {
        let manager = SoundPackManager()

        for pack in SoundPackManager.packs {
            XCTAssertFalse(
                manager.soundURLs(for: pack.id, customDirectoryPath: nil).isEmpty,
                "Expected bundled sounds for \(pack.id)"
            )
        }
    }

    func testCustomFolderWithoutPathReturnsNoSounds() {
        let manager = SoundPackManager()

        let urls = manager.soundURLs(
            for: SoundPackManager.customPackID,
            customDirectoryPath: nil
        )

        XCTAssertTrue(urls.isEmpty)
    }

    func testDoctorPuttyFailurePackIsProfileOnly() {
        let manager = SoundPackManager()

        XCTAssertEqual(
            manager.soundCount(
                for: "doctor-putty-failure",
                customDirectoryPath: nil
            ),
            2
        )
        XCTAssertFalse(
            manager.availablePacks().contains { $0.id == "doctor-putty-failure" }
        )
    }

    func testVideo3ClearSlimePacksAreGestureSpecificAndProfileOnly() {
        let manager = SoundPackManager()

        XCTAssertEqual(
            manager.soundCount(
                for: "clear-video-3-knead",
                customDirectoryPath: nil
            ),
            34
        )
        XCTAssertEqual(
            manager.soundCount(
                for: "clear-video-3-stretch",
                customDirectoryPath: nil
            ),
            6
        )
        XCTAssertFalse(
            manager.availablePacks().contains {
                $0.id == "clear-video-3-knead"
                    || $0.id == "clear-video-3-stretch"
            }
        )
    }

    func testVideo4PastelWaxPacksIncludeRestoredBreaksAndAreProfileOnly() {
        let manager = SoundPackManager()

        XCTAssertEqual(
            manager.soundCount(
                for: "pastel-wax-video-4-press",
                customDirectoryPath: nil
            ),
            18
        )
        XCTAssertEqual(
            manager.soundCount(
                for: "pastel-wax-video-4-crack",
                customDirectoryPath: nil
            ),
            5
        )
        XCTAssertEqual(
            manager.soundCount(
                for: "pastel-wax-video-4-crush",
                customDirectoryPath: nil
            ),
            1
        )
        XCTAssertFalse(
            manager.availablePacks().contains {
                $0.id.hasPrefix("pastel-wax-video-4-")
            }
        )
    }

    func testVideo5WhitePuttyPacksAreGestureSpecificAndProfileOnly() {
        let manager = SoundPackManager()

        XCTAssertEqual(
            manager.soundCount(
                for: "white-putty-video-5-knead",
                customDirectoryPath: nil
            ),
            14
        )
        XCTAssertEqual(
            manager.soundCount(
                for: "white-putty-video-5-stretch",
                customDirectoryPath: nil
            ),
            6
        )
        XCTAssertFalse(
            manager.availablePacks().contains {
                $0.id.hasPrefix("white-putty-video-5-")
            }
        )
    }

    func testVideo6AeratedClearPacksAreGestureSpecificAndProfileOnly() {
        let manager = SoundPackManager()

        XCTAssertEqual(
            manager.soundCount(
                for: "aerated-clear-video-6-knead",
                customDirectoryPath: nil
            ),
            35
        )
        XCTAssertEqual(
            manager.soundCount(
                for: "aerated-clear-video-6-stretch",
                customDirectoryPath: nil
            ),
            7
        )
        XCTAssertFalse(
            manager.availablePacks().contains {
                $0.id.hasPrefix("aerated-clear-video-6-")
            }
        )
    }

    func testVideo7DenseWhiteClayPacksAreGestureSpecificAndProfileOnly() {
        let manager = SoundPackManager()

        XCTAssertEqual(
            manager.soundCount(
                for: "dense-white-clay-video-7-knead",
                customDirectoryPath: nil
            ),
            20
        )
        XCTAssertEqual(
            manager.soundCount(
                for: "dense-white-clay-video-7-stretch",
                customDirectoryPath: nil
            ),
            9
        )
        XCTAssertFalse(
            manager.availablePacks().contains {
                $0.id.hasPrefix("dense-white-clay-video-7-")
            }
        )
    }

    func testVideo8PinkGummyJellyPacksAreGestureSpecificAndProfileOnly() {
        let manager = SoundPackManager()

        XCTAssertEqual(
            manager.soundCount(
                for: "pink-gummy-jelly-video-8-knead",
                customDirectoryPath: nil
            ),
            24
        )
        XCTAssertEqual(
            manager.soundCount(
                for: "pink-gummy-jelly-video-8-stretch",
                customDirectoryPath: nil
            ),
            6
        )
        XCTAssertFalse(
            manager.availablePacks().contains {
                $0.id.hasPrefix("pink-gummy-jelly-video-8-")
            }
        )
    }

    func testCustomFolderSearchesRecursivelyForSupportedAudioFiles() throws {
        let manager = SoundPackManager()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let nested = root.appendingPathComponent("nested", isDirectory: true)

        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data("sound".utf8).write(to: root.appendingPathComponent("one.wav"))
        try Data("sound".utf8).write(to: nested.appendingPathComponent("two.mp3"))
        try Data("ignore".utf8).write(to: nested.appendingPathComponent("note.txt"))

        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let names = manager.soundURLs(
            for: SoundPackManager.customPackID,
            customDirectoryPath: root.path
        )
        .map(\.lastPathComponent)

        XCTAssertEqual(names.sorted(), ["one.wav", "two.mp3"])
    }
}
