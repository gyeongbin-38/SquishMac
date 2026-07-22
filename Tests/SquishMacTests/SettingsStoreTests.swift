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

    func testUnknownSoundPackFallsBackToDefault() {
        let defaults = makeDefaults()
        defaults.set("missing-pack", forKey: "settings.selectedSoundPackID")

        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.selectedSoundPackID, SoundPackManager.defaultPackID)
    }

    func testNumericSettingsClampAssignedValues() {
        let store = SettingsStore(defaults: makeDefaults())

        store.sensitivity = 10
        store.cooldown = -1
        store.masterVolume = 4
        store.trackpadResponse = 0
        store.trackpadSoundDensity = 8

        XCTAssertEqual(store.sensitivity, SettingsStore.sensitivityRange.upperBound)
        XCTAssertEqual(store.cooldown, SettingsStore.cooldownRange.lowerBound)
        XCTAssertEqual(store.masterVolume, SettingsStore.masterVolumeRange.upperBound)
        XCTAssertEqual(store.trackpadResponse, SettingsStore.trackpadResponseRange.lowerBound)
        XCTAssertEqual(store.trackpadSoundDensity, SettingsStore.soundDensityRange.upperBound)
    }

    func testTrackpadPreferencesPersist() {
        let defaults = makeDefaults()
        let store = SettingsStore(defaults: defaults)
        store.trackpadMode = .twoThumbWaxCrush
        store.trackpadResponse = 1.4
        store.trackpadSoundDensity = 1.6
        store.isHapticFeedbackEnabled = false

        let restored = SettingsStore(defaults: defaults)

        XCTAssertEqual(restored.trackpadMode, .twoThumbWaxCrush)
        XCTAssertEqual(restored.trackpadResponse, 1.4, accuracy: 0.0001)
        XCTAssertEqual(restored.trackpadSoundDensity, 1.6, accuracy: 0.0001)
        XCTAssertFalse(restored.isHapticFeedbackEnabled)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "SquishMacTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
