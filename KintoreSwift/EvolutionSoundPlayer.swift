import Foundation
import AVFoundation

final class EvolutionSoundPlayer {
    static let shared = EvolutionSoundPlayer()

    private var audioPlayer: AVAudioPlayer?

    private init() {}

    func playEvolutionSound() {
        guard let url = Bundle.main.url(forResource: "levelup_fanfare", withExtension: "wav") else {
            print("levelup_fanfare.wav not found")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Failed to play evolution sound: \(error)")
        }
    }
}
