//  ExerciseDetailView.swift

import SwiftUI
import Charts

struct ExerciseDetailView: View {
    let exerciseName: String
    @State private var history: [SetEntry] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ✅ タイトル
            Text("\(exerciseName) の履歴")
                .font(.title2)
                .bold()
                .padding(.horizontal)

            // ✅ 統計表示
            if !history.isEmpty {
                let stats = calculateStats(for: history)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("平均: \(String(format: "%.1f", stats.avg)) kg")
                        Text("最大: \(Int(stats.max)) kg")
                        Text("総レップ: \(stats.totalReps)")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
            }

            // ✅ グラフ表示（1日ごとの最大重量を表示）
            if !history.isEmpty {
                // 各日の最大重量をまとめる
                let grouped = Dictionary(grouping: history) { entry in
                    Calendar.current.startOfDay(for: entry.date)
                }.mapValues { entries in
                    entries.map { $0.weight }.max() ?? 0
                }

                // 日付順にソート
                let sortedData = grouped.sorted { $0.key < $1.key }

                Chart {
                    ForEach(sortedData, id: \.key) { date, maxWeight in
                        LineMark(
                            x: .value("日付", date),
                            y: .value("最大重量 (kg)", maxWeight)
                        )
                        .symbol(.circle)
                        .foregroundStyle(.blue)

                        PointMark(
                            x: .value("日付", date),
                            y: .value("最大重量 (kg)", maxWeight)
                        )
                        .annotation {
                            Text("\(Int(maxWeight))kg")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 200)
                .padding(.horizontal)
                .chartYAxisLabel("重量 (kg)")
            }

            // ✅ データなしメッセージ
            if history.isEmpty {
                Text("この種目の記録はまだありません。")
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                // ✅ 記録リスト
                List {
                    ForEach(history.sorted(by: { $0.date > $1.date }), id: \.id) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.date, style: .date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(Int(entry.weight)) kg × \(entry.reps) 回")
                                .font(.body)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Spacer()
        }
        .navigationTitle(exerciseName)
        .onAppear {
            history = DatabaseManager.shared.fetchAll()
                .filter { $0.exercise == exerciseName }
        }
    }

    // ✅ 統計計算関数
    private func calculateStats(for entries: [SetEntry]) -> (avg: Double, max: Double, totalReps: Int) {
        guard !entries.isEmpty else { return (0, 0, 0) }

        let weights = entries.map { $0.weight }
        let reps = entries.map { $0.reps }

        let avg = weights.reduce(0, +) / Double(weights.count)
        let max = weights.max() ?? 0
        let totalReps = reps.reduce(0, +)

        return (avg, max, totalReps)
    }
}

