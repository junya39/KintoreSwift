//  HistoryView.swift.swift

import SwiftUI
import Charts

struct HistoryView: View {
    var entries: [SetEntry]
    var exerciseName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(exerciseName) の履歴")
                .font(.title2)
                .bold()

            if entries.isEmpty {
                Text("記録がありません。")
                    .foregroundColor(.secondary)
            } else {
                // 平均・最大・総レップ数
                let avg = entries.map { $0.weight }.reduce(0, +) / Double(entries.count)
                let max = entries.map { $0.weight }.max() ?? 0
                let totalReps = entries.map { $0.reps }.reduce(0, +)

                Text("平均: \(String(format: "%.1f", avg)) kg")
                Text("最大: \(Int(max)) kg")
                Text("総レップ: \(totalReps) 回")

                // ✅ グラフ（日ごとに集約して折れ線化）
                Chart {
                    ForEach(groupedByDay(), id: \.0) { (date, maxWeight) in
                        LineMark(
                            x: .value("日付", date),
                            y: .value("最大重量", maxWeight)
                        )
                        .foregroundStyle(.blue)
                        .symbol(Circle())
                        .lineStyle(.init(lineWidth: 3))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 220)
                .chartYAxisLabel("重量 (kg)")
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                        AxisValueLabel(formatDate(value.as(Date.self)))
                    }
                }

                Divider().padding(.vertical, 4)

                // 🧾 記録リスト
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(entries.sorted(by: { $0.date > $1.date }), id: \.id) { e in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(e.date, style: .date)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("\(Int(e.weight)) kg × \(e.reps) 回")
                                    .font(.headline)
                            }
                            .padding(.vertical, 6)
                            Divider()
                        }
                    }
                }
            }
        }
        .padding()
    }

    // ✅ 日ごとに「最大重量」を抽出
    private func groupedByDay() -> [(Date, Double)] {
        var grouped: [Date: [Double]] = [:]
        let calendar = Calendar.current

        for e in entries {
            let key = calendar.startOfDay(for: e.date)
            grouped[key, default: []].append(e.weight)
        }

        return grouped.map { (key, weights) in
            (key, weights.max() ?? 0)
        }
        .sorted { $0.0 < $1.0 }
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: date)
    }
}
