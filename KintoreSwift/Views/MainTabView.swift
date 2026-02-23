//
//  MainTabView.swift


import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var userStatusVM: UserStatusViewModel

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

            LevelView(
                viewModel: LevelViewModel(userStatus: userStatusVM)
            )
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Level")
                }
        }
        .background(Color.black)
    }
}
