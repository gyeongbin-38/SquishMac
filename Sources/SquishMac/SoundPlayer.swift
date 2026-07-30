import AVFoundation
import Combine
import Foundation

struct AudioPlaybackResponse: Equatable {
    let packID: String
    let volume: Float
    let rate: Float
}

enum AudioResponseCurve {
    static func referencePackRate(intensity: Double) -> Float {
        Float(0.96 + intensity.clamped(to: 0.0...1.0) * 0.06)
    }

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
        case .slimeBubble:
            packID = "bubble"
            rate = Float(0.74 + safeIntensity * 0.28)
            volumeBoost = 0.02
        case .slimeStretchFailure:
            packID = "pop"
            rate = Float(0.94 + safeIntensity * 0.18)
            volumeBoost = 0.08
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
    private var playbackGeneration = 0
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
        masterVolume: Double = 1.0,
        soundPackIDOverride: String? = nil,
        volumeScale: Double = 1.0,
        secondarySoundLayer: InteractionSoundLayerRules? = nil
    ) -> Bool {
        let safeIntensity = intensity.clamped(to: 0.0...1.0)
        let safeMasterVolume = (
            masterVolume * volumeScale.clamped(to: 0.1...1.0)
        ).clamped(to: 0.0...1.0)
        let response = AudioResponseCurve.interaction(
            kind: kind,
            intensity: safeIntensity,
            masterVolume: safeMasterVolume
        )
        let primaryPackID = soundPackIDOverride ?? response.packID
        let urls = packManager.soundURLs(for: primaryPackID, customDirectoryPath: nil)
        let usesReferencePack = soundPackIDOverride != nil
        let baseRate = usesReferencePack
            ? AudioResponseCurve.referencePackRate(intensity: safeIntensity)
            : response.rate
        let rateVariation = Float.random(
            in: usesReferencePack ? -0.012...0.012 : -0.025...0.025
        )
        let didPlayPrimary = playRandomURL(
            urls,
            key: primaryPackID,
            volume: response.volume,
            rate: (baseRate + rateVariation).clamped(to: 0.5...1.5)
        )
        guard didPlayPrimary else {
            return false
        }

        if let secondarySoundLayer,
           let layerPlan = secondarySoundLayer.plan(
               intensity: safeIntensity,
               probabilitySample: Double.random(in: 0...1),
               delaySample: Double.random(in: 0...1)
           ) {
            let generation = playbackGeneration
            let layerVolume = response.volume * Float(layerPlan.volumeScale)
            let layerRate = (
                baseRate
                    + Float(layerPlan.rateOffset)
                    + Float.random(in: -0.012...0.012)
            ).clamped(to: 0.5...1.5)

            DispatchQueue.main.asyncAfter(
                deadline: .now() + layerPlan.delayMilliseconds / 1_000
            ) { [weak self] in
                guard let self, self.playbackGeneration == generation else {
                    return
                }
                let layerURLs = self.packManager.soundURLs(
                    for: layerPlan.soundPackID,
                    customDirectoryPath: nil
                )
                _ = self.playRandomURL(
                    layerURLs,
                    key: "\(layerPlan.soundPackID):material-layer",
                    volume: layerVolume,
                    rate: layerRate
                )
            }
            return true
        }

        // Reference-derived packs only mix with explicitly configured clips from
        // the same material. Generic layers would change the recorded texture.
        guard !usesReferencePack else {
            return true
        }

        let generation = playbackGeneration
        let recipe = GestureSoundRecipeLibrary.recipe(for: kind)
        for layer in recipe.layers.dropFirst() {
            let probability = (
                layer.probability * (0.62 + safeIntensity * 0.38)
            ).clamped(to: 0.0...1.0)
            guard Double.random(in: 0...1) <= probability else {
                continue
            }

            let volume = Float(
                interpolated(layer.volume, progress: safeIntensity)
                    * safeMasterVolume
            )
            let rate = Float(
                interpolated(layer.playbackRate, progress: safeIntensity)
                    + Double.random(in: -0.025...0.025)
            ).clamped(to: 0.5...1.5)
            let delay = interpolated(
                layer.delayMilliseconds,
                progress: Double.random(in: 0...1)
            ) / 1_000

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.playbackGeneration == generation else {
                    return
                }
                let layerURLs = self.packManager.soundURLs(
                    for: layer.sourcePackID,
                    customDirectoryPath: nil
                )
                _ = self.playRandomURL(
                    layerURLs,
                    key: "\(layer.sourcePackID):\(layer.role)",
                    volume: volume,
                    rate: rate
                )
            }
        }
        return true
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
        playbackGeneration &+= 1
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

    private func interpolated(
        _ range: SoundParameterRange,
        progress: Double
    ) -> Double {
        range.minimum + (range.maximum - range.minimum) * progress.clamped(to: 0.0...1.0)
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
