//  KintoreSwiftApp.swift

import SwiftUI
import AVFoundation

@main
struct KintoreSwiftApp: App {
    @StateObject private var userStatusVM = UserStatusViewModel()

    init() {
        configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userStatusVM)
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
}
