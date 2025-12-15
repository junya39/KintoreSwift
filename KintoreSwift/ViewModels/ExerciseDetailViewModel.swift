//  ExerciseDetailViewModel.swift


import Foundation
import Combine

class ExerciseDetailViewModel: ObservableObject {

    @Published var history: [SetEntry] = []

    func load(exercise: String) {
        history = DatabaseManager.shared.fetchSetsByExercise(exercise)
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            let entry = history[index]
            DatabaseManager.shared.delete(id: entry.id)
        }
        history.remove(atOffsets: offsets)
    }

    var totalVolume: Double {
        history.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    var max1RM: Double {
        history.map {
            $0.weight * (1 + Double($0.reps) / 30)
        }.max() ?? 0
    }
}
