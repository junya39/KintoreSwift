//  ExerciseDetailViewModel.swift


import SwiftUI
import Foundation
import Combine

class ExerciseDetailViewModel: ObservableObject {
    struct Stats {
        let totalReps: Int
        let totalVolume: Double
        let averageWeight: Double
        let maxWeight: Double
        let bodyweightMaxReps: Int
        let bodyweightTotalReps: Int
        let bodyweightSets: Int
    }

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

    var max1RM: Double {
        history.map {
            $0.weight * (1 + Double($0.reps) / 30)
        }.max() ?? 0
    }

    var totalReps: Int {
        stats.totalReps
    }

    var totalVolume: Double {
        stats.totalVolume
    }

    var averageWeight: Double {
        stats.averageWeight
    }

    var maxWeight: Double {
        stats.maxWeight
    }

    var bodyweightMaxReps: Int {
        stats.bodyweightMaxReps
    }

    var bodyweightTotalReps: Int {
        stats.bodyweightTotalReps
    }

    var bodyweightSets: Int {
        stats.bodyweightSets
    }

    var stats: Stats {
        var totalReps = 0
        var totalVolume = 0.0
        var weightedTotal = 0.0
        var weightedCount = 0
        var maxWeight = 0.0
        var bodyweightMaxReps = 0
        var bodyweightTotalReps = 0
        var bodyweightSets = 0

        for entry in history {
            let reps = max(0, entry.reps)
            let weight = max(0, entry.weight)

            totalReps += reps
            totalVolume += weight * Double(reps)

            if weight > 0 {
                weightedTotal += weight
                weightedCount += 1
                maxWeight = max(maxWeight, weight)
            } else {
                bodyweightSets += 1
                bodyweightTotalReps += reps
                bodyweightMaxReps = max(bodyweightMaxReps, reps)
            }
        }

        let averageWeight =
            weightedCount > 0 ? weightedTotal / Double(weightedCount) : 0

        return Stats(
            totalReps: totalReps,
            totalVolume: totalVolume,
            averageWeight: averageWeight,
            maxWeight: maxWeight,
            bodyweightMaxReps: bodyweightMaxReps,
            bodyweightTotalReps: bodyweightTotalReps,
            bodyweightSets: bodyweightSets
        )
    }

    // MARK: - View からの追加操作（DB集約）
    func addSet(
        date: Date,
        bodyPart: String,
        exercise: String,
        weight: Double,
        isBodyweight: Bool,
        reps: Int,
        note: String?,
        side: String
    ) {
        contentViewModel.addSet(
            date: date,
            bodyPart: bodyPart,
            exercise: exercise,
            weight: weight,
            isBodyweight: isBodyweight,
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
