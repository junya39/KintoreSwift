// WorkoutView.swift

import SwiftUI
import Charts

struct WorkoutView: View {

    // MARK: - State
    @State private var selectedDate = Date()
    @State private var selectedBodyPart = "胸"
    @State private var selectedExercise = "ベンチプレス"

    @State private var weightText = ""
    @State private var repsText = ""
    @State private var note = ""
    @State private var isBodyweight = false
    @State private var selectedSide = ""

    @State private var showingAddExercise = false
    @State private var newExerciseName = ""

    @StateObject private var viewModel = ContentViewModel()

    // ✅ 日付タップで履歴へ遷移するためのフラグ
    @State private var showHistory = false

    private let bodyParts = ["胸", "背中", "脚", "肩", "腕", "腹筋"]

    // MARK: - Computed
    private var todayTotalVolume: Int {
        Int(viewModel.dailyEntries.reduce(0) { $0 + ($1.weight * Double($1.reps)) })
    }

    private var level: Int {
        max(1, todayTotalVolume / 500 + 1)
    }

    private var levelProgress: Double {
        Double(todayTotalVolume % 500) / 500
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {

                // =========================
                // 情報表示エリア（スクロール）
                // =========================
                ScrollView {
                    VStack(spacing: 16) {

                        HeaderSection(level: level, progress: levelProgress)

                        CalendarSection(
                            selectedDate: $selectedDate,
                            entries: viewModel.entries
                        )

                        BodyPartSection(
                            selectedBodyPart: $selectedBodyPart,
                            exercises: viewModel.exercises,
                            selectedExercise: $selectedExercise,
                            bodyParts: bodyParts
                        )

                        ExercisePickerSection(
                            selectedExercise: $selectedExercise,
                            exercises: viewModel.exercises[selectedBodyPart] ?? [],
                            onAdd: { showingAddExercise = true }
                        )

                        DailyListSection(
                            dailyEntries: viewModel.dailyEntries
                        )

                        if !viewModel.dailyEntries.isEmpty {
                            TodaySummarySection(totalVolume: todayTotalVolume)
                        }
                    }
                    .padding(.bottom, 260) // 👈 入力フォーム分の余白
                }

                // =========================
                // 入力フォーム（固定）
                // =========================
                InputFormSection(
                    isBodyweight: $isBodyweight,
                    selectedSide: $selectedSide,
                    weightText: $weightText,
                    repsText: $repsText,
                    note: $note,
                    onAdd: addSet
                )
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("")
            .onAppear {
                viewModel.loadInitialData()
                viewModel.updateDailyEntries(for: selectedDate)
            }

            // ✅ カレンダーで日付が変わった瞬間に「その日」の一覧へ
            .onChange(of: selectedDate) { _, newValue in
                viewModel.updateDailyEntries(for: newValue)
                showHistory = true
            }

            // ✅ iOS 16+ 推奨の遷移（deprecated回避）
            .navigationDestination(isPresented: $showHistory) {
                // HistoryView が「selectedDate だけ」を受け取る前提
                HistoryView(selectedDate: selectedDate)
            }

            .sheet(isPresented: $showingAddExercise) {
                VStack(spacing: 16) {
                    Text("新しい種目を追加")
                        .font(.headline)

                    TextField("種目名", text: $newExerciseName)
                        .keyboardType(.default)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("キャンセル") {
                            showingAddExercise = false
                        }

                        Button("追加") {
                            addNewExercise()
                            showingAddExercise = false
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Actions
    private func addSet() {
        guard let reps = Int(repsText), !selectedExercise.isEmpty else { return }

        let weight = isBodyweight ? 0 : (Double(weightText) ?? 0)

        DatabaseManager.shared.insert(
            date: selectedDate,
            bodyPart: selectedBodyPart,
            exercise: selectedExercise,
            weight: weight,
            reps: reps,
            note: note.isEmpty ? nil : note,
            side: selectedSide
        )

        viewModel.loadInitialData()
        viewModel.updateDailyEntries(for: selectedDate)

        weightText = ""
        repsText = ""
        note = ""
        selectedSide = ""
        isBodyweight = false
    }

    private func addNewExercise() {
        guard !newExerciseName.isEmpty else { return }
        DatabaseManager.shared.insertExercise(
            name: newExerciseName,
            bodyPart: selectedBodyPart
        )
        viewModel.exercises[selectedBodyPart, default: []].append(newExerciseName)
        selectedExercise = newExerciseName
        newExerciseName = ""
    }
}

//
// MARK: - Sections
//

private struct HeaderSection: View {
    let level: Int
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout")
                .font(.largeTitle.bold())
                .foregroundColor(.white)

            HStack {
                Text("Lv \(level)")
                    .foregroundColor(.white)

                ProgressView(value: progress)
                    .tint(.accent)
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct TodaySummarySection: View {
    let totalVolume: Int

    var body: some View {
        HStack {
            Text("合計")
                .foregroundColor(.white.opacity(0.6))

            Spacer()

            Text("\(totalVolume) kg")
                .foregroundColor(.green)
                .bold()
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
        .padding(.horizontal, 16)
    }
}

private struct CalendarSection: View {
    @Binding var selectedDate: Date
    let entries: [SetEntry]

    var body: some View {
        CalendarView(
            selectedDate: $selectedDate,
            markedDates: entries.map { $0.date }
        )
        .frame(height: 220)
        .background(Color.card)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
}

private struct BodyPartSection: View {
    @Binding var selectedBodyPart: String
    let exercises: [String: [String]]
    @Binding var selectedExercise: String
    let bodyParts: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(bodyParts, id: \.self) { part in
                    Button {
                        selectedBodyPart = part
                        selectedExercise = exercises[part]?.first ?? ""
                    } label: {
                        Text(part)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selectedBodyPart == part
                                ? Color.green.opacity(0.25)
                                : Color.white.opacity(0.08)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

private struct ExercisePickerSection: View {
    @Binding var selectedExercise: String
    let exercises: [String]
    let onAdd: () -> Void

    var body: some View {
        HStack {
            Text(selectedExercise)
                .font(.title3.bold())
                .foregroundColor(.white)

            Spacer()

            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            }
        }
        .padding()
        .background(Color.card)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
}

private struct DailyListSection: View {
    let dailyEntries: [SetEntry]

    private func weightText(_ w: Double) -> String {
        w == 0 ? "自重" : "\(Int(w))kg"
    }

    var body: some View {
        if !dailyEntries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("本日の記録")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)

                ForEach(dailyEntries, id: \.id) { entry in
                    HStack {
                        Text("\(weightText(entry.weight)) × \(entry.reps)回")
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                    .background(Color.card)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

private struct InputFormSection: View {
    @Binding var isBodyweight: Bool
    @Binding var selectedSide: String
    @Binding var weightText: String
    @Binding var repsText: String
    @Binding var note: String
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Toggle("自重トレーニング", isOn: $isBodyweight)

            Picker("左右", selection: $selectedSide) {
                Text("左").tag("L")
                Text("右").tag("R")
                Text("なし").tag("")
            }
            .pickerStyle(.segmented)

            TextField("重量 (kg)", text: $weightText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .disabled(isBodyweight)

            TextField("回数", text: $repsText)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)

            TextField("メモ", text: $note)
                .textFieldStyle(.roundedBorder)

            Button(action: onAdd) {
                Text("このセットを追加")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
        }
        .padding()
        .background(Color.card)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
}
