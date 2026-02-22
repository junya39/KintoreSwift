//ContentViewModel.swift

import SwiftUI
import Foundation

final class ContentViewModel: ObservableObject {
    enum PostSaveSideAction {
        case switchToLeft
        case switchToRight
        case none
    }

    struct HomeMetrics {
        let totalVolume: Int
        let streakDays: Int
    }

    @Published var entries: [SetEntry] = []
    @Published var exercises: [String: [String]] = [:]
    @Published var dailyEntries: [SetEntry] = []
    @Published var history: [SetEntry] = []
    @Published var diffText: String = ""
    @Published var diffColor: Color = .secondary
    @Published var chartGrouping: GroupingType = .day
    @Published private(set) var deletedExerciseNames: Set<String> = []
    private var pendingRightExercise: String?
    func loadInitialData() {
        DatabaseManager.shared.createExerciseTableIfNeeded()
        DatabaseManager.shared.createDeletedExerciseTableIfNeeded()
        deletedExerciseNames = DatabaseManager.shared.fetchDeletedExerciseNames()
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
        side: String,
        userStatusVM: UserStatusViewModel? = nil
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

        if shouldGrantXP(for: side, exercise: exercise) {
            // 保存完了後に、今回セットのボリューム分XPを加算
            let totalVolume = max(0, weight) * Double(reps)
            userStatusVM?.addXP(volume: totalVolume, exerciseId: exercise)
        }

        reloadAfterChange(
            selectedDate: date,
            selectedExercise: exercise
        )
    }

    private func shouldGrantXP(for side: String, exercise: String) -> Bool {
        let normalizedSide = side.uppercased()

        // sideが指定されていない通常種目は従来どおり毎回XPを加算
        guard normalizedSide == "R" || normalizedSide == "L" else {
            pendingRightExercise = nil
            return true
        }

        if normalizedSide == "R" {
            pendingRightExercise = exercise
            return false
        }

        if normalizedSide == "L", pendingRightExercise == exercise {
            pendingRightExercise = nil
            return true
        }

        return false
    }

    func postSaveSideAction(for currentSide: String) -> PostSaveSideAction {
        switch currentSide {
        case "R":
            return .switchToLeft
        case "L":
            return .switchToRight
        default:
            return .none
        }
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

    func deleteExercise(name: String, selectedDate: Date, selectedExercise: String) {
        DatabaseManager.shared.deleteExercise(name: name)
        deletedExerciseNames = DatabaseManager.shared.fetchDeletedExerciseNames()

        reloadAfterChange(
            selectedDate: selectedDate,
            selectedExercise: selectedExercise
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

    func getEntries(for date: Date) -> [SetEntry] {
        entries
            .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.id < $1.id }
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

    func loadHistory(exercise: String) {
        history = DatabaseManager.shared.fetchSetsByExercise(exercise)
    }

    func addNewExercise(name: String, bodyPart: String) {
        DatabaseManager.shared.insertExercise(
            name: name,
            bodyPart: bodyPart
        )
        deletedExerciseNames = DatabaseManager.shared.fetchDeletedExerciseNames()
        exercises = DatabaseManager.shared.fetchExercisesByBodyPart()
    }
    
    func getLastSet(for exerciseId: String) -> String {
        guard !exerciseId.isEmpty else { return "前セットなし" }
        let last = entries
            .filter { $0.exercise == exerciseId }
            .max(by: { $0.date < $1.date })

        guard let last else { return "前セットなし" }

        let weightText = last.weight > 0 ? "\(Int(last.weight))kg" : "自重"
        if let side = last.side, !side.isEmpty {
            return "\(weightText) × \(last.reps)回（\(side)）"
        }
        return "\(weightText) × \(last.reps)回"
    }

    func lastSetText(for exercise: String) -> String? {
        let text = getLastSet(for: exercise)
        return text == "前セットなし" ? nil : text
    }

    var homeMetrics: HomeMetrics {
        let totalVolume = Int(entries.reduce(0) { $0 + ($1.weight * Double($1.reps)) })
        let streakDays = calculateStreakDays()

        return HomeMetrics(
            totalVolume: totalVolume,
            streakDays: streakDays
        )
    }

    private func calculateStreakDays(referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        let workoutDays = Set(entries.map { calendar.startOfDay(for: $0.date) })
        guard !workoutDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: referenceDate)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        let startDay: Date
        if workoutDays.contains(today) {
            startDay = today
        } else if workoutDays.contains(yesterday) {
            startDay = yesterday
        } else {
            return 0
        }

        var streak = 0
        var cursor = startDay
        while workoutDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return streak
    }

}
