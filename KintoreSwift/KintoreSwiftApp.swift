//  KintoreSwiftApp.swift

import SwiftUI
import AVFoundation
import UserNotifications

@main
struct KintoreSwiftApp: App {
    @StateObject private var userStatusVM = UserStatusViewModel()
    @StateObject private var monsterManager = MonsterManager()
    @StateObject private var workoutTimerVM = IntervalTimerViewModel()

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
        }
    }

    private func configureAudioSession() {
        TimerAudioSession.configure()
    }

    private func configureNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = TimerNotificationDelegate.shared
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                print("Notification permission error: \(error)")
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

private final class TimerNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = TimerNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.identifier == TimerNotificationConstants.requestId {
            completionHandler([.banner])
            return
        }

        completionHandler([.banner, .sound])
    }
}
