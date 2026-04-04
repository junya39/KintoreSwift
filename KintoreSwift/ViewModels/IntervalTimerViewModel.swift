import Foundation
import Combine
import UIKit
import UserNotifications

final class IntervalTimerViewModel: ObservableObject {
    @Published var remainingSeconds: Int
    @Published var isRunning: Bool = false
    @Published var duration: Int {
        didSet { persistState() }
    }

    private var timer: AnyCancellable?
    private(set) var endDate: Date?
    private let timerNotificationId = "workout_timer"
    private let defaults = UserDefaults.standard
    private let durationKey = "workout_timer_duration"
    private let remainingSecondsKey = "workout_timer_remaining_seconds"
    private let endDateKey = "workout_timer_end_date"
    private let isRunningKey = "workout_timer_is_running"

    init(duration: Int = 120) {
        let storedDuration = defaults.object(forKey: durationKey) as? Int
        let restoredDuration = max(1, storedDuration ?? duration)
        self.duration = restoredDuration
        self.remainingSeconds = restoredDuration
        restoreState()
    }

    func start() {
        let seconds = remainingSeconds > 0 ? remainingSeconds : duration
        remainingSeconds = seconds
        endDate = Date().addingTimeInterval(TimeInterval(seconds))
        persistState()
        startTimer()
    }

    func remainingTime() -> Int {
        guard let endDate else { return 0 }
        return max(0, Int(endDate.timeIntervalSinceNow))
    }

    func startTimerIfNeeded() {
        restoreState()
        guard endDate != nil else { return }
        startTimer()
    }

    private func startTimer() {
        timer?.cancel()
        timer = nil
        let seconds = remainingTime()
        remainingSeconds = seconds
        guard seconds > 0 else {
            stop(cancelNotification: false)
            return
        }
        isRunning = true
        persistState()
        scheduleTimerNotification(seconds: seconds)
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.endDate != nil else {
                    self.stop(cancelNotification: false)
                    return
                }

                self.remainingSeconds = self.remainingTime()
                self.persistState()

                if self.remainingSeconds == 0 {
                    self.stop(cancelNotification: false)
                    let generator = UINotificationFeedbackGenerator()
                    generator.prepare()
                    generator.notificationOccurred(.warning)
                }
            }
    }

    func stop(cancelNotification: Bool = true) {
        remainingSeconds = remainingTime()
        timer?.cancel()
        timer = nil
        isRunning = false
        endDate = nil
        persistState()
        if cancelNotification {
            cancelTimerNotification()
        }
    }

    func reset() {
        stop()
        endDate = nil
        remainingSeconds = duration
        persistState()
    }

    private func restoreState() {
        let storedRemainingSeconds = defaults.object(forKey: remainingSecondsKey) as? Int
        let storedIsRunning = defaults.bool(forKey: isRunningKey)

        if let storedEndDate = defaults.object(forKey: endDateKey) as? Date {
            endDate = storedEndDate
            let seconds = max(0, Int(storedEndDate.timeIntervalSinceNow))
            remainingSeconds = seconds
            if seconds == 0 {
                isRunning = false
                endDate = nil
                persistState()
            } else {
                isRunning = storedIsRunning
            }
            return
        }

        endDate = nil
        isRunning = false
        remainingSeconds = max(0, storedRemainingSeconds ?? duration)
    }

    private func persistState() {
        defaults.set(duration, forKey: durationKey)
        defaults.set(remainingSeconds, forKey: remainingSecondsKey)
        defaults.set(isRunning, forKey: isRunningKey)
        defaults.set(endDate, forKey: endDateKey)
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
