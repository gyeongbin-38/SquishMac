import Combine
import Foundation

final class SettingsStore: ObservableObject {
    static let sensitivityRange: ClosedRange<Double> = 0.08...1.20
    static let cooldownRange: ClosedRange<Double> = 0.15...3.00
    static let masterVolumeRange: ClosedRange<Double> = 0.0...1.0
    static let trackpadResponseRange: ClosedRange<Double> = 0.5...1.75
    static let soundDensityRange: ClosedRange<Double> = 0.5...2.0

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.isEnabled) }
    }

    @Published var isImpactDetectionEnabled: Bool {
        didSet { defaults.set(isImpactDetectionEnabled, forKey: Keys.isImpactDetectionEnabled) }
    }

    @Published var isHapticFeedbackEnabled: Bool {
        didSet { defaults.set(isHapticFeedbackEnabled, forKey: Keys.isHapticFeedbackEnabled) }
    }

    @Published var sensitivity: Double {
        didSet {
            let safeValue = sensitivity.clamped(to: Self.sensitivityRange)
            if sensitivity != safeValue {
                sensitivity = safeValue
            }
            defaults.set(safeValue, forKey: Keys.sensitivity)
        }
    }

    @Published var cooldown: Double {
        didSet {
            let safeValue = cooldown.clamped(to: Self.cooldownRange)
            if cooldown != safeValue {
                cooldown = safeValue
            }
            defaults.set(safeValue, forKey: Keys.cooldown)
        }
    }

    @Published var masterVolume: Double {
        didSet {
            let safeValue = masterVolume.clamped(to: Self.masterVolumeRange)
            if masterVolume != safeValue {
                masterVolume = safeValue
            }
            defaults.set(safeValue, forKey: Keys.masterVolume)
        }
    }

    @Published var trackpadMode: TrackpadMode {
        didSet { defaults.set(trackpadMode.rawValue, forKey: Keys.trackpadMode) }
    }

    @Published var trackpadResponse: Double {
        didSet {
            let safeValue = trackpadResponse.clamped(to: Self.trackpadResponseRange)
            if trackpadResponse != safeValue {
                trackpadResponse = safeValue
            }
            defaults.set(safeValue, forKey: Keys.trackpadResponse)
        }
    }

    @Published var trackpadSoundDensity: Double {
        didSet {
            let safeValue = trackpadSoundDensity.clamped(to: Self.soundDensityRange)
            if trackpadSoundDensity != safeValue {
                trackpadSoundDensity = safeValue
            }
            defaults.set(safeValue, forKey: Keys.trackpadSoundDensity)
        }
    }

    @Published var selectedSoundPackID: String {
        didSet {
            guard Self.validSoundPackIDs.contains(selectedSoundPackID) else {
                selectedSoundPackID = SoundPackManager.defaultPackID
                defaults.set(SoundPackManager.defaultPackID, forKey: Keys.selectedSoundPackID)
                return
            }
            if selectedSoundPackID == SoundPackManager.customPackID && customSoundDirectoryPath == nil {
                selectedSoundPackID = SoundPackManager.defaultPackID
                defaults.set(SoundPackManager.defaultPackID, forKey: Keys.selectedSoundPackID)
                return
            }
            defaults.set(selectedSoundPackID, forKey: Keys.selectedSoundPackID)
        }
    }

    @Published var customSoundDirectoryPath: String? {
        didSet {
            if let customSoundDirectoryPath {
                defaults.set(customSoundDirectoryPath, forKey: Keys.customSoundDirectoryPath)
            } else {
                defaults.removeObject(forKey: Keys.customSoundDirectoryPath)
                if selectedSoundPackID == SoundPackManager.customPackID {
                    selectedSoundPackID = SoundPackManager.defaultPackID
                }
            }
        }
    }

    @Published private(set) var launchAtLoginStatus: LaunchAtLoginStatus = .unknown
    @Published private(set) var launchAtLoginError: String?

    @Published private(set) var todaysCount: Int {
        didSet { defaults.set(todaysCount, forKey: Keys.todaysCount) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        self.isImpactDetectionEnabled = defaults.object(forKey: Keys.isImpactDetectionEnabled) as? Bool ?? true
        self.isHapticFeedbackEnabled = defaults.object(forKey: Keys.isHapticFeedbackEnabled) as? Bool ?? true
        self.sensitivity = (defaults.object(forKey: Keys.sensitivity) as? Double ?? 0.32)
            .clamped(to: Self.sensitivityRange)
        self.cooldown = (defaults.object(forKey: Keys.cooldown) as? Double ?? 0.80)
            .clamped(to: Self.cooldownRange)
        self.masterVolume = (defaults.object(forKey: Keys.masterVolume) as? Double ?? 0.85)
            .clamped(to: Self.masterVolumeRange)
        self.trackpadMode = TrackpadMode(
            rawValue: defaults.string(forKey: Keys.trackpadMode) ?? ""
        ) ?? .sixFingerSlime
        self.trackpadResponse = (defaults.object(forKey: Keys.trackpadResponse) as? Double ?? 1.0)
            .clamped(to: Self.trackpadResponseRange)
        self.trackpadSoundDensity = (defaults.object(forKey: Keys.trackpadSoundDensity) as? Double ?? 1.0)
            .clamped(to: Self.soundDensityRange)
        self.selectedSoundPackID = defaults.string(forKey: Keys.selectedSoundPackID) ?? SoundPackManager.defaultPackID
        self.customSoundDirectoryPath = defaults.string(forKey: Keys.customSoundDirectoryPath)
        self.todaysCount = max(0, defaults.integer(forKey: Keys.todaysCount))

        if !Self.validSoundPackIDs.contains(selectedSoundPackID)
            || (selectedSoundPackID == SoundPackManager.customPackID && customSoundDirectoryPath == nil) {
            selectedSoundPackID = SoundPackManager.defaultPackID
            defaults.set(SoundPackManager.defaultPackID, forKey: Keys.selectedSoundPackID)
        }

        resetDailyCounterIfNeeded()
    }

    var trackpadTuning: TrackpadTuning {
        TrackpadTuning(response: trackpadResponse, soundDensity: trackpadSoundDensity)
    }

    var customSoundDirectoryDisplayName: String {
        guard let customSoundDirectoryPath else {
            return "No folder selected"
        }

        return URL(fileURLWithPath: customSoundDirectoryPath).lastPathComponent
    }

    func updateLaunchAtLoginStatus(_ status: LaunchAtLoginStatus, error: String? = nil) {
        launchAtLoginStatus = status
        launchAtLoginError = error
    }

    func recordPlay() {
        resetDailyCounterIfNeeded()
        if todaysCount < Int.max {
            todaysCount += 1
        }
    }

    func resetTodayCount() {
        todaysCount = 0
        defaults.set(Self.todayKey(), forKey: Keys.countDate)
    }

    func resetTrackpadTuning() {
        trackpadResponse = 1.0
        trackpadSoundDensity = 1.0
    }

    private func resetDailyCounterIfNeeded() {
        let currentKey = Self.todayKey()
        guard defaults.string(forKey: Keys.countDate) != currentKey else {
            return
        }

        todaysCount = 0
        defaults.set(currentKey, forKey: Keys.countDate)
    }

    private static var validSoundPackIDs: Set<String> {
        Set(SoundPackManager.packs.map(\.id) + [SoundPackManager.customPackID])
    }

    private static func todayKey(date: Date = Date()) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

private enum Keys {
    static let isEnabled = "settings.isEnabled"
    static let isImpactDetectionEnabled = "settings.isImpactDetectionEnabled"
    static let isHapticFeedbackEnabled = "settings.isHapticFeedbackEnabled"
    static let sensitivity = "settings.sensitivity"
    static let cooldown = "settings.cooldown"
    static let masterVolume = "settings.masterVolume"
    static let trackpadMode = "settings.trackpadMode"
    static let trackpadResponse = "settings.trackpadResponse"
    static let trackpadSoundDensity = "settings.trackpadSoundDensity"
    static let selectedSoundPackID = "settings.selectedSoundPackID"
    static let customSoundDirectoryPath = "settings.customSoundDirectoryPath"
    static let todaysCount = "stats.todaysCount"
    static let countDate = "stats.countDate"
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
