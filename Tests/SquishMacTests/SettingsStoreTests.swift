import XCTest
@testable import SquishMac

final class SettingsStoreTests: XCTestCase {
    func testClearingCustomFolderFallsBackToDefaultSoundPack() {
        let defaults = makeDefaults()
        let store = SettingsStore(defaults: defaults)

        store.customSoundDirectoryPath = "/tmp/squishmac-sounds"
        store.selectedSoundPackID = SoundPackManager.customPackID
        store.customSoundDirectoryPath = nil

        XCTAssertEqual(store.selectedSoundPackID, SoundPackManager.defaultPackID)
    }

    func testStoredCustomPackWithoutFolderFallsBackOnLaunch() {
        let defaults = makeDefaults()
        defaults.set(SoundPackManager.customPackID, forKey: "settings.selectedSoundPackID")

        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.selectedSoundPackID, SoundPackManager.defaultPackID)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "SquishMacTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
