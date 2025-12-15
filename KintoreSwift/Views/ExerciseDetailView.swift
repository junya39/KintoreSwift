import SwiftUI
import Charts

struct ExerciseDetailView: View {

    let exerciseName: String
    @State private var history: [SetEntry] = []

    @State private var weightInput = ""
    @State private var repsInput = ""
    @State private var selectedSide = "R"

    // ---------------------
    // 日付ごとに履歴をまとめる
    // ---------------------
    var groupedHistory: [(Date, [SetEntry])] {

        let grouped = Dictionary(grouping: history) {
            Calendar.current.startOfDay(for: $0.date)
        }

        return grouped
            .map { (day, entries) in
                (
                    day,
                    entries.sorted(by: { $0.id < $1.id })
                )
            }
            .sorted { $0.0 > $1.0 }
    }
    
    
    private var isBodyweightOnly: Bool {
        history.allSatisfy { $0.weight == 0 }
    }


    var body: some View {

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ---------------------
                // タイトル
                // ---------------------
                Text("\(exerciseName) の履歴")
                    .font(.title2)
                    .bold()
                    .padding(.horizontal)

                // ---------------------
                // 統計
                // ---------------------
                if !history.isEmpty {

                    let stats = calculateStats(for: history)

                    VStack(alignment: .leading, spacing: 6) {

                        // 重量系（ラット・ロウなど）
                        if stats.maxWeight > 0 {
                            Text("平均重量: \(String(format: "%.1f", stats.avgWeight)) kg")
                            Text("最大重量: \(Int(stats.maxWeight)) kg")
                        }

                        Text("総レップ数: \(stats.totalReps)")

                        // 自重チンニング
                        if stats.bodyweightSets > 0 {
                            Divider().padding(.vertical, 4)
                            Text("チンニング最大回数: \(stats.bodyweightMaxReps) 回")
                            Text("チンニング合計回数: \(stats.bodyweightTotalReps) 回")
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                }

                // ---------------------
                // グラフ（重量トレのみ）
                // ---------------------
                // ---------------------
                // グラフ
                // ---------------------
                if !groupedHistory.isEmpty {

                    Chart {
                        ForEach(groupedHistory, id: \.0) { day, entries in

                            if isBodyweightOnly {
                                // ✅ 自重種目：回数グラフ
                                if let maxReps = entries.map({ $0.reps }).max() {
                                    LineMark(
                                        x: .value("日付", day),
                                        y: .value("回数", maxReps)
                                    )
                                    .symbol(.circle)
                                }

                            } else {
                                // ✅ 加重種目：重量グラフ
                                if let maxWeight = entries.map({ $0.weight }).max() {
                                    LineMark(
                                        x: .value("日付", day),
                                        y: .value("重量", maxWeight)
                                    )
                                    .symbol(.circle)
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                    .padding(.horizontal)
                }


                // ---------------------
                // 履歴一覧
                // ---------------------
                if groupedHistory.isEmpty {

                    Text("この種目の記録はまだありません。")
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                } else {

                    VStack(alignment: .leading, spacing: 10) {

                        ForEach(groupedHistory, id: \.0) { day, entries in

                            VStack(alignment: .leading, spacing: 6) {

                                // 日付
                                Text(day, style: .date)
                                    .font(.headline)

                                // セット一覧
                                ForEach(entries, id: \.id) { entry in

                                    VStack(alignment: .leading, spacing: 4) {

                                        HStack {

                                            if entry.weight == 0 {
                                                Text("自重 × \(entry.reps) 回")
                                                    .font(.body)
                                            } else {
                                                Text("\(Int(entry.weight)) kg × \(entry.reps) 回")
                                                    .font(.body)
                                            }

                                            if let side = entry.side, !side.isEmpty {
                                                Text(side == "R" ? "(右)" : "(左)")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                        }

                                        if let note = entry.note, !note.isEmpty {
                                            Text("💬 \(note)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(6)
                                }
                            }

                            Divider().padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal)
                }

                // ---------------------
                // 新規セット追加
                // ---------------------
                Divider().padding(.vertical, 8)

                VStack(spacing: 10) {

                    Text("新しいセットを追加")
                        .font(.headline)

                    // 重量
                    HStack {
                        Text("重量(kg)")
                        TextField("0（自重）", text: $weightInput)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 回数
                    HStack {
                        Text("回数")
                        TextField("10", text: $repsInput)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Side Picker
                    VStack(alignment: .leading, spacing: 6) {

                        Text("左右")
                            .font(.subheadline)

                        Picker("Side", selection: $selectedSide) {
                            Text("右").tag("R")
                            Text("左").tag("L")
                            Text("なし").tag("")
                        }
                        .pickerStyle(.segmented)
                    }

                    Button("+ 記録を追加") {
                        addNewSet()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 6)
                }
                .padding()
            }
        }
        .onAppear {
            history = DatabaseManager.shared.fetchSetsByExercise(exerciseName)
        }
        .navigationTitle(exerciseName)
    }

    // ---------------------
    // MARK: - Stats
    // ---------------------
    private func calculateStats(for entries: [SetEntry]) -> (
        avgWeight: Double,
        maxWeight: Double,
        totalReps: Int,
        bodyweightMaxReps: Int,
        bodyweightTotalReps: Int,
        bodyweightSets: Int
    ) {

        let weighted = entries.filter { $0.weight > 0 }
        let bodyweight = entries.filter { $0.weight == 0 }

        let avgWeight =
            weighted.isEmpty
            ? 0
            : weighted.map { $0.weight }.reduce(0, +) / Double(weighted.count)

        let maxWeight = weighted.map { $0.weight }.max() ?? 0
        let totalReps = entries.map { $0.reps }.reduce(0, +)

        let bodyweightMaxReps = bodyweight.map { $0.reps }.max() ?? 0
        let bodyweightTotalReps = bodyweight.map { $0.reps }.reduce(0, +)

        return (
            avgWeight,
            maxWeight,
            totalReps,
            bodyweightMaxReps,
            bodyweightTotalReps,
            bodyweight.count
        )
    }

    // ---------------------
    // MARK: - Add Set
    // ---------------------
    private func addNewSet() {

        guard
            let weight = Double(weightInput),
            let reps = Int(repsInput),
            !exerciseName.isEmpty
        else { return }

        DatabaseManager.shared.insert(
            date: Date(),
            bodyPart: "",
            exercise: exerciseName,
            weight: weight,
            reps: reps,
            note: nil,
            side: selectedSide
        )

        weightInput = ""
        repsInput = ""
        selectedSide = "R"

        history = DatabaseManager.shared.fetchSetsByExercise(exerciseName)
    }
}
