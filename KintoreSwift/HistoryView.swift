//  HistoryView.swift
import SwiftUI
import Charts

struct HistoryView: View {
    var entries: [SetEntry]
    var exerciseName: String
    var selectedDate: Date? = nil // カレンダーで選んだ日。nilなら全期間

    // 選択日で絞った配列（nilなら全部）
    private var filteredEntries: [SetEntry] {
        guard let targetDate = selectedDate else {
            return entries
        }
        return entries.filter { entry in
            Calendar.current.isDate(entry.date, inSameDayAs: targetDate)
        }
    }

    // 重量の表示を "自重" / "xxkg" で返す便利関数
    private func weightText(_ w: Double) -> String {
        w == 0 ? "自重" : "\(Int(w))kg"
    }

    // グラフ用: 日ごとにその日の「最大重量」を使う
    private var dayMaxSeries: [(date: Date, maxWeight: Double)] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filteredEntries) { e in
            cal.startOfDay(for: e.date)
        }
        return grouped.map { (dayStart, items) in
            let maxW = items.map { $0.weight }.max() ?? 0
            return (dayStart, maxW)
        }
        .sorted { $0.date < $1.date }
    }

    // リスト表示用: 日付ごとに並べた辞書を並べ替え
    private var entriesByDayDesc: [(day: Date, sets: [SetEntry])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filteredEntries) { e in
            cal.startOfDay(for: e.date)
        }
        // 新しい日付が上にくるよう降順ソート
        return grouped
            .map { (key: Date, value: [SetEntry]) in
                // その日の中も追加順で見たいならid降順などしてもOK
                let sortedSets = value.sorted { $0.id < $1.id }
                return (day: key, sets: sortedSets)
            }
            .sorted { $0.day > $1.day }
    }

    // 集計（平均・最大・総レップ）
    private var avgText: String {
        let ws = filteredEntries.map { $0.weight }
        if ws.isEmpty { return "-" }
        if ws.allSatisfy({ $0 == 0 }) { return "自重" }
        let avg = ws.reduce(0,+) / Double(ws.count)
        return String(format: "%.1f kg", avg)
    }

    private var maxText: String {
        let ws = filteredEntries.map { $0.weight }
        if ws.isEmpty { return "-" }
        if ws.allSatisfy({ $0 == 0 }) { return "自重" }
        let mx = ws.max() ?? 0
        return String(format: "%.1f kg", mx)
    }

    private var totalRepsText: String {
        let repsSum = filteredEntries.map { $0.reps }.reduce(0,+)
        return "\(repsSum) 回"
    }

    // 日付のラベル
    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long // "October 19, 2025"とか
        return f.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // タイトル
            Text("\(exerciseName) の履歴")
                .font(.title2)
                .bold()

            if filteredEntries.isEmpty {
                Text("記録がありません。")
                    .foregroundColor(.secondary)
            } else {

                // 集計サマリ
                VStack(alignment: .leading, spacing: 8) {
                    Text("平均: \(avgText)")
                    Text("最大: \(maxText)")
                    Text("総レップ: \(totalRepsText)")
                }

                // 折れ線グラフ（その日ごとの最大重量）
                Chart {
                    ForEach(dayMaxSeries, id: \.date) { point in
                        LineMark(
                            x: .value("日付", point.date),
                            y: .value("最大重量(kg)", point.maxWeight)
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(.init(lineWidth: 3))
                        .symbol(Circle())

                        PointMark(
                            x: .value("日付", point.date),
                            y: .value("最大重量(kg)", point.maxWeight)
                        )
                        .foregroundStyle(.blue)

                        // 自重ならラベル「自重」
                        .annotation(position: .top) {
                            if point.maxWeight == 0 {
                                Text("自重")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else {
                                Text("\(Int(point.maxWeight))kg")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 220)
                .chartYAxisLabel("重量 (kg)")
                .chartYAxis {
                    AxisMarks(position: .trailing)
                }
                .chartXAxis {
                    AxisMarks(values: dayMaxSeries.map { $0.date }) { val in
                        AxisGridLine()
                        AxisValueLabel {
                            Text(
                                val.as(Date.self).map {
                                    let f = DateFormatter()
                                    f.dateFormat = "M/d"
                                    return f.string(from: $0)
                                } ?? ""
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                }


                // 日ごとの詳細リスト
                ForEach(entriesByDayDesc, id: \.day) { dayBlock in
                    VStack(alignment: .leading, spacing: 8) {

                        Text(dayLabel(dayBlock.day))
                            .font(.headline)

                        ForEach(dayBlock.sets, id: \.id) { entry in
                            VStack(alignment: .leading, spacing: 4) {

                                // 🔥 ここだけ HStack に変更
                                HStack {
                                    Text("\(weightText(entry.weight)) × \(entry.reps) 回")
                                        .font(.subheadline)

                                    if let side = entry.side, !side.isEmpty {
                                        if side == "R" {
                                            Text("(右)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else if side == "L" {
                                            Text("(左)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }

                                // 📝 メモは今のままでOK
                                if let note = entry.note,
                                   !note.isEmpty {
                                    Text("💬 \(note)")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.top, 4)
                }
            }

            Spacer()
        }
        .padding()
    }
}

