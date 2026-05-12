import Foundation
import AVFoundation
import Combine
import UIKit
import UserNotifications

final class IntervalTimerViewModel: ObservableObject {
    @Published private(set) var remainingSeconds: Int
    @Published var isRunning: Bool = false
    @Published var duration: Int

    private var timer: AnyCancellable?
    private var audioPlayer: AVAudioPlayer?
    private var endDate: Date?
    private let timerNotificationId = "workout_timer"

    init(duration: Int = 90) {
        self.duration = duration
        self.remainingSeconds = duration
    }

    func start() {
        guard isRunning == false else { return }
        if remainingSeconds == 0 {
            remainingSeconds = duration
        }
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        isRunning = true
        startTicker()
        scheduleTimerNotification(seconds: remainingSeconds)
    }

    func remainingTime() -> Int {
        guard let endDate else { return remainingSeconds }
        return max(0, Int(ceil(endDate.timeIntervalSinceNow)))
    }

    func startTimerIfNeeded() {
        refreshRemainingSeconds()
        guard isRunning, timer == nil else { return }
        startTicker()
    }

    private func startTicker() {
        timer?.cancel()
        timer = nil
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshRemainingSeconds()
                if self.remainingSeconds == 0 {
                    self.stop(cancelNotification: false)
                    self.playTimerSoundIfAvailable()
                    let generator = UINotificationFeedbackGenerator()
                    generator.prepare()
                    generator.notificationOccurred(.warning)
                }
            }
    }

    func stop(cancelNotification: Bool = true) {
        refreshRemainingSeconds()
        timer?.cancel()
        timer = nil
        isRunning = false
        endDate = nil
        if cancelNotification {
            cancelTimerNotification()
        }
    }

    func reset() {
        stop()
        remainingSeconds = duration
    }

    private func refreshRemainingSeconds() {
        remainingSeconds = remainingTime()
    }

    private func scheduleTimerNotification(seconds: Int) {
        guard seconds > 0 else { return }

        cancelTimerNotification()

        let content = UNMutableNotificationContent()
        content.title = "タイマー終了"
        content.body = "セットを開始してください"
        content.sound = UNNotificationSound(
            named: UNNotificationSoundName("kintore_timer_competition.wav")
        )

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(seconds),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: timerNotificationId,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Timer notification error: \(error)")
            }
        }
    }

    private func cancelTimerNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [timerNotificationId])
    }

    private func playTimerSoundIfAvailable() {
        guard let url = Bundle.main.url(
            forResource: "kintore_timer_competition",
            withExtension: "wav"
        ) else { return }

        do {
            TimerAudioSession.configure()

            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 1.0
            player.prepareToPlay()
            player.play()
            audioPlayer = player
        } catch {
            print("Timer sound playback error: \(error)")
        }
    }
}
