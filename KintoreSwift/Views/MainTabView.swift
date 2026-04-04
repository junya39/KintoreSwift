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
        .overlay {
            if let event = userStatusVM.evolutionEvent {
                EvolutionOverlayView(
                    event: event,
                    imageNames: evolutionImageNames(for: event)
                )
                .transition(.opacity)
                .zIndex(999)
            }
        }
        .onChange(of: userStatusVM.evolutionEvent) { _, newValue in
            guard let newValue else { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if userStatusVM.evolutionEvent == newValue {
                    userStatusVM.evolutionEvent = nil
                }
            }
        }
    }
}
