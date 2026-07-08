import XCTest
@testable import SquishMac

final class SoundPackManagerTests: XCTestCase {
    func testCustomFolderWithoutPathReturnsNoSounds() {
        let manager = SoundPackManager()

        let urls = manager.soundURLs(
            for: SoundPackManager.customPackID,
            customDirectoryPath: nil
        )

        XCTAssertTrue(urls.isEmpty)
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
