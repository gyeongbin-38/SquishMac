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
        store.selectedSlimeMaterialProfileID = "clear"
        store.isHapticFeedbackEnabled = false
        store.isSystemGestureGuardEnabled = false

        let restored = SettingsStore(defaults: defaults)

        XCTAssertEqual(restored.trackpadMode, .twoThumbWaxCrush)
        XCTAssertEqual(restored.trackpadResponse, 1.4, accuracy: 0.0001)
        XCTAssertEqual(restored.trackpadSoundDensity, 1.6, accuracy: 0.0001)
        XCTAssertEqual(restored.selectedSlimeMaterialProfileID, "clear")
        XCTAssertFalse(restored.isHapticFeedbackEnabled)
        XCTAssertFalse(restored.isSystemGestureGuardEnabled)
    }

    func testUnknownSlimeProfileFallsBackToDoctorPutty() {
        let defaults = makeDefaults()
        defaults.set("missing-slime", forKey: "settings.selectedSlimeMaterialProfileID")

        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(
            store.selectedSlimeMaterialProfileID,
            SlimeMaterialProfile.defaultSlimeProfileID
        )
        XCTAssertEqual(
            store.selectedSlimeMaterialProfile.interactionRules,
            SlimeInteractionRules.doctorPutty
        )
    }

    func testProfileTrackpadTuningIsAppliedAsAUserAdjustableMultiplier() throws {
        let store = SettingsStore(defaults: makeDefaults())
        store.trackpadResponse = 1.10
        store.trackpadSoundDensity = 0.90
        let profile = try XCTUnwrap(
            SlimeMaterialProfile.builtIn.first { $0.id == "clear-video-3" }
        )

        let tuning = store.trackpadTuning(for: profile)

        XCTAssertEqual(tuning.response, 1.056, accuracy: 0.0001)
        XCTAssertEqual(tuning.soundDensity, 0.972, accuracy: 0.0001)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "SquishMacTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
