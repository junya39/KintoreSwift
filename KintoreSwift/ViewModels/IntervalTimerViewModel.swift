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
    private var currentTimerId: String?
    private var completedTimerId: String?
    private var lastCompletionHandledAt: Date?
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
        let timerId = UUID().uuidString
        let scheduledEndDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        currentTimerId = timerId
        endDate = scheduledEndDate
        wasAwayFromForeground = false
        didExpireWhileInactive = false
        shouldSuppressNextInAppCompletionSound = false
        hasHandledCurrentTimerCompletion = false
        completedTimerId = nil
        lastCompletionHandledAt = nil
        isRunning = true
        startTicker()
        print(
            "IntervalTimer start: timerId=\(timerId), duration=\(duration), remaining=\(remainingSeconds), endDate=\(scheduledEndDate), appState=\(applicationStateDescription)"
        )
        checkNotificationAuthorization()
        scheduleTimerNotification(timerId: timerId, endDate: scheduledEndDate)
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
        print(
            "IntervalTimer stop: cancelNotification=\(cancelNotification), timerId=\(currentTimerId ?? "nil"), remainingBeforeRefresh=\(remainingSeconds)"
        )
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
        print(
            "IntervalTimer inactive: timerId=\(currentTimerId ?? "nil"), endDate=\(endDate.map(String.init(describing:)) ?? "nil"), appState=\(applicationStateDescription)"
        )
    }

    private func handleAppDidBecomeActive() {
        print(
            "IntervalTimer didBecomeActive: isRunning=\(isRunning), timerId=\(currentTimerId ?? "nil"), endDate=\(endDate.map(String.init(describing:)) ?? "nil"), appState=\(applicationStateDescription)"
        )
        checkNotificationAuthorization()

        guard isRunning else {
            wasAwayFromForeground = false
            return
        }

        if let endDate, Date() >= endDate {
            didExpireWhileInactive = wasAwayFromForeground
            shouldSuppressNextInAppCompletionSound = wasAwayFromForeground
            remainingSeconds = 0
            print(
                "IntervalTimer expired while returning active: timerId=\(currentTimerId ?? "nil"), wasAwayFromForeground=\(wasAwayFromForeground), suppressInAppSound=\(shouldSuppressNextInAppCompletionSound)"
            )
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
        let finishingTimerId = currentTimerId ?? "unknown"

        guard hasHandledCurrentTimerCompletion == false,
              completedTimerId != finishingTimerId else {
            print(
                "IntervalTimer completion ignored: timerId=\(finishingTimerId), hasHandled=\(hasHandledCurrentTimerCompletion), completedTimerId=\(completedTimerId ?? "nil")"
            )
            return
        }

        hasHandledCurrentTimerCompletion = true
        completedTimerId = finishingTimerId
        lastCompletionHandledAt = Date()

        let shouldPlayInAppSound = playSound && shouldSuppressNextInAppCompletionSound == false
        print(
            "IntervalTimer complete: timerId=\(finishingTimerId), playSoundRequested=\(playSound), shouldPlayInAppSound=\(shouldPlayInAppSound), wasAwayFromForeground=\(wasAwayFromForeground), didExpireWhileInactive=\(didExpireWhileInactive), appState=\(applicationStateDescription)"
        )
        stop(cancelNotification: shouldPlayInAppSound)

        guard shouldPlayInAppSound else {
            print("IntervalTimer in-app sound skipped: timerId=\(finishingTimerId)")
            return
        }

        playTimerSoundIfAvailable()
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    private func scheduleTimerNotification(timerId: String, endDate: Date) {
        let seconds = max(0, endDate.timeIntervalSinceNow)
        guard seconds > 0 else {
            print("IntervalTimer notification skipped: timerId=\(timerId), seconds=\(seconds)")
            return
        }

        cancelTimerNotification()

        let content = UNMutableNotificationContent()
        content.title = "タイマー終了"
        content.body = "セットを開始してください"
        TimerCompletionSound.logBundleAvailability(context: "scheduleNotification")
        content.sound = TimerCompletionSound.notificationSound
        content.userInfo = [
            "timerId": timerId,
            "endDate": endDate.timeIntervalSince1970
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: seconds,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: timerNotificationId,
            content: content,
            trigger: trigger
        )

        print(
            "IntervalTimer notification scheduling: requestId=\(timerNotificationId), timerId=\(timerId), endDate=\(endDate), seconds=\(seconds)"
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("IntervalTimer notification schedule failed: requestId=\(self.timerNotificationId), timerId=\(timerId), error=\(error)")
            } else {
                print("IntervalTimer notification schedule succeeded: requestId=\(self.timerNotificationId), timerId=\(timerId)")
            }
        }
    }

    private func cancelTimerNotification() {
        let center = UNUserNotificationCenter.current()
        print("IntervalTimer notification cancel: requestId=\(timerNotificationId)")
        center.removePendingNotificationRequests(withIdentifiers: [timerNotificationId])
        center.removeDeliveredNotifications(withIdentifiers: [timerNotificationId])
    }

    private func checkNotificationAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print(
                "IntervalTimer notification authorization: status=\(settings.authorizationStatus.kintoreDebugDescription), sound=\(settings.soundSetting.kintoreDebugDescription), alert=\(settings.alertSetting.kintoreDebugDescription)"
            )
        }
    }

    private func playTimerSoundIfAvailable() {
        TimerCompletionSound.logBundleAvailability(context: "inAppPlayback")
        guard let url = TimerCompletionSound.bundleURL else {
            print("IntervalTimer in-app sound skipped: audio file not found, fileName=\(TimerCompletionSound.fileName)")
            return
        }

        do {
            TimerAudioSession.configure()

            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 1.0
            player.prepareToPlay()
            player.play()
            audioPlayer = player
            print("IntervalTimer in-app sound played: fileName=\(TimerCompletionSound.fileName), url=\(url.path)")
        } catch {
            print("Timer sound playback error: fileName=\(TimerCompletionSound.fileName), error=\(error)")
        }
    }

    private var applicationStateDescription: String {
        switch UIApplication.shared.applicationState {
        case .active:
            return "active"
        case .inactive:
            return "inactive"
        case .background:
            return "background"
        @unknown default:
            return "unknown"
        }
    }
}
