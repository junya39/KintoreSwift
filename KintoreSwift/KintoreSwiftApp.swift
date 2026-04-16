//  KintoreSwiftApp.swift

import SwiftUI
import AVFoundation
import UserNotifications

@main
struct KintoreSwiftApp: App {
    @StateObject private var userStatusVM = UserStatusViewModel()
    @StateObject private var monsterManager = MonsterManager()

    init() {
        configureAudioSession()
        configureNotifications()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userStatusVM)
                .environmentObject(monsterManager)
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Keep external music playing while app sound effects play.
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("AudioSession setup failed: \(error)")
        }
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

private final class TimerNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = TimerNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
