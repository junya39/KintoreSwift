// ContentView.swift

import SwiftUI
import Charts

struct ContentView: View {
    @State private var selectedDate = Date()
    @State private var selectedBodyPart = "胸"
    @State private var selectedExercise = "ベンチプレス"
    @State private var weightText = ""
    @State private var repsText = ""
    @State private var note: String = ""
    @State private var isBodyweight = false

    @State private var entries: [SetEntry] = []
    @State private var exercises: [String: [String]] = [:] // ← SQLiteから読み込む
    @State private var chartGrouping: GroupingType = .day
    @State private var showingHistory = false
    
    @State private var selectedSide = "none"

    // 新種目追加
    @State private var showingAddExercise = false
    @State private var newExerciseName = ""

    // 前回比
    @State private var diffText: String = ""
    @State private var diffColor: Color = .secondary

    let bodyParts = ["胸", "背中", "脚", "肩", "腕", "腹筋"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // ✅ カレンダー
                    CalendarView(selectedDate: $selectedDate, markedDates: entries.map { $0.date })
                        .frame(height: 340)
                        .padding(.top, 8)

                    // ✅ 部位ボタン
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(bodyParts, id: \.self) { part in
                                Button {
                                    selectedBodyPart = part
                                    selectedExercise = exercises[part]?.first ?? ""
                                    updateLastDiff()
                                } label: {
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

                    // ✅ 種目選択 + 追加
                    HStack {
                        Picker("種目", selection: $selectedExercise) {
                            ForEach(exercises[selectedBodyPart] ?? [], id: \.self) { ex in
                                Text(ex)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedExercise, initial: true) { _, _ in
                            updateLastDiff()
                        }

                        Spacer()
                        Button {
                            showingAddExercise = true
                        } label: {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.blue)
                                .font(.title3)
                        }
                    }
                    .padding(.horizontal)

                    // ✅ 新種目追加ダイアログ
                    .alert("新しい種目を追加", isPresented: $showingAddExercise) {
                        TextField("種目名を入力", text: $newExerciseName)
                        Button("追加") {
                            addNewExercise()
                        }
                        Button("キャンセル", role: .cancel) { }
                    } message: {
                        Text("\(selectedBodyPart) に新しい種目を追加します")
                    }

                    // ✅ 前回比
                    if !diffText.isEmpty {
                        Text(diffText)
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(diffColor)
                            .frame(maxWidth: .infinity)
                    }

                    // ✅ 履歴画面へ
                    Button { showingHistory = true } label: {
                        Label("過去の記録を見る", systemImage: "clock.arrow.circlepath")
                            .foregroundColor(.blue)
                    }
                    .sheet(isPresented: $showingHistory) {
                        HistoryView(entries: entries.filter { $0.exercise == selectedExercise },
                                    exerciseName: selectedExercise)
                    }

                    // ✅ 入力フォーム
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("自重トレーニング", isOn: $isBodyweight)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .padding(.horizontal)
                        
                        // 左右選択（自重トグルの下）
                        VStack(alignment: .leading, spacing: 6) {
                            Text("左右")
                                .font(.headline)

                            Picker("Side", selection: $selectedSide) {
                                Text("左").tag("L")
                                Text("右").tag("R")
                                Text("なし").tag("")
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)

                        TextField("重量 (kg)", text: $weightText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(isBodyweight)
                            .opacity(isBodyweight ? 0.5 : 1.0)
                            .padding(.horizontal)

                        TextField("回数", text: $repsText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)

                        TextField("メモ（例：フォーム良好／追い込めた）", text: $note)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)

                        Button(action: addSet) {
                            Text("このセットを追加")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }

                    // ✅ グラフ
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
                DatabaseManager.shared.createExerciseTableIfNeeded()
                exercises = DatabaseManager.shared.fetchExercisesByBodyPart()
                entries = DatabaseManager.shared.fetchAll()
                updateLastDiff()
            }
        }
    }

    // ✅ 新しい種目を追加してDBに保存
    private func addNewExercise() {
        guard !newExerciseName.isEmpty else { return }

        // SQLite保存
        DatabaseManager.shared.insertExercise(name: newExerciseName, bodyPart: selectedBodyPart)

        // メモリ上でも即反映
        if var list = exercises[selectedBodyPart] {
            list.append(newExerciseName)
            exercises[selectedBodyPart] = list
        } else {
            exercises[selectedBodyPart] = [newExerciseName]
        }

        selectedExercise = newExerciseName
        newExerciseName = ""
    }

    // ✅ セットを追加
    private func addSet() {
        let weight = isBodyweight ? 0.0 : (Double(weightText) ?? 0.0)
        guard let reps = Int(repsText), !selectedExercise.isEmpty else { return }

        DatabaseManager.shared.insert(
            date: selectedDate,
            bodyPart: selectedBodyPart,
            exercise: selectedExercise,
            weight: weight,
            reps: reps,
            note: note.isEmpty ? nil : note,
            side: selectedSide   // ← 追加！
        )

        entries = DatabaseManager.shared.fetchAll()
        weightText = ""
        repsText = ""
        note = ""
        isBodyweight = false
        selectedSide = "none"   // ← リセットすると使いやすい
        updateLastDiff()
    }

    // ✅ 前回比更新
    private func updateLastDiff() {
        let recs = DatabaseManager.shared.fetchLastTwoRecords(for: selectedExercise)
        guard recs.count == 2 else {
            diffText = recs.count == 1 ? "前回記録なし" : ""
            diffColor = .secondary
            return
        }
        let latest = recs[0]
        let prev = recs[1]

        let wDiff = Int(latest.weight - prev.weight)
        let rDiff = latest.reps - prev.reps

        let wText = (latest.weight == 0 && prev.weight == 0)
            ? "±0kg"
            : "\(wDiff >= 0 ? "+" : "")\(wDiff)kg"
        let rText = "\(rDiff >= 0 ? "+" : "")\(rDiff)回"

        diffText = "前回比: \(wText) / \(rText)"
        diffColor = (wDiff > 0 || rDiff > 0) ? .green : (wDiff < 0 || rDiff < 0) ? .red : .gray
    }
}

// MARK: - グルーピングタイプ
enum GroupingType: String, CaseIterable, Identifiable {
    case day, week, month
    var id: String { rawValue }
}


//PR練習中です。　sideブランチ


