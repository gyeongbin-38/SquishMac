import AppKit
import AVFoundation
import Foundation

final class SoundPlayer: NSObject, AVAudioPlayerDelegate {
    private let packManager: SoundPackManager
    private var activePlayers: [AVAudioPlayer] = []

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
        playRandomURL(urls, volume: volume(for: impactStrength, sensitivity: sensitivity), rate: 1.0)
    }

    func playInteractionSound(kind: TrackpadSoundKind, intensity: Double) {
        let packID: String
        let rate: Float

        switch kind {
        case .slimeKnead:
            packID = "slime"
            rate = Float(0.82 + intensity.clamped(to: 0.0...1.0) * 0.34)
        case .waxCrush:
            packID = "wax"
            rate = Float(0.76 + intensity.clamped(to: 0.0...1.0) * 0.58)
        }

        let urls = packManager.soundURLs(for: packID, customDirectoryPath: nil)
        let volume = Float(0.18 + intensity.clamped(to: 0.0...1.0) * 0.82)
        playRandomURL(urls, volume: volume, rate: rate)
    }

    private func playRandomURL(_ urls: [URL], volume: Float, rate: Float) {
        guard let url = urls.randomElement() else {
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
            player.play()
        } catch {
            NSSound.beep()
            NSLog("SquishMac could not play sound: \(error.localizedDescription)")
        }
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
