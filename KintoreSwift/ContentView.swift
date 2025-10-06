import SwiftUI
import Charts

struct SetEntry: Identifiable, Hashable {
    let id: Int64        // ← DBの id をここで管理
    let date: Date
    let bodyPart: String
    let exercise: String
    let weight: Double
    let reps: Int
}


enum GroupingType: String, CaseIterable {
    case day = "日ごと"
    case week = "週ごと"
    case month = "月ごと"
}

struct ContentView: View {
    @State private var exerciseCategories: [String: [String]] = [
        "胸": ["ベンチプレス", "インクラインベンチプレス", "ケーブルフライ"],
        "背中": ["デッドリフト", "懸垂", "ラットプルダウン"],
        "肩": ["ショルダープレス", "サイドレイズ", "リアレイズ"],
        "腕": ["アームカール", "ハンマーカール", "ディップス"],
        "脚": ["スクワット", "ブルガリアンスクワット", "レッグプレス"],
        "腹筋": ["クランチ", "レッグレイズ", "プランク"]
    ]

    @State private var selectedBodyPart = "胸"
    @State private var selectedExercise = "ベンチプレス"
    @State private var weightText = ""
    @State private var repsText = ""
    @State private var entries: [SetEntry] = []

    @State private var selectedDate = Date()
    @State private var grouping: GroupingType = .day

    @State private var showingAddBodyPart = false
    @State private var newBodyPart = ""
    @State private var showingAddExercise = false
    @State private var newExercise = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // 日付選択
                DatePicker("日付", selection: $selectedDate, displayedComponents: .date)
                    .padding(.horizontal)

