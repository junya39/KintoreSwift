//  KintoreSwiftApp.swift

import SwiftUI

@main
struct KintoreSwiftApp: App {
    @StateObject private var userStatusVM = UserStatusViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userStatusVM)
        }
    }
}
