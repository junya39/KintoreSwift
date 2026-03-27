//ContentViewModel.swift

import SwiftUI
import Foundation

class ContentViewModel: ObservableObject {
    enum PostSaveSideAction {
        case switchToLeft
        case switchToRight
        case none
    }

    enum LogEventType: Int {
        case normalLog
        case newWeightRecord
        case newRepRecord
        case perfectRecord
        case levelUp
    }

    struct HomeMetrics {
        let totalVolume: Int
        let streakDays: Int
    }

    private struct ExerciseRecordSnapshot {
        var lastWeight: Double
        var lastReps: Int
        var bestWeight: Double
        var bestReps: Int
    }

    private enum LogSyncKeys {
        static let notificationName = Notification.Name("ContentViewModel.LogDidChange")
        static let message = "message"
        static let eventRawValue = "eventRawValue"
    }

    private static var sharedLogMessage: String = "今日も鍛える準備はできている。"
    private static var sharedLogEvent: LogEventType = .normalLog

    @Published var entries: [SetEntry] = []
    @Published var exercises: [String: [String]] = [:]
    @Published var dailyEntries: [SetEntry] = []
    @Published var history: [SetEntry] = []
    @Published var diffText: String = ""
    @Published var diffColor: Color = .secondary
    @Published var chartGrouping: GroupingType = .day
    @Published var currentLogMessage: String
    @Published var currentLogEvent: LogEventType
    @Published private(set) var deletedExerciseNames: Set<String> = []
    private var pendingRightExercise: String?
    private var exerciseRecordSnapshots: [String: ExerciseRecordSnapshot] = [:]
    private var logResetToken = UUID()
    private var logObserver: NSObjectProtocol?

    init() {
        currentLogMessage = Self.sharedLogMessage
        currentLogEvent = Self.sharedLogEvent

        logObserver = NotificationCenter.default.addObserver(
            forName: LogSyncKeys.notificationName,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard
                let userInfo = notification.userInfo,
                let message = userInfo[LogSyncKeys.message] as? String,
                let eventRawValue = userInfo[LogSyncKeys.eventRawValue] as? Int,
                let event = LogEventType(rawValue: eventRawValue)
            else {
                return
            }
            self.currentLogMessage = message
            self.currentLogEvent = event
        }
    }

    deinit {
        if let logObserver {
            NotificationCenter.default.removeObserver(logObserver)
        }
    }

    func loadInitialData() {
        DatabaseManager.shared.createExerciseTableIfNeeded()
        DatabaseManager.shared.createDeletedExerciseTableIfNeeded()
        deletedExerciseNames = DatabaseManager.shared.fetchDeletedExerciseNames()
        exercises = DatabaseManager.shared.fetchExercisesByBodyPart()
        entries = DatabaseManager.shared.fetchAll()
        rebuildExerciseRecordSnapshots()
    }

    func bodyPart(for exercise: String) -> String {
        for (bodyPart, exerciseNames) in exercises where exerciseNames.contains(exercise) {
            return bodyPart
        }
        return "ALL"
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
        let previousSnapshot = exerciseRecordSnapshots[exercise]
        let isWeightRecord: Bool
        let isRepRecord: Bool
        if let previousSnapshot {
            isWeightRecord = weight > previousSnapshot.bestWeight
            isRepRecord = reps > previousSnapshot.bestReps
        } else {
            isWeightRecord = weight > 0
            isRepRecord = reps > 0
        }

        var eventType: LogEventType
        if isWeightRecord && isRepRecord {
            eventType = .perfectRecord
        } else if isWeightRecord {
            eventType = .newWeightRecord
        } else if isRepRecord {
            eventType = .newRepRecord
        } else {
            eventType = .normalLog
        }

        let levelBeforeXP = userStatusVM?.level ?? 1
        let actorName = evolutionName(for: levelBeforeXP)
        let weightText = formattedWeightText(weight)
        let normalMessage = "\(actorName)は\(exercise)\(weightText)を\(reps)回上げた！"
        var eventMessage: String
        switch eventType {
        case .perfectRecord:
            eventMessage = "★★ 完全勝利！★★\n自己ベスト更新！！"
        case .newWeightRecord:
            eventMessage = "★ NEW RECORD ★\n\(actorName)は\(formattedWeightValue(weight))kgを持ち上げた！"
        case .newRepRecord:
            eventMessage = "限界突破！\n\(actorName)は\(reps)回達成！"
        case .levelUp:
            eventMessage = normalMessage
        case .normalLog:
            eventMessage = normalMessage
        }

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
            if let userStatusVM {
                let xpType = xpType(for: bodyPart)
                let baseXP = sqrt(totalVolume)
                let adjustedBaseXP = userStatusVM.titleManager.applyBonus(
                    baseXP: baseXP,
                    type: xpType
                )
                let subXP = adjustedBaseXP * 0.3
                userStatusVM.addXP(
                    volume: totalVolume,
                    exerciseId: exercise,
                    baseXPOverride: adjustedBaseXP
                )
                applySubXP(
                    subXP: subXP,
                    weight: weight,
                    reps: reps,
                    userStatusVM: userStatusVM
                )
            }
        }

