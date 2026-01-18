//ContentViewModel.swift

import SwiftUI
import Foundation

final class ContentViewModel: ObservableObject {
    @Published var entries: [SetEntry] = []
    @Published var exercises: [String: [String]] = [:]
    @Published var dailyEntries: [SetEntry] = []
    @Published var diffText: String = ""
    @Published var diffColor: Color = .secondary
    @Published var chartGrouping: GroupingType = .day
    func loadInitialData() {
        DatabaseManager.shared.createExerciseTableIfNeeded()
        exercises = DatabaseManager.shared.fetchExercisesByBodyPart()
        entries = DatabaseManager.shared.fetchAll()
    }
    
    // MARK: - Write / Update Actions (View から呼ばれる入口)

    func addSet(
        date: Date,
        bodyPart: String,
        exercise: String,
        weight: Double,
        reps: Int,
        note: String?,
        side: String
    ) {
        DatabaseManager.shared.insert(
            date: date,
            bodyPart: bodyPart,
            exercise: exercise,
            weight: weight,
            reps: reps,
            note: note,
            side: side
        )

        reloadAfterChange(
            selectedDate: date,
            selectedExercise: exercise
        )
    }

    func deleteSet(
        _ entry: SetEntry,
        selectedDate: Date,
        selectedExercise: String
    ) {
        DatabaseManager.shared.delete(id: entry.id)

        reloadAfterChange(
            selectedDate: selectedDate,
            selectedExercise: selectedExercise
        )
    }

    func updateExercise(
        oldName: String,
        newName: String,
        newBodyPart: String
    ) {
        DatabaseManager.shared.updateExercise(
            name: oldName,
            newName: newName,
            newBodyPart: newBodyPart
        )

        exercises = DatabaseManager.shared.fetchExercisesByBodyPart()
    }

    // MARK: - 共通更新処理

    private func reloadAfterChange(
        selectedDate: Date,
        selectedExercise: String
    ) {
        entries = DatabaseManager.shared.fetchAll()
        updateDailyEntries(for: selectedDate)
        updateLastDiff(for: selectedExercise)
    }


    func updateDailyEntries(for selectedDate: Date) {
        dailyEntries = entries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    func updateLastDiff(for selectedExercise: String) {
        let recs = DatabaseManager.shared.fetchLastTwoRecords(for: selectedExercise)
        guard recs.count == 2 else {
            diffText = recs.count == 1 ? "前回記録なし" : ""
            diffColor = .secondary
            return
        }
        let latest = recs[0]
        let prev = recs[1]
        let wDiff = Int(latest.weight - prev.weight)
        let rDiff = latest.reps - prev.reps
        diffText = "前回比: \(wDiff >= 0 ? "+" : "")\(wDiff)kg / \(rDiff >= 0 ? "+" : "")\(rDiff)回"
        diffColor = (wDiff > 0 || rDiff > 0) ? .green : ((wDiff < 0 || rDiff < 0) ? .red : .gray)
    }
    
    func lastSetText(for exercise: String) -> String? {
        let items = entries
            .filter { $0.exercise == exercise }
            .sorted { $0.date > $1.date }

        guard let last = items.first else { return nil }

        if last.weight > 0 {
            return "\(Int(last.weight))kg × \(last.reps)回"
        } else {
            return "\(last.reps)回"
        }
    }

}

