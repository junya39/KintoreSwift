//  ContentView.swift

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
    @State private var exercises: [String: [String]] = [:]
    @State private var chartGrouping: GroupingType = .day

    @State private var selectedSide = ""
    @State private var dailyEntries: [SetEntry] = []

    // 新種目追加
    @State private var showingAddExercise = false
    @State private var newExerciseName = ""

    // 編集シート
    @State private var showingEditSheet = false
    @State private var editingEntry: SetEntry? = nil

    // 前回比
    @State private var diffText: String = ""
    @State private var diffColor: Color = .secondary

    let bodyParts = ["胸", "背中", "脚", "肩", "腕", "腹筋"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {

                    // MARK: - カレンダー
                    CalendarView(selectedDate: $selectedDate, markedDates: entries.map { $0.date })
                        .frame(height: 340)
                        .padding(.top, 8)
                        .onChange(of: selectedDate) { _, _ in
                            updateDailyEntries()
                            diffText = ""
                        }

                    // MARK: - 部位選択
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
                        }
                        .padding(.horizontal)
                    }

                    // MARK: - 種目選択 + 追加
                    HStack {
                        Picker("種目", selection: $selectedExercise) {
                            ForEach(exercises[selectedBodyPart] ?? [], id: \.self) { ex in
                                Text(ex)
                            }
                        }
                        .pickerStyle(.menu)

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
                    .alert("新しい種目を追加", isPresented: $showingAddExercise) {
                        TextField("種目名を入力", text: $newExerciseName)
                        Button("追加") { addNewExercise() }
                        Button("キャンセル", role: .cancel) {}
                    }

                    // MARK: - 前回比
                    if !diffText.isEmpty && diffText != "前回記録なし" {
                        Text(diffText)
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(diffColor)
                            .frame(maxWidth: .infinity)
                    }

                    // MARK: - 日付別記録リスト
                    if !dailyEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(formattedDate(selectedDate)) の記録")
                                .font(.headline)
                                .padding(.horizontal)

                            List {
                                ForEach(dailyEntries, id: \.id) { entry in
                                    VStack(alignment: .leading, spacing: 6) {

                                        Text(entry.exercise)
                                            .font(.subheadline).bold()

                                        HStack {
                                            Text("\(Int(entry.weight))kg × \(entry.reps)回")
                                            if let side = entry.side, !side.isEmpty {
                                                Text(side == "R" ? "(右)" : "(左)")
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        if let note = entry.note, !note.isEmpty {
                                            Text("💬 \(note)").font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(6)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingEntry = entry
                                        showingEditSheet = true
                                    }
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            deleteSet(entry)
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .frame(height: CGFloat(dailyEntries.count) * 90)
                            .listStyle(.plain)
                        }
                    }

                    // MARK: - 入力フォーム
                    inputForm

                    // MARK: - グラフ
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
                updateDailyEntries()
            }

            // MARK: - 編集シート（これだけで OK）
            .sheet(isPresented: $showingEditSheet) {
                if let e = editingEntry {
                    EditSetView(
                        entry: Binding(
                            get: { e },
                            set: { editingEntry = $0 }
                        )
                    ) { updated in
                        DatabaseManager.shared.updateSet(updated)
                        entries = DatabaseManager.shared.fetchAll()
                        updateDailyEntries()
                        updateLastDiff()
                    }
                }
            }
        }
    }

    // MARK: - 入力フォーム
    private var inputForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("自重トレーニング", isOn: $isBodyweight)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 6) {
                Text("左右").font(.headline)
                Picker("Side", selection: $selectedSide) {
                    Text("左").tag("L")
                    Text("右").tag("R")
                    Text("なし").tag("")
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)

            TextField("重量 (kg)", text: $weightText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .disabled(isBodyweight)
                .opacity(isBodyweight ? 0.5 : 1.0)
                .padding(.horizontal)

            TextField("回数", text: $repsText)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            TextField("メモ（例：フォーム良好／追い込めた）", text: $note)
                .textFieldStyle(.roundedBorder)
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
    }

    // MARK: - ロジック類
    private func addNewExercise() {
        guard !newExerciseName.isEmpty else { return }

        DatabaseManager.shared.insertExercise(name: newExerciseName, bodyPart: selectedBodyPart)

        exercises[selectedBodyPart, default: []].append(newExerciseName)
        selectedExercise = newExerciseName
        newExerciseName = ""
    }

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
            side: selectedSide
        )

        entries = DatabaseManager.shared.fetchAll()
        weightText = ""
        repsText = ""
        note = ""
        isBodyweight = false
        selectedSide = ""
        updateLastDiff()
        updateDailyEntries()
    }

    private func deleteSet(_ entry: SetEntry) {
        DatabaseManager.shared.delete(id: entry.id)
        entries = DatabaseManager.shared.fetchAll()
        updateDailyEntries()
        updateLastDiff()
    }

    private func updateDailyEntries() {
        dailyEntries = entries.filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }
    }

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

        diffText = "前回比: \(wDiff >= 0 ? "+" : "")\(wDiff)kg / \(rDiff >= 0 ? "+" : "")\(rDiff)回"
        diffColor = wDiff > 0 || rDiff > 0 ? .green : (wDiff < 0 || rDiff < 0 ? .red : .gray)
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: date)
    }
}


// MARK: - グルーピングタイプ
enum GroupingType: String, CaseIterable, Identifiable {
    case day, week, month
    var id: String { rawValue }
}
