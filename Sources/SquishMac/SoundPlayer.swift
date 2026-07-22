import AVFoundation
import Combine
import Foundation

struct AudioPlaybackResponse: Equatable {
    let packID: String
    let volume: Float
    let rate: Float
}

enum AudioResponseCurve {
    static func interaction(
        kind: TrackpadSoundKind,
        intensity: Double,
        masterVolume: Double
    ) -> AudioPlaybackResponse {
        let safeIntensity = intensity.clamped(to: 0.0...1.0)
        let safeMasterVolume = masterVolume.clamped(to: 0.0...1.0)
        let packID: String
        let rate: Float
        let volumeBoost: Double

        switch kind {
        case .slimeKnead:
            packID = "slime"
            rate = Float(0.82 + safeIntensity * 0.34)
            volumeBoost = 0.00
        case .slimeStretch:
            packID = "slime"
            rate = Float(0.64 + safeIntensity * 0.26)
            volumeBoost = -0.04
        case .slimeRelease:
            packID = "pop"
            rate = Float(0.92 + safeIntensity * 0.24)
            volumeBoost = -0.06
        case .waxPress:
            packID = "squishy"
            rate = Float(0.70 + safeIntensity * 0.28)
            volumeBoost = -0.10
        case .waxCrack:
            packID = "wax"
            rate = Float(0.88 + safeIntensity * 0.34)
            volumeBoost = -0.02
        case .waxCrush:
            packID = "wax"
            rate = Float(0.76 + safeIntensity * 0.58)
            volumeBoost = 0.06
        }

        let shapedVolume = (0.18 + safeIntensity * 0.82 + volumeBoost).clamped(to: 0.05...1.0)
        return AudioPlaybackResponse(
            packID: packID,
            volume: Float(shapedVolume * safeMasterVolume),
            rate: rate
        )
    }

    static func impactVolume(
        impactStrength: Double,
        sensitivity: Double,
        masterVolume: Double
    ) -> Float {
        let safeSensitivity = max(sensitivity, 0.01)
        let normalized = ((impactStrength - safeSensitivity) / (safeSensitivity * 3.0))
            .clamped(to: 0.0...1.0)
        let shaped = pow(normalized, 0.65)
        return Float((0.22 + shaped * 0.78) * masterVolume.clamped(to: 0.0...1.0))
    }
}

struct SoundVariationSelector {
    private var bags: [String: [URL]] = [:]
    private var sourceSets: [String: Set<URL>] = [:]
    private var lastURLByKey: [String: URL] = [:]

    mutating func nextURL(from urls: [URL], key: String) -> URL? {
        guard !urls.isEmpty else {
            return nil
        }

        let currentSourceSet = Set(urls)
        if sourceSets[key] != currentSourceSet {
            sourceSets[key] = currentSourceSet
            bags[key] = []
        }

        if bags[key]?.isEmpty != false {
            var nextBag = urls.shuffled()
            if nextBag.count > 1,
               let lastURL = lastURLByKey[key],
               nextBag.last == lastURL,
               let replacementIndex = nextBag.indices.first(where: { nextBag[$0] != lastURL }) {
                nextBag.swapAt(replacementIndex, nextBag.index(before: nextBag.endIndex))
            }
            bags[key] = nextBag
        }

        guard let selectedURL = bags[key]?.removeLast() else {
            return nil
        }

        lastURLByKey[key] = selectedURL
        return selectedURL
    }

    mutating func reset() {
        bags.removeAll()
        sourceSets.removeAll()
        lastURLByKey.removeAll()
    }
}

final class SoundPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var lastPlaybackError: String?
    @Published private(set) var lastPlayedFileName: String?

    private let packManager: SoundPackManager
    private var activePlayers: [AVAudioPlayer] = []
    private var variationSelector = SoundVariationSelector()
    private var audioDataCache: [URL: Data] = [:]
    private var cacheOrder: [URL] = []
    private let maxActivePlayers = 10
    private let maximumCachedFiles = 48

    init(packManager: SoundPackManager) {
        self.packManager = packManager
        super.init()
    }

    @discardableResult
    func playRandomSound(
        packID: String,
        customDirectoryPath: String?,
        impactStrength: Double,
        sensitivity: Double,
        masterVolume: Double = 1.0
    ) -> Bool {
        let urls = packManager.soundURLs(for: packID, customDirectoryPath: customDirectoryPath)
        let volume = AudioResponseCurve.impactVolume(
            impactStrength: impactStrength,
            sensitivity: sensitivity,
            masterVolume: masterVolume
        )
        return playRandomURL(urls, key: packID, volume: volume, rate: 1.0)
    }

    @discardableResult
    func playInteractionSound(
        kind: TrackpadSoundKind,
        intensity: Double,
        masterVolume: Double = 1.0
    ) -> Bool {
        let response = AudioResponseCurve.interaction(
            kind: kind,
            intensity: intensity,
            masterVolume: masterVolume
        )
        let urls = packManager.soundURLs(for: response.packID, customDirectoryPath: nil)
        let rateVariation = Float.random(in: -0.025...0.025)
        return playRandomURL(
            urls,
            key: response.packID,
            volume: response.volume,
            rate: (response.rate + rateVariation).clamped(to: 0.5...1.5)
        )
    }

    @discardableResult
    func playPreview(
        packID: String,
        customDirectoryPath: String?,
        sensitivity: Double,
        masterVolume: Double = 1.0
    ) -> Bool {
        playRandomSound(
            packID: packID,
            customDirectoryPath: customDirectoryPath,
            impactStrength: sensitivity * 2.2,
            sensitivity: sensitivity,
            masterVolume: masterVolume
        )
    }

    func stopAll() {
        activePlayers.forEach { $0.stop() }
        activePlayers.removeAll()
    }

    func clearPlaybackError() {
        lastPlaybackError = nil
    }

    private func playRandomURL(_ urls: [URL], key: String, volume: Float, rate: Float) -> Bool {
        guard volume > 0.001 else {
            return false
        }

        guard let url = variationSelector.nextURL(from: urls, key: key) else {
            reportError("No playable sounds were found for this sound pack.")
            return false
        }

        do {
            let player = try AVAudioPlayer(data: audioData(for: url))
            player.delegate = self
            player.enableRate = true
            player.rate = rate
            player.volume = volume
            player.prepareToPlay()

            guard player.play() else {
                reportError("macOS could not start audio playback for \(url.lastPathComponent).")
                return false
            }

            activePlayers.append(player)
            trimActivePlayersIfNeeded()
            lastPlaybackError = nil
            lastPlayedFileName = url.lastPathComponent
            return true
        } catch {
            reportError("Could not play \(url.lastPathComponent): \(error.localizedDescription)")
            return false
        }
    }

    private func audioData(for url: URL) throws -> Data {
        if let cachedData = audioDataCache[url] {
            return cachedData
        }

        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        audioDataCache[url] = data
        cacheOrder.append(url)

        if cacheOrder.count > maximumCachedFiles {
            let evictedURL = cacheOrder.removeFirst()
            audioDataCache.removeValue(forKey: evictedURL)
        }

        return data
    }

    private func trimActivePlayersIfNeeded() {
        guard activePlayers.count > maxActivePlayers else {
            return
        }

        let overflow = activePlayers.count - maxActivePlayers
        activePlayers.prefix(overflow).forEach { $0.stop() }
        activePlayers.removeFirst(overflow)
    }

    private func reportError(_ message: String) {
        lastPlaybackError = message
        NSLog("SquishMac audio: \(message)")
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        activePlayers.removeAll { $0 === player }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
