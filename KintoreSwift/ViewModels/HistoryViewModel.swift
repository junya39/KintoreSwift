
// HistoryViewModel.swift

import Foundation
import Combine

final class HistoryViewModel: ObservableObject {

    /// 履歴画面に表示する「種目ごとのグループ」
    @Published var groups: [ExerciseHistoryGroup] = []
    @Published var entries: [SetEntry] = []

    /// 指定された日付の履歴を読み込む
    func load(date: Date) {

        // ① その日だけの SetEntry を DB から取得
        let entries = DatabaseManager.shared.fetchSets(by: date)
        let sortedEntries = ContentViewModel.sortedForDailyRecordDisplay(entries)
        self.entries = sortedEntries

        // ② 種目ごとにグルーピング
        let grouped = Dictionary(grouping: sortedEntries) { $0.exercise }
        var seenExercises = Set<String>()
        let exerciseOrder = sortedEntries.compactMap { entry in
            if seenExercises.insert(entry.exercise).inserted {
                return entry.exercise
            }
            return nil
        }

        // ③ 表示用モデルに変換
        let result = exerciseOrder.compactMap { exercise -> ExerciseHistoryGroup? in
            guard let sets = grouped[exercise] else { return nil }
            return ExerciseHistoryGroup(
                date: date,
                exercise: exercise,
                sets: sets.sorted { $0.id < $1.id } // 古い順
            )
        }

        // ④ UIに反映
        self.groups = result
    }
}
