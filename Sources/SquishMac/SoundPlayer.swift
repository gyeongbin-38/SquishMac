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

        guard let url = urls.randomElement() else {
            NSSound.beep()
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.volume = volume(for: impactStrength, sensitivity: sensitivity)
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
