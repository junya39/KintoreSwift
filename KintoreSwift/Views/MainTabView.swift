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

            MonsterDexView()
                .tabItem {
                    Image(systemName: "square.grid.2x2")
                    Text("Dex")
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
