//  ExerciseDetailView.swift

import SwiftUI
import Charts

struct ExerciseDetailView: View {
    let exerciseName: String
    @State private var history: [SetEntry] = []

    @State private var weightInput = ""
    @State private var repsInput = ""
    @State private var selectedSide = "R"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // ✅ デバッグ表示
                Text("✅ Picker表示テスト")
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
                
                // タイトル
                Text("\(exerciseName) の履歴")
                    .font(.title2)
                    .bold()
                    .padding(.horizontal)
                
                // 統計表示
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

                // グラフ
                if !history.isEmpty {
                    let grouped = Dictionary(grouping: history) { entry in
                        Calendar.current.startOfDay(for: entry.date)
                    }.mapValues { entries in
                        entries.map { $0.weight }.max() ?? 0
                    }
                    let sortedData = grouped.sorted { $0.key < $1.key }

                    Chart {
                        ForEach(sortedData, id: \.key) { date, maxWeight in
                            LineMark(
                                x: .value("日付", date),
                                y: .value("最大重量 (kg)", maxWeight)
                            )
                            .symbol(.circle)
                            .foregroundStyle(.blue)
                        }
                    }
                    .frame(height: 200)
                    .padding(.horizontal)
                }

                // 履歴リスト（日時ごとにまとめる）
                if history.isEmpty {
                    Text("この種目の記録はまだありません。")
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                } else {

                    // 日付ごとにグループ化
                    let grouped = Dictionary(grouping: history) { entry in
                        Calendar.current.startOfDay(for: entry.date)
                    }

                    // 新しい日付が上にくるようにソート
                    let sortedDays = grouped.keys.sorted(by: >)

                    VStack(alignment: .leading, spacing: 10) {

                        ForEach(sortedDays, id: \.self) { day in

                            VStack(alignment: .leading, spacing: 6) {

                                // 日付ヘッダー
                                Text(day, style: .date)
                                    .font(.headline)

                                // その日のセット一覧
                                ForEach(grouped[day]!.sorted(by: { $0.id < $1.id }), id: \.id) { entry in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("\(Int(entry.weight)) kg × \(entry.reps) 回")
                                                .font(.body)

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


                // ✅ 新しいセット追加フォーム
                Divider().padding(.vertical, 8)
                
                VStack(spacing: 10) {
                    Text("新しいセットを追加")
                        .font(.headline)
                    
                    // 重量入力
                    HStack {
                        Text("重量(kg)")
                        TextField("60", text: $weightInput)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 回数入力
                    HStack {
                        Text("回数")
                        TextField("10", text: $repsInput)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }

                    // ✅ 左右選択 Picker（常時表示・目立つ位置）
                    VStack(alignment: .leading, spacing: 6) {
                        Text("どちらの手で行いましたか？")
                            .font(.subheadline)
                        Picker("Side", selection: $selectedSide) {
                            Text("右").tag("R")
                            Text("左").tag("L")
                            Text("なし").tag("")
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 6)
                    
                    // 追加ボタン
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
            history = DatabaseManager.shared.fetchAll()
                .filter { $0.exercise == exerciseName }
        }
        .navigationTitle(exerciseName)
    }
    
    private func calculateStats(for entries: [SetEntry]) -> (avg: Double, max: Double, totalReps: Int) {
        guard !entries.isEmpty else { return (0, 0, 0) }
        let weights = entries.map { $0.weight }
        let reps = entries.map { $0.reps }
        let avg = weights.reduce(0, +) / Double(weights.count)
        let max = weights.max() ?? 0
        let totalReps = reps.reduce(0, +)
        return (avg, max, totalReps)
    }

    private func addNewSet() {
        guard let weight = Double(weightInput),
              let reps = Int(repsInput),
              !exerciseName.isEmpty else { return }
        
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

        history = DatabaseManager.shared.fetchAll()
            .filter { $0.exercise == exerciseName }
    }
}
