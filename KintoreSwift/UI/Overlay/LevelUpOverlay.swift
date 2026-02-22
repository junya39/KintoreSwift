import SwiftUI
import AVFoundation
import UIKit

struct LevelUpOverlay: View {
    let level: Int
    let fanfareVolume: Float
    let onComplete: () -> Void

    @State private var backgroundOpacity: Double = 0.0
    @State private var levelScale: CGFloat = 0.3
    @State private var levelOpacity: Double = 0.0
    @State private var statusOpacity: Double = 0.0
    @State private var contentOpacity: Double = 1.0
    @State private var player: AVAudioPlayer?

    init(level: Int, fanfareVolume: Float = 0.9, onComplete: @escaping () -> Void = {}) {
        self.level = level
        self.fanfareVolume = fanfareVolume
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(0.85 * backgroundOpacity)
                .ignoresSafeArea()

            // Future particle effects can be added here without changing callers.
            VStack(spacing: 16) {
                Text("LEVEL UP")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))

                Text("Lv \(level)")
                    .font(.system(size: 92, weight: .black, design: .rounded))
                    .foregroundStyle(.yellow)
                    .shadow(color: .yellow.opacity(0.95), radius: 26)
                    .shadow(color: .black.opacity(0.45), radius: 14, x: 0, y: 8)
                    .scaleEffect(levelScale)
                    .opacity(levelOpacity)

                VStack(spacing: 6) {
                    Text("ALL STATS UP")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("POWER +2   ENDURANCE +2")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.yellow)
                }
                .opacity(statusOpacity)
            }
            .padding(.horizontal, 20)
            .opacity(contentOpacity)
        }
        .allowsHitTesting(false)
        .onAppear {
            triggerHaptic()
            playFanfareIfAvailable()
            runAnimationSequence()
        }
    }

    private func playFanfareIfAvailable() {
        guard let url = Bundle.main.url(forResource: "levelup_fanfare", withExtension: "wav") else { return }
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.volume = fanfareVolume
            audioPlayer.prepareToPlay()
            audioPlayer.play()
            player = audioPlayer
        } catch {
            // Keep overlay animation functional even if audio fails.
        }
    }

    private func runAnimationSequence() {
        withAnimation(.easeOut(duration: 0.16)) {
            backgroundOpacity = 1.0
        }

        withAnimation(.spring(response: 0.48, dampingFraction: 0.68)) {
            levelScale = 1.2
            levelOpacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeIn(duration: 0.2)) {
                statusOpacity = 1.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.25)) {
                contentOpacity = 0.0
                backgroundOpacity = 0.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.25) {
            onComplete()
        }
    }

    private func triggerHaptic() {
        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
    }
}
