import Foundation
import Combine
import UIKit
import UserNotifications

final class IntervalTimerViewModel: ObservableObject {
    @Published var remainingSeconds: Int
    @Published var isRunning: Bool = false
    @Published var duration: Int

    private var timer: AnyCancellable?
    private let timerNotificationId = "workout_timer"

    init(duration: Int = 120) {
        self.duration = duration
        self.remainingSeconds = duration
    }

    func start() {
        stop()
        isRunning = true
        scheduleTimerNotification(seconds: remainingSeconds)
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.remainingSeconds > 0 else {
                    self.stop()
                    return
                }

                self.remainingSeconds -= 1

                if self.remainingSeconds == 0 {
                    self.stop(cancelNotification: false)
                    let generator = UINotificationFeedbackGenerator()
                    generator.prepare()
                    generator.notificationOccurred(.warning)
                }
            }
    }

    func stop(cancelNotification: Bool = true) {
        timer?.cancel()
        timer = nil
        isRunning = false
        if cancelNotification {
            cancelTimerNotification()
        }
    }

    func reset() {
        stop()
        remainingSeconds = duration
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
}
