//  ExerciseDetailViewModel.swift


import SwiftUI
import Foundation
import Combine

class ExerciseDetailViewModel: ObservableObject {

    private let contentViewModel: ContentViewModel
    private var cancellables = Set<AnyCancellable>()
    private var currentExercise: String?

    var history: [SetEntry] {
        contentViewModel.history
    }

    init(contentViewModel: ContentViewModel) {
        self.contentViewModel = contentViewModel

        contentViewModel.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func load(exercise: String) {
        currentExercise = exercise
        contentViewModel.loadHistory(exercise: exercise)
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            let entry = history[index]
            DatabaseManager.shared.delete(id: entry.id)
        }
        reloadHistoryIfPossible()
    }

    func delete(entry: SetEntry) {
        DatabaseManager.shared.delete(id: entry.id)
        reloadHistoryIfPossible()
    }

    var totalVolume: Double {
        history.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    var max1RM: Double {
        history.map {
            $0.weight * (1 + Double($0.reps) / 30)
        }.max() ?? 0
    }

    // MARK: - View からの追加操作（DB集約）
    func addSet(
        date: Date,
        bodyPart: String,
        exercise: String,
        weight: Double,
        reps: Int,
        note: String?,
        side: String
    ) {
        contentViewModel.addSet(
            date: date,
            bodyPart: bodyPart,
            exercise: exercise,
            weight: weight,
            reps: reps,
            note: note,
            side: side
        )
        contentViewModel.loadHistory(exercise: exercise)
        currentExercise = exercise
    }

    func updateSet(_ entry: SetEntry) {
        DatabaseManager.shared.updateSet(entry)
        reloadHistoryIfPossible()
    }

    func bodyPart(for exercise: String) -> String {
        if let fromHistory = history.first(where: { $0.exercise == exercise })?.bodyPart, !fromHistory.isEmpty {
            return fromHistory
        }
        if let fromMaster = DatabaseManager.shared.fetchBodyPart(for: exercise), !fromMaster.isEmpty {
            return fromMaster
        }
        return "胸"
    }

    private func reloadHistoryIfPossible() {
        guard let exercise = currentExercise else { return }
        contentViewModel.loadHistory(exercise: exercise)
    }
}
