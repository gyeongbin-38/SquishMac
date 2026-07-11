import AppKit
import AVFoundation
import Foundation

final class SoundPlayer: NSObject, AVAudioPlayerDelegate {
    private let packManager: SoundPackManager
    private var activePlayers: [AVAudioPlayer] = []
    private var lastURLByPack: [String: URL] = [:]
    private let maxActivePlayers = 10

    init(packManager: SoundPackManager) {
        self.packManager = packManager
        super.init()
    }

    func playRandomSound(
        packID: String,
        customDirectoryPath: String?,
        impactStrength: Double,
        sensitivity: Double
    ) {
        let urls = packManager.soundURLs(for: packID, customDirectoryPath: customDirectoryPath)
        playRandomURL(urls, packID: packID, volume: volume(for: impactStrength, sensitivity: sensitivity), rate: 1.0)
    }

    func playInteractionSound(kind: TrackpadSoundKind, intensity: Double) {
        let packID: String
        let rate: Float
        let volumeBoost: Double

        switch kind {
        case .slimeKnead:
            packID = "slime"
            rate = Float(0.82 + intensity.clamped(to: 0.0...1.0) * 0.34)
            volumeBoost = 0.00
        case .slimeStretch:
            packID = "slime"
            rate = Float(0.64 + intensity.clamped(to: 0.0...1.0) * 0.26)
            volumeBoost = -0.04
        case .slimeRelease:
            packID = "pop"
            rate = Float(0.92 + intensity.clamped(to: 0.0...1.0) * 0.24)
            volumeBoost = -0.06
        case .waxPress:
            packID = "squishy"
            rate = Float(0.70 + intensity.clamped(to: 0.0...1.0) * 0.28)
            volumeBoost = -0.10
        case .waxCrack:
            packID = "wax"
            rate = Float(0.88 + intensity.clamped(to: 0.0...1.0) * 0.34)
            volumeBoost = -0.02
        case .waxCrush:
            packID = "wax"
            rate = Float(0.76 + intensity.clamped(to: 0.0...1.0) * 0.58)
            volumeBoost = 0.06
        }

        let urls = packManager.soundURLs(for: packID, customDirectoryPath: nil)
        let volume = Float((0.18 + intensity.clamped(to: 0.0...1.0) * 0.82 + volumeBoost).clamped(to: 0.05...1.0))
        playRandomURL(urls, packID: packID, volume: volume, rate: rate)
    }

    private func playRandomURL(_ urls: [URL], packID: String? = nil, volume: Float, rate: Float) {
        guard let url = nextURL(from: urls, packID: packID) else {
            NSSound.beep()
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.enableRate = true
            player.rate = rate
            player.volume = volume
            player.prepareToPlay()
            activePlayers.append(player)
            trimActivePlayersIfNeeded()
            player.play()
        } catch {
            NSSound.beep()
            NSLog("SquishMac could not play sound: \(error.localizedDescription)")
        }
    }

    private func nextURL(from urls: [URL], packID: String?) -> URL? {
        guard !urls.isEmpty else {
            return nil
        }

        let candidates: [URL]
        if let packID, urls.count > 1, let lastURL = lastURLByPack[packID] {
            candidates = urls.filter { $0 != lastURL }
        } else {
            candidates = urls
        }

        guard let selectedURL = candidates.randomElement() ?? urls.randomElement() else {
            return nil
        }

        if let packID {
            lastURLByPack[packID] = selectedURL
        }

        return selectedURL
    }

    private func trimActivePlayersIfNeeded() {
        guard activePlayers.count > maxActivePlayers else {
            return
        }

        let overflow = activePlayers.count - maxActivePlayers
        activePlayers.prefix(overflow).forEach { $0.stop() }
        activePlayers.removeFirst(overflow)
    }

    func playPreview(packID: String, customDirectoryPath: String?, sensitivity: Double) {
        playRandomSound(
            packID: packID,
            customDirectoryPath: customDirectoryPath,
            impactStrength: sensitivity * 2.2,
            sensitivity: sensitivity
        )
    }

    private func volume(for impactStrength: Double, sensitivity: Double) -> Float {
        let safeSensitivity = max(sensitivity, 0.01)
        let normalized = ((impactStrength - safeSensitivity) / (safeSensitivity * 3.0))
            .clamped(to: 0.0...1.0)
        let shaped = pow(normalized, 0.65)
        return Float(0.22 + shaped * 0.78)
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
