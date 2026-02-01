
// HistoryViewModel.swift

import Foundation
import Combine

final class HistoryViewModel: ObservableObject {

    /// 履歴画面に表示する「種目ごとのグループ」
    @Published var groups: [ExerciseHistoryGroup] = []

    /// 指定された日付の履歴を読み込む
    func load(date: Date) {

        // ① その日だけの SetEntry を DB から取得
        let entries = DatabaseManager.shared.fetchSets(by: date)

        // ② 種目ごとにグルーピング
        let grouped = Dictionary(grouping: entries) { $0.exercise }

        // ③ 表示用モデルに変換
        let result = grouped.map { (exercise, sets) in
            ExerciseHistoryGroup(
                date: date,
                exercise: exercise,
                sets: sets.sorted { $0.id < $1.id } // 古い順
            )
        }
        .sorted { $0.exercise < $1.exercise } // 種目名順

        // ④ UIに反映
        self.groups = result
    }
}
