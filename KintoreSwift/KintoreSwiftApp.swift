//  KintoreSwiftApp.swift

import SwiftUI
import AVFoundation
import UserNotifications

@main
struct KintoreSwiftApp: App {
    @StateObject private var userStatusVM = UserStatusViewModel()
    @StateObject private var monsterManager = MonsterManager()
    @StateObject private var workoutTimerVM = IntervalTimerViewModel()
    @StateObject private var authVM = AuthViewModel()

    init() {
        configureAudioSession()
        configureNotifications()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userStatusVM)
                .environmentObject(monsterManager)
                .environmentObject(workoutTimerVM)
                .environmentObject(authVM)
                .task {
                    // 起動時にKeychainのトークンを検証してログイン状態を復元する
                    await authVM.restoreSession()
                }
        }
    }

    private func configureAudioSession() {
        TimerAudioSession.configure()
    }

    private func configureNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = TimerNotificationDelegate.shared
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("Notification permission error: \(error)")
            }
            print("Notification permission request completed: granted=\(granted)")
            center.getNotificationSettings { settings in
                print(
                    "Notification settings: status=\(settings.authorizationStatus.kintoreDebugDescription), sound=\(settings.soundSetting.kintoreDebugDescription), alert=\(settings.alertSetting.kintoreDebugDescription)"
                )
            }
        }
    }
}

enum TimerAudioSession {
    private static var isConfigured = false

    static func configure() {
        let session = AVAudioSession.sharedInstance()

        do {
            if session.category != .playback || !session.categoryOptions.contains(.mixWithOthers) {
                // Keep timer sounds audible in silent mode without interrupting external music.
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            }

            guard isConfigured == false else { return }
            try session.setActive(true)
            isConfigured = true
        } catch {
            print("AudioSession setup failed: \(error)")
        }
    }
}

enum TimerNotificationConstants {
    static let requestId = "workout_timer"
}

enum TimerCompletionSound {
    static let fileName = "kintore_timer_competition.wav"

    static var bundleURL: URL? {
        Bundle.main.url(forResource: fileName, withExtension: nil)
    }

    static var notificationSound: UNNotificationSound {
        UNNotificationSound(named: UNNotificationSoundName(rawValue: fileName))
    }

    static func logBundleAvailability(context: String) {
        if let url = bundleURL {
            print("IntervalTimer sound bundle check: context=\(context), fileName=\(fileName), url=\(url.path), exists=\(FileManager.default.fileExists(atPath: url.path))")
        } else {
            print("IntervalTimer sound bundle check failed: context=\(context), fileName=\(fileName), reason=Bundle.main.url returned nil")
        }
    }
}

private final class TimerNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = TimerNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.identifier == TimerNotificationConstants.requestId {
            print("Timer notification willPresent in foreground: banner only, notification sound suppressed")
            completionHandler([.banner])
            return
        }

        completionHandler([.banner, .sound])
    }
}

extension UNAuthorizationStatus {
    var kintoreDebugDescription: String {
        switch self {
        case .notDetermined:
            return "notDetermined"
        case .denied:
            return "denied"
        case .authorized:
            return "authorized"
        case .provisional:
            return "provisional"
        case .ephemeral:
            return "ephemeral"
        @unknown default:
            return "unknown"
        }
    }
}

extension UNNotificationSetting {
    var kintoreDebugDescription: String {
        switch self {
        case .notSupported:
            return "notSupported"
        case .disabled:
            return "disabled"
        case .enabled:
            return "enabled"
        @unknown default:
            return "unknown"
        }
    }
}
