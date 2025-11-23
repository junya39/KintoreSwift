import SwiftUI
import Charts

struct HistoryView: View {
    var entries: [SetEntry]          // ← その日の全ての記録が渡ってくる
    var selectedDate: Date? = nil    // ← カレンダーで選んだ日

    // 便利：重量の表示
    private func weightText(_ w: Double) -> String {
        w == 0 ? "自重" : "\(Int(w))kg"
    }

    // 日付ラベル
    private var dateLabel: String {
        guard let d = selectedDate else { return "" }
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: d)
    }

    // 種目別にグラフ用データをまとめる
    private var maxWeightPerExercise: [(name: String, maxWeight: Double)] {
        let grouped = Dictionary(grouping: entries, by: { $0.exercise })
        return grouped.map { (key, list) in
            (name: key, maxWeight: list.map { $0.weight }.max() ?? 0)
        }
        .sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // タイトル
            Text("\(dateLabel) の記録")
                .font(.title2)
                .bold()

            if entries.isEmpty {
                Text("この日の記録はありません。")
                    .foregroundColor(.secondary)
            } else {

                // --- グラフ：種目ごとの最大重量 ---
                Chart {
                    ForEach(maxWeightPerExercise, id: \.name) { item in
                        BarMark(
                            x: .value("重量", item.maxWeight),
                            y: .value("種目", item.name)
                        )
                        .foregroundStyle(.blue)

                        PointMark(
                            x: .value("重量", item.maxWeight),
                            y: .value("種目", item.name)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .frame(height: 240)
                .padding(.bottom, 8)

                Divider()

                // --- 日付内の全記録を箇条書き表示 ---
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(entries.sorted(by: { $0.id < $1.id }), id: \.id) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            
                            // 種目名
                            Text(entry.exercise)
                                .font(.headline)

                            HStack {
                                Text("\(weightText(entry.weight)) × \(entry.reps) 回")
                                    .font(.subheadline)

                                // 左右
                                if let side = entry.side {
                                    if side == "R" { Text("(右)") }
                                    if side == "L" { Text("(左)") }
                                }
                            }

                            // メモ
                            if let note = entry.note, !note.isEmpty {
                                Text("💬 \(note)")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}

