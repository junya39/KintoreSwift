
//  ExerciseHistoryGroup.swift

import Foundation

/// 履歴画面専用の表示モデル（DBとは無関係）
struct ExerciseHistoryGroup: Identifiable {
    let id = UUID()
    let date: Date
    let exercise: String
    let sets: [SetEntry]
}