        let levelAfterXP = userStatusVM?.level ?? levelBeforeXP
        if levelAfterXP > levelBeforeXP {
            let evolvedName = evolutionName(for: levelAfterXP)
            eventType = .levelUp
            eventMessage = "\(evolvedName)はレベルがLv\(levelAfterXP)になった！"
        }

        reloadAfterChange(
            selectedDate: date,
            selectedExercise: exercise
        )

        publishLog(
            eventType: eventType,
            eventMessage: eventMessage,
            fallbackMessage: normalMessage
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

    private func xpType(for bodyPart: String) -> TitleEffectType {
        switch bodyPart {
        case "脚", "腹筋":
            return .enduranceXP
        default:
            return .powerXP
        }
    }

    private func applySubXP(
        subXP: Double,
        weight: Double,
        reps: Int,
        userStatusVM: UserStatusViewModel
    ) {
        guard subXP > 0 else { return }

        let powerDelta: Double
        let enduranceDelta: Double

        if weight == 0 {
            powerDelta = 0
            enduranceDelta = subXP
        } else if reps <= 8 {
            powerDelta = subXP
            enduranceDelta = 0
        } else if reps >= 15 {
            powerDelta = 0
            enduranceDelta = subXP
        } else {
            powerDelta = subXP * 0.5
            enduranceDelta = subXP * 0.5
        }

        let statCap = max(0, userStatusVM.level)
        if powerDelta > 0 {
            let nextPower = userStatusVM.power + Int(powerDelta.rounded())
            userStatusVM.power = min(statCap, max(0, nextPower))
        }
        if enduranceDelta > 0 {
            let nextEndurance = userStatusVM.endurance + Int(enduranceDelta.rounded())
            userStatusVM.endurance = min(statCap, max(0, nextEndurance))
        }

        userStatusVM.titleManager.evaluateTitles(
            powerLevel: userStatusVM.power,
            enduranceLevel: userStatusVM.endurance,
            totalLevel: userStatusVM.level
        )
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
        rebuildExerciseRecordSnapshots()
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
        let wDiff = latest.weight - prev.weight
        let rDiff = latest.reps - prev.reps
        diffText = "前回比: \(signedWeightText(wDiff))kg / \(rDiff >= 0 ? "+" : "")\(rDiff)回"
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

        let weightText = formattedWeightText(last.weight)
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

    private func rebuildExerciseRecordSnapshots() {
        var snapshots: [String: ExerciseRecordSnapshot] = [:]
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            var snapshot = snapshots[entry.exercise] ?? ExerciseRecordSnapshot(
                lastWeight: entry.weight,
                lastReps: entry.reps,
                bestWeight: entry.weight,
                bestReps: entry.reps
            )
            snapshot.lastWeight = entry.weight
            snapshot.lastReps = entry.reps
            snapshot.bestWeight = max(snapshot.bestWeight, entry.weight)
            snapshot.bestReps = max(snapshot.bestReps, entry.reps)
            snapshots[entry.exercise] = snapshot
        }
        exerciseRecordSnapshots = snapshots
    }

    private func formattedWeightValue(_ weight: Double) -> String {
        String(format: "%.1f", weight)
    }

    private func formattedWeightText(_ weight: Double) -> String {
        weight > 0 ? "\(formattedWeightValue(weight))kg" : "自重"
    }

    private func signedWeightText(_ weight: Double) -> String {
        let sign = weight >= 0 ? "+" : ""
        return "\(sign)\(formattedWeightValue(weight))"
    }

    private func publishLog(
        eventType: LogEventType,
        eventMessage: String,
        fallbackMessage: String
    ) {
        let token = UUID()
        logResetToken = token
        syncLogState(message: eventMessage, event: eventType)

        guard eventType != .normalLog else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self else { return }
            guard self.logResetToken == token else { return }
            self.syncLogState(message: fallbackMessage, event: .normalLog)
        }
    }

    private func syncLogState(message: String, event: LogEventType) {
        currentLogMessage = message
        currentLogEvent = event
        Self.sharedLogMessage = message
        Self.sharedLogEvent = event
        NotificationCenter.default.post(
            name: LogSyncKeys.notificationName,
            object: nil,
            userInfo: [
                LogSyncKeys.message: message,
                LogSyncKeys.eventRawValue: event.rawValue
            ]
        )
    }

    private func evolutionName(for level: Int) -> String {
        switch level {
        case 1...4:
            return "がりがり"
        case 5...9:
            return "ほそ"
        case 10...14:
            return "ふつう"
        case 15...19:
            return "ほそまっちょ"
        case 20...29:
            return "まっちょ"
        case 30...39:
            return "ごりまっちょ"
        case 40...99:
            return "ごりらっちょ"
        default:
            return "れじぇんど"
        }
    }

}
