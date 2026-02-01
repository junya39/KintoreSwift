//
//  MainTabView.swift


import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }

            WorkoutView()
                .tabItem {
                    Image(systemName: "dumbbell")
                    Text("Workout")
                }

            LevelView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Level")
                }
        }
        .background(Color.black)
    }
}
