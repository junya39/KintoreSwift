//ContentView.Swift

import SwiftUI
import Charts

struct ContentView: View {
    @State private var selectedDate = Date()
    @State private var selectedBodyPart = "胸"
    @State private var selectedExercise = "ベンチプレス"
    @State private var weightText = ""
    @State private var repsText = ""
    @State private var entries: [SetEntry] = []
    @State private var chartGrouping: GroupingType = .day
    @State private var showingHistory = false

    // 🔥 追加（前回比表示用）
    @State private var lastRecord: SetEntry? = nil
    @State private var diffText: String = ""
    @State private var diffColor: Color = .secondary

    let bodyParts = ["胸", "背中", "脚", "肩", "腕", "腹筋"]
    let exercises: [String: [String]] = [
        "胸": ["ベンチプレス", "インクラインベンチプレス", "ケーブルだっちゅーの"],
        "背中": ["チンニング", "ワンハンドロー", "Tバーロウ", "ラットプルダウン（ナロー）"],
        "脚": ["スクワット", "ブルガリアンスクワット", "レッグプレス", "アダクター"],
        "肩": ["ショルダープレス", "サイドレイズ", "リアレイズ"],
        "腕": ["インクラインアームカール", "ハンマーカール", "ディップス", "ワンハンドオーバーエクステンション"],
        "腹筋": ["クランチ", "レッグレイズ", "アブローラー"]
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {

                    // 🗓 カレンダー
                    CalendarView(selectedDate: $selectedDate, markedDates: entries.map { $0.date })
                        .frame(height: 340)
                        .padding(.top, 8)

                    // 🏋️ 部位選択ボタン
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(bodyParts, id: \.self) { part in
                                Button(action: {
                                    selectedBodyPart = part
                                    selectedExercise = exercises[part]?.first ?? ""
                                }) {
                                    Text(part)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedBodyPart == part ? Color.blue : Color.gray.opacity(0.2))
                                        .foregroundColor(selectedBodyPart == part ? .white : .primary)
                                        .cornerRadius(10)
                                }
                            }
                        }.padding(.horizontal)
                    }

                    // 🏋️‍♀️ 種目選択
                    HStack {
                        Picker("種目", selection: $selectedExercise) {
                            ForEach(exercises[selectedBodyPart] ?? [], id: \.self) { ex in
                                Text(ex)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedExercise, initial: true) { _, newValue in
                            updateLastRecord(for: newValue)
                        }


                        Spacer()

                        // ➕ 種目追加（将来用）
                        Button(action: {}) {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.blue)
                                .font(.title3)
                        }
                    }
                    .padding(.horizontal)

                    // 🧾 前回比表示
                    if !diffText.isEmpty {
                        Text(diffText)
                            .font(.subheadline)
                            .foregroundColor(diffColor)
                            .bold()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    // 📅 履歴ボタン
                    Button(action: { showingHistory = true }) {
                        Label("過去の記録を見る", systemImage: "clock.arrow.circlepath")
                            .foregroundColor(.blue)
                    }
                    .sheet(isPresented: $showingHistory) {
                        HistoryView(entries: entries.filter { $0.exercise == selectedExercise },
                                    exerciseName: selectedExercise)
                    }

                    // ⚖️ 入力フォーム
                    VStack {
                        TextField("重量 (kg)", text: $weightText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        TextField("回数", text: $repsText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        Button(action: addSet) {
                            Text("このセットを追加")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)

                    // 📈 グラフ
                    Picker("Grouping", selection: $chartGrouping) {
                        Text("日ごと").tag(GroupingType.day)
                        Text("週ごと").tag(GroupingType.week)
                        Text("月ごと").tag(GroupingType.month)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    ChartView(entries: entries, grouping: chartGrouping)
                        .frame(height: 220)
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Workout")
            .onAppear {
                entries = DatabaseManager.shared.fetchAll()
                updateLastRecord(for: selectedExercise)
            }
        }
    }

    // MARK: - 関数群
    private func addSet() {
        guard let weight = Double(weightText),
              let reps = Int(repsText),
              !selectedExercise.isEmpty else { return }

        DatabaseManager.shared.insert(
            date: selectedDate,
            bodyPart: selectedBodyPart,
            exercise: selectedExercise,
            weight: weight,
            reps: reps
        )
        entries = DatabaseManager.shared.fetchAll()
        weightText = ""
        repsText = ""
        updateLastRecord(for: selectedExercise)
    }

    // 🔥 前回比を計算する
    private func updateLastRecord(for exercise: String) {
        guard !exercise.isEmpty else { return }
        if let last = DatabaseManager.shared.fetchLastRecord(for: exercise) {
            lastRecord = last
            if let latest = entries.filter({ $0.exercise == exercise }).max(by: { $0.date < $1.date }) {
                let weightDiff = Int(latest.weight - last.weight)
                let repsDiff = latest.reps - last.reps

                diffText = "前回比: \(weightDiff >= 0 ? "+" : "")\(weightDiff)kg / \(repsDiff >= 0 ? "+" : "")\(repsDiff)回"
                diffColor = (weightDiff > 0 || repsDiff > 0)
                    ? .green
                    : (weightDiff < 0 || repsDiff < 0)
                        ? .red
                        : .gray
            }
        } else {
            diffText = "前回記録なし"
            diffColor = .secondary
        }
    }
}

// MARK: - グルーピングタイプ
enum GroupingType: String, CaseIterable, Identifiable {
    case day, week, month
    var id: String { rawValue }
}
