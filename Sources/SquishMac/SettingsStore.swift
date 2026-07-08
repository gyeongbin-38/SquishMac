import Combine
import Foundation

final class SettingsStore: ObservableObject {
    static let sensitivityRange: ClosedRange<Double> = 0.08...1.20
    static let cooldownRange: ClosedRange<Double> = 0.15...3.00

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.isEnabled) }
    }

    @Published var sensitivity: Double {
        didSet { defaults.set(sensitivity.clamped(to: Self.sensitivityRange), forKey: Keys.sensitivity) }
    }

    @Published var cooldown: Double {
        didSet { defaults.set(cooldown.clamped(to: Self.cooldownRange), forKey: Keys.cooldown) }
    }

    @Published var selectedSoundPackID: String {
        didSet { defaults.set(selectedSoundPackID, forKey: Keys.selectedSoundPackID) }
    }

    @Published private(set) var todaysCount: Int {
        didSet { defaults.set(todaysCount, forKey: Keys.todaysCount) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        self.sensitivity = (defaults.object(forKey: Keys.sensitivity) as? Double ?? 0.32)
            .clamped(to: Self.sensitivityRange)
        self.cooldown = (defaults.object(forKey: Keys.cooldown) as? Double ?? 0.80)
            .clamped(to: Self.cooldownRange)
        self.selectedSoundPackID = defaults.string(forKey: Keys.selectedSoundPackID) ?? "bubble"
        self.todaysCount = defaults.integer(forKey: Keys.todaysCount)
        resetDailyCounterIfNeeded()
    }

    func recordPlay() {
        resetDailyCounterIfNeeded()
        todaysCount += 1
    }

    func resetTodayCount() {
        todaysCount = 0
        defaults.set(Self.todayKey(), forKey: Keys.countDate)
    }

    private func resetDailyCounterIfNeeded() {
        let currentKey = Self.todayKey()
        guard defaults.string(forKey: Keys.countDate) != currentKey else {
            return
        }

        todaysCount = 0
        defaults.set(currentKey, forKey: Keys.countDate)
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
    static let sensitivity = "settings.sensitivity"
    static let cooldown = "settings.cooldown"
    static let selectedSoundPackID = "settings.selectedSoundPackID"
    static let todaysCount = "stats.todaysCount"
    static let countDate = "stats.countDate"
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