                // 部位選択
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Array(exerciseCategories.keys), id: \.self) { part in
                            Button(action: {
                                selectedBodyPart = part
                                // ✅ 部位を切り替えたときに最初の種目を自動選択
                                if let firstExercise = exerciseCategories[part]?.first {
                                    selectedExercise = firstExercise
                                } else {
                                    selectedExercise = ""
                                }
                            }) {
                                Text(part)
                                    .padding(8)
                                    .background(selectedBodyPart == part ? Color.blue : Color.gray.opacity(0.3))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        Button(action: { showingAddBodyPart = true }) {
                            Image(systemName: "plus.circle")
                        }
                    }
                }
                .padding(.horizontal)

                // 種目選択
                HStack {
                    Picker("種目", selection: $selectedExercise) {
                        ForEach(exerciseCategories[selectedBodyPart] ?? [], id: \.self) { e in
                            Text(e)
                        }
                    }
                    Button(action: { showingAddExercise = true }) {
                        Image(systemName: "plus.circle")
                    }
                }
                .padding(.horizontal)

                // 入力フォーム
                VStack(alignment: .leading, spacing: 8) {
                    TextField("重量 (kg)", text: $weightText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)

                    TextField("回数", text: $repsText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)

                    Button("このセットを追加") {
                        if let w = Double(weightText), let r = Int(repsText), w > 0, r > 0 {
                            // ✅ DBに追加
                            DatabaseManager.shared.insertWorkout(
                                date: selectedDate,
                                bodyPart: selectedBodyPart,
                                exercise: selectedExercise,
                                weight: w,
                                reps: r
                            )

                            // ✅ DBから最新データを取得
                            entries = DatabaseManager.shared.fetchAll()

                            // 入力リセット
                            weightText = ""
                            repsText = ""

                            print("✅ 新しいデータをDBに追加しました")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)

                // グラフ表示
                Picker("集計", selection: $grouping) {
                    ForEach(GroupingType.allCases, id: \.self) { g in
                        Text(g.rawValue).tag(g)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Chart {
                    ForEach(groupedData(), id: \.0) { (date, totalWeight, totalSets, totalReps) in
                        LineMark(
                            x: .value("日付", date),
                            y: .value("合計重量 (kg×rep)", totalWeight),
                            series: .value("種類", "合計重量")
                        )
                        .foregroundStyle(.blue)
                        .symbol(.circle)

                        LineMark(
                            x: .value("日付", date),
                            y: .value("セット数", totalSets),
                            series: .value("種類", "セット数")
                        )
                        .foregroundStyle(.green)
                        .symbol(.circle)

                        LineMark(
                            x: .value("日付", date),
                            y: .value("合計回数", totalReps),
                            series: .value("種類", "合計回数")
                        )
                        .foregroundStyle(.red)
                        .symbol(.circle)
                    }
                }
                .chartForegroundStyleScale([
                    "合計重量": .blue,
                    "セット数": .green,
                    "合計回数": .red
                ])
                .chartLegend(position: .bottom)
                .frame(height: 200)
                .padding(.horizontal)

                // 記録リスト（日付＋種目ごとにセット数リセット）
                let todaysEntries = entries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
                if todaysEntries.isEmpty {
                    Text("この日には記録がありません")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(groupedEntriesByExercise(entries: todaysEntries), id: \.0) { (exercise, sets) in
                            Section(header: Text("\(sets.first?.bodyPart ?? "") - \(exercise)")) {
                                ForEach(Array(sets.enumerated()), id: \.element.id) { index, e in
                                    Text("\(index + 1)sets: \(Int(e.weight)) kg × \(e.reps) 回")
                                        .foregroundColor(.secondary)
                                }
                                .onDelete { offsets in
                                    deleteEntry(offsets, from: sets)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workout")
            .onAppear {
                // ✅ 起動時にDBからデータを読み込む
                entries = DatabaseManager.shared.fetchAll()
                print("📦 DBからデータを読み込みました（\(entries.count)件）")
            }

            // 部位追加アラート
            .alert("新しい部位を追加", isPresented: $showingAddBodyPart) {
                TextField("部位名", text: $newBodyPart)
                Button("追加") {
                    if !newBodyPart.isEmpty {
                        exerciseCategories[newBodyPart] = []
                        selectedBodyPart = newBodyPart
                        newBodyPart = ""
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }

            // 種目追加アラート
            .alert("新しい種目を追加", isPresented: $showingAddExercise) {
                TextField("種目名", text: $newExercise)
                Button("追加") {
                    if !newExercise.isEmpty {
                        exerciseCategories[selectedBodyPart, default: []].append(newExercise)
                        selectedExercise = newExercise
                        newExercise = ""
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    // 日付＋種目ごとにグループ化
    private func groupedEntriesByExercise(entries: [SetEntry]) -> [(String, [SetEntry])] {
        let grouped = Dictionary(grouping: entries) { $0.exercise }
        return grouped.map { ($0.key, $0.value) }
    }

    // データ集計（日・週・月）
    private func groupedData() -> [(Date, Double, Int, Int)] {
        var grouped: [Date: (Double, Int, Int)] = [:]
        let calendar = Calendar.current

        for e in entries {
            let key: Date
            switch grouping {
            case .day:
                key = calendar.startOfDay(for: e.date)
            case .week:
                key = calendar.dateInterval(of: .weekOfYear, for: e.date)!.start
            case .month:
                key = calendar.dateInterval(of: .month, for: e.date)!.start
            }
            let weight = e.weight * Double(e.reps)
            grouped[key, default: (0, 0, 0)] = (
                grouped[key, default: (0, 0, 0)].0 + weight,
                grouped[key, default: (0, 0, 0)].1 + 1,
                grouped[key, default: (0, 0, 0)].2 + e.reps
            )
        }
        return grouped.map { ($0.key, $0.value.0, $0.value.1, $0.value.2) }
            .sorted { $0.0 < $1.0 }
    }

    // 削除処理（DBにも反映）
    private func deleteEntry(_ offsets: IndexSet, from sets: [SetEntry]) {
        for index in offsets {
            let entry = sets[index]
            // 🗑 DBから削除
            DatabaseManager.shared.deleteWorkout(entry: entry)
            // 🗑 配列から削除
            if let realIndex = entries.firstIndex(where: { $0.id == entry.id }) {
                entries.remove(at: realIndex)
            }
        }
    }
}

#Preview {
    ContentView()
}
