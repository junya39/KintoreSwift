//ContentView.swift

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            WorkoutView()
                .tabItem {
                    Label("Workout", systemImage: "dumbbell.fill")
                }

            LevelView()
                .tabItem {
                    Label("Level", systemImage: "chart.bar.fill")
                }
        }
    }
}
