import Foundation
import AVFoundation
import Combine
import UIKit
import UserNotifications

final class IntervalTimerViewModel: ObservableObject {
    @Published private(set) var remainingSeconds: Int
    @Published var isRunning: Bool = false
    @Published private(set) var duration: Int

    private var timer: AnyCancellable?
    private var audioPlayer: AVAudioPlayer?
    private var endDate: Date?
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var wasAwayFromForeground = false
    private var didExpireWhileInactive = false
    private var shouldSuppressNextInAppCompletionSound = false
    private var hasHandledCurrentTimerCompletion = false
    private let timerNotificationId = TimerNotificationConstants.requestId
    private let userDefaults: UserDefaults

    private enum Defaults {
        static let selectedDurationSecondsKey = "intervalTimer.selectedDurationSeconds"
        static let fallbackDurationSeconds = 90
    }

    init(
        duration defaultDuration: Int = Defaults.fallbackDurationSeconds,
        userDefaults: UserDefaults = .standard
    ) {
        self.userDefaults = userDefaults

        let savedDuration = userDefaults.object(
            forKey: Defaults.selectedDurationSecondsKey
        ) as? Int
        let initialDuration = max(1, savedDuration ?? defaultDuration)
        self.duration = initialDuration
        self.remainingSeconds = initialDuration
        observeAppLifecycle()
    }

    deinit {
        lifecycleObservers.forEach(NotificationCenter.default.removeObserver)
    }

    func start() {
        guard isRunning == false else { return }
        if remainingSeconds == 0 {
            remainingSeconds = duration
        }
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        wasAwayFromForeground = false
        didExpireWhileInactive = false
        shouldSuppressNextInAppCompletionSound = false
        hasHandledCurrentTimerCompletion = false
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
        if isRunning, remainingSeconds == 0 {
            completeTimer(playSound: shouldPlayCompletionSound())
            return
        }

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
                    self.completeTimer(playSound: self.shouldPlayCompletionSound())
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

    func updateDuration(_ seconds: Int) {
        guard seconds > 0 else { return }

        duration = seconds
        userDefaults.set(seconds, forKey: Defaults.selectedDurationSecondsKey)

        guard isRunning == false else { return }
        remainingSeconds = seconds
    }

    private func refreshRemainingSeconds() {
        remainingSeconds = remainingTime()
    }

    private func observeAppLifecycle() {
        let center = NotificationCenter.default

        lifecycleObservers.append(
            center.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.markTimerInactive()
            }
        )

        lifecycleObservers.append(
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.markTimerInactive()
            }
        )

        lifecycleObservers.append(
            center.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleAppDidBecomeActive()
            }
        )
    }

    private func markTimerInactive() {
        guard isRunning else { return }
        wasAwayFromForeground = true
    }

    private func handleAppDidBecomeActive() {
        guard isRunning else {
            wasAwayFromForeground = false
            return
        }

        if let endDate, Date() >= endDate {
            didExpireWhileInactive = wasAwayFromForeground
            shouldSuppressNextInAppCompletionSound = wasAwayFromForeground
            remainingSeconds = 0
            completeTimer(playSound: false)
            return
        }

        refreshRemainingSeconds()

        if remainingSeconds == 0 {
            completeTimer(playSound: shouldPlayCompletionSound())
        } else {
            wasAwayFromForeground = false
            shouldSuppressNextInAppCompletionSound = false
            startTimerIfNeeded()
        }
    }

    private func shouldPlayCompletionSound() -> Bool {
        UIApplication.shared.applicationState == .active
            && wasAwayFromForeground == false
            && didExpireWhileInactive == false
            && shouldSuppressNextInAppCompletionSound == false
    }

    private func completeTimer(playSound: Bool) {
        guard hasHandledCurrentTimerCompletion == false else { return }
        hasHandledCurrentTimerCompletion = true

        let shouldPlayInAppSound = playSound && shouldSuppressNextInAppCompletionSound == false
        stop(cancelNotification: shouldPlayInAppSound)

        guard shouldPlayInAppSound else { return }

        playTimerSoundIfAvailable()
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
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
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [timerNotificationId])
        center.removeDeliveredNotifications(withIdentifiers: [timerNotificationId])
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
