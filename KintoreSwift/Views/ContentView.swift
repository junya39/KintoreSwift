//ContentView.swift

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
    @State private var showingAddExercise = false
    @State private var newExerciseName = ""
    @State private var showingEditSheet = false
    @State private var editingEntry: SetEntry? = nil
    @State private var diffText: String = ""
    @State private var diffColor: Color = .secondary
    @State private var showingEditExercise = false
    @State private var editExerciseName = ""
    @State private var editExerciseBodyPart = "胸"
    
    @State private var showExerciseDetail = false
    @State private var detailExerciseName = ""


    

    let bodyParts = ["胸", "背中", "脚", "肩", "腕", "腹筋"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    CalendarSection(
                        selectedDate: $selectedDate,
                        entries: entries,
                        onDateChange: {
                            updateDailyEntries()
                            diffText = ""
                        }
                    )

                    BodyPartSection(
                        selectedBodyPart: $selectedBodyPart,
                        exercises: exercises,
                        selectedExercise: $selectedExercise,
                        bodyParts: bodyParts,
                        onSelect: updateLastDiff
                    )

                    ExercisePickerSection(
                        selectedExercise: $selectedExercise,
                        exercises: exercises[selectedBodyPart] ?? [],
                        onAdd: { showingAddExercise = true },
                        onEdit: {
                            editExerciseName = selectedExercise
                            editExerciseBodyPart = selectedBodyPart
                            showingEditExercise = true
                        }
                    )
                    
                    DailyListSection(
                        dailyEntries: dailyEntries,
                        onTap: { entry in
                            editingEntry = entry
                            showingEditSheet = true
                        },
                        onDelete: { entry in
                            deleteSet(entry)
                        },
                        onTapExercise: { name in
                            detailExerciseName = name
                            showExerciseDetail = true
                        }
                    )


                        .alert("新しい種目を追加", isPresented: $showingAddExercise) {
                            TextField("種目名を入力", text: $newExerciseName)
                            Button("追加") { addNewExercise() }
                            Button("キャンセル", role: .cancel) {}
                        }
                    
                        .sheet(isPresented: $showingEditExercise) {
                            VStack(spacing: 20) {
                                Text("種目を編集")
                                    .font(.headline)

                                TextField("名前", text: $editExerciseName)
                                    .textFieldStyle(.roundedBorder)
                                    .padding()

                                Picker("部位", selection: $editExerciseBodyPart) {
                                    ForEach(bodyParts, id: \.self) { Text($0) }
                                }
                                .pickerStyle(.wheel)

                                Button("保存") {
                                    updateExercise()
                                    showingEditExercise = false
                                }
                                .padding()
                            }
                            .presentationDetents([.medium])
                        }


                    DiffSection(diffText: diffText, diffColor: diffColor)



                    InputFormSection(
                        isBodyweight: $isBodyweight,
                        selectedSide: $selectedSide,
                        weightText: $weightText,
                        repsText: $repsText,
                        note: $note,
                        onAdd: addSet
                    )

                    ChartSection(entries: entries, chartGrouping: $chartGrouping)
                }
                .padding(.bottom, 32)
            }
            
            .navigationDestination(isPresented: $showExerciseDetail) {
                ExerciseDetailView(exerciseName: detailExerciseName)
            }

            .navigationTitle("Workout")
            .onAppear {
                DatabaseManager.shared.createExerciseTableIfNeeded()
                exercises = DatabaseManager.shared.fetchExercisesByBodyPart()
                entries = DatabaseManager.shared.fetchAll()
                updateLastDiff()
                updateDailyEntries()
            }
            .sheet(isPresented: $showingEditSheet) {
                if let e = editingEntry {
                    EditSetView(
                        entry: Binding(get: { e }, set: { editingEntry = $0 })
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
        DatabaseManager.shared.insert(date: selectedDate, bodyPart: selectedBodyPart, exercise: selectedExercise, weight: weight, reps: reps, note: note.isEmpty ? nil : note, side: selectedSide)
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
        dailyEntries = entries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
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
        diffColor = (wDiff > 0 || rDiff > 0) ? .green : (wDiff < 0 || rDiff < 0 ? .red : .gray)
    }
    
    private func updateExercise() {
        DatabaseManager.shared.updateExercise(
            name: selectedExercise,
            newName: editExerciseName,
            newBodyPart: editExerciseBodyPart
        )

        exercises = DatabaseManager.shared.fetchExercisesByBodyPart()
        selectedExercise = editExerciseName
    }

}


// MARK: - Section Views ---------------------------------------------------------

private struct CalendarSection: View {
    @Binding var selectedDate: Date
    let entries: [SetEntry]
    let onDateChange: () -> Void

    var body: some View {
        CalendarView(selectedDate: $selectedDate, markedDates: entries.map { $0.date })
            .frame(height: 340)
            .padding(.top, 8)
            .padding(.horizontal, 16)
            .onChange(of: selectedDate) { _, _ in onDateChange() }
    }
}

private struct BodyPartSection: View {
    @Binding var selectedBodyPart: String
    let exercises: [String: [String]]
    @Binding var selectedExercise: String
    let bodyParts: [String]
    let onSelect: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(bodyParts, id: \.self) { part in
                    Button {
                        selectedBodyPart = part
                        selectedExercise = exercises[part]?.first ?? ""
                        onSelect()
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
            .padding(.horizontal, 16)
        }
    }
}

private struct ExercisePickerSection: View {
    @Binding var selectedExercise: String
    let exercises: [String]
    let onAdd: () -> Void
    let onEdit: () -> Void   // ←追加

    var body: some View {
        HStack {
            Picker("種目", selection: $selectedExercise) {
                ForEach(exercises, id: \.self) { Text($0) }
            }
            .pickerStyle(.menu)

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
                    .font(.title3)
            }

            Button(action: onAdd) {
                Image(systemName: "plus.circle")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
        }
        .padding(.horizontal, 16)
    }
}


private struct DiffSection: View {
    let diffText: String
    let diffColor: Color

    var body: some View {
        if !diffText.isEmpty && diffText != "前回記録なし" {
            Text(diffText)
                .font(.subheadline)
                .bold()
                .foregroundColor(diffColor)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct DailyListSection: View {
    let dailyEntries: [SetEntry]
    let onTap: (SetEntry) -> Void
    let onDelete: (SetEntry) -> Void
    let onTapExercise: (String) -> Void

    // 種目毎にグループ化
    private var groupedEntries: [String: [SetEntry]] {
        Dictionary(grouping: dailyEntries, by: { $0.exercise })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            if !dailyEntries.isEmpty {
                Text("本日の記録")
                    .font(.headline)
                    .padding(.horizontal, 16)

                VStack(spacing: 24) {
                    ForEach(groupedEntries.keys.sorted(), id: \.self) { exerciseName in
                        let items = groupedEntries[exerciseName] ?? []

                        VStack(alignment: .leading, spacing: 8) {

                            // 種目名（1回だけ）
                            Button {
                                onTapExercise(exerciseName)
                            } label: {
                                Text(exerciseName)
                                    .font(.headline)
                                    .padding(.horizontal, 16)
                                    .foregroundColor(.blue)
                            }


                            VStack(spacing: 8) {
                                ForEach(items, id: \.id) { entry in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("\(Int(entry.weight))kg × \(entry.reps)回")
                                                .font(.subheadline)

                                            if let side = entry.side, !side.isEmpty {
                                                Text(side == "R" ? "(右)" : "(左)")
                                                    .foregroundColor(.secondary)
                                            }

                                            if let note = entry.note, !note.isEmpty {
                                                Text("💬 \(note)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                    .padding(.horizontal, 16)
                                    .onTapGesture { onTap(entry) }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            onDelete(entry)
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
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
        VStack(alignment: .leading, spacing: 16) {
            Toggle("自重トレーニング", isOn: $isBodyweight)
                .toggleStyle(SwitchToggleStyle(tint: .blue))

            VStack(alignment: .leading, spacing: 6) {
                Text("左右").font(.headline)
                Picker("Side", selection: $selectedSide) {
                    Text("左").tag("L")
                    Text("右").tag("R")
                    Text("なし").tag("")
                }
                .pickerStyle(.segmented)
            }

            TextField("重量 (kg)", text: $weightText)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedFieldStyle())
                .disabled(isBodyweight)
                .opacity(isBodyweight ? 0.5 : 1.0)

            TextField("回数", text: $repsText)
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedFieldStyle())

            TextField("メモ（例：フォーム良好／追い込めた）", text: $note)
                .textFieldStyle(RoundedFieldStyle())

            PrimaryButton(title: "このセットを追加") { onAdd() }
        }
        .padding(16)
        .background(Color(.systemGray5))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

private struct ChartSection: View {
    let entries: [SetEntry]
    @Binding var chartGrouping: GroupingType

    var groupedEntries: [(Date, Double)] {
        switch chartGrouping {
        case .day:
            return Dictionary(grouping: entries, by: { Calendar.current.startOfDay(for: $0.date) })
                .map { (key, values) in
                    (key, values.map { $0.weight }.max() ?? 0)
                }
                .sorted { $0.0 < $1.0 }

        case .week:
            return Dictionary(grouping: entries, by: { Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: $0.date)) ?? $0.date })
                .map { (key, values) in
                    (key, values.map { $0.weight }.max() ?? 0)
                }
                .sorted { $0.0 < $1.0 }

        case .month:
            return Dictionary(grouping: entries, by: { Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: $0.date)) ?? $0.date })
                .map { (key, values) in
                    (key, values.map { $0.weight }.max() ?? 0)
                }
                .sorted { $0.0 < $1.0 }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Grouping", selection: $chartGrouping) {
                Text("日").tag(GroupingType.day)
                Text("週").tag(GroupingType.week)
                Text("月").tag(GroupingType.month)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            Chart {
                ForEach(groupedEntries, id: \.0) { (date, value) in
                    LineMark(
                        x: .value("Date", date),
                        y: .value("Weight", value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.blue)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    PointMark(
                        x: .value("Date", date),
                        y: .value("Weight", value)
                    )
                    .foregroundStyle(Color.blue)
                }
            }
            .frame(height: 220)
            .padding(.horizontal, 16)
        }
    }
}


enum GroupingType: String, CaseIterable, Identifiable {
    case day, week, month
    var id: String { rawValue }
}
