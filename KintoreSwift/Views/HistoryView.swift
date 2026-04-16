// HistoryView.swift


import SwiftUI

struct HistoryView: View {

    let selectedDate: Date
    @StateObject private var viewModel = HistoryViewModel()
    @EnvironmentObject private var contentViewModel: ContentViewModel
    @State private var editingEntry = SetEntry(
        id: -1,
        date: Date(),
        bodyPart: "",
        exercise: "",
        weight: 0,
        reps: 0,
        note: nil,
        side: ""
    )
    @State private var showEditSheet = false
    @State private var showAddSheet = false

    private var dateTitle: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f.string(from: selectedDate)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // 日付
                    Text(dateTitle)
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)

                    if viewModel.entries.isEmpty {
                        Text("この日の記録はありません")
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 16)
                    }

                    ForEach(viewModel.entries) { entry in
                        DaySetRow(entry: entry) {
                            editingEntry = entry
                            showEditSheet = true
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                }
            }
        }
        .onAppear {
            reload()
        }
        .sheet(isPresented: $showEditSheet) {
            EditSetView(entry: $editingEntry) { updated in
                DatabaseManager.shared.updateSet(updated)
                reload()
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showAddSheet) {
            DaySetAddView(
                date: selectedDate,
                exercises: contentViewModel.exercises
            ) { bodyPart, exercise, weight, reps, note, side in
                contentViewModel.addSet(
                    date: selectedDate,
                    bodyPart: bodyPart,
                    exercise: exercise,
                    weight: weight,
                    reps: reps,
                    note: note,
                    side: side
                )
                reload()
            }
            .preferredColorScheme(.dark)
        }
    }

    private func reload() {
        contentViewModel.loadInitialData()
        viewModel.load(date: selectedDate)
    }
}

private struct DaySetRow: View {
    let entry: SetEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.exercise)
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Text(entry.bodyPart)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.16))
                        .clipShape(Capsule())
                }

                Text(setText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.86))

                if let note = entry.note, note.isEmpty == false {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.58))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.card)
            .cornerRadius(16)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    private var setText: String {
        let base = entry.weight == 0
            ? "自重 × \(entry.reps)回"
            : "\(weightText(entry.weight))kg × \(entry.reps)回"
        guard let side = entry.side, side.isEmpty == false else { return base }
        return "\(base)（\(side)）"
    }

    private func weightText(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

private struct DaySetAddView: View {
    let date: Date
    let exercises: [String: [String]]
    let onSave: (String, String, Double, Int, String?, String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var bodyPart = "胸"
    @State private var exercise = ""
    @State private var weight = ""
    @State private var reps = ""
    @State private var side = ""
    @State private var note = ""

    private let bodyPartOrder = ["胸", "背中", "脚", "肩", "腕", "腹筋"]
    private var availableBodyParts: [String] {
        bodyPartOrder.filter { exercises[$0]?.isEmpty == false }
    }
    private var availableExercises: [String] {
        exercises[bodyPart] ?? []
    }
    private var canSave: Bool {
        exercise.isEmpty == false && Int(reps) != nil
    }

    var body: some View {
        NavigationView {
            Form {
                Picker("部位", selection: $bodyPart) {
                    ForEach(availableBodyParts, id: \.self) { part in
                        Text(part).tag(part)
                    }
                }

                Picker("種目", selection: $exercise) {
                    ForEach(availableExercises, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }

                TextField("重量 (kg)", text: $weight)
                    .keyboardType(.decimalPad)

                TextField("回数", text: $reps)
                    .keyboardType(.numberPad)

                Picker("左右", selection: $side) {
                    Text("左").tag("L")
                    Text("右").tag("R")
                    Text("なし").tag("")
                }
                .pickerStyle(.segmented)

                TextField("メモ", text: $note)
            }
            .navigationTitle("記録を追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(
                            bodyPart,
                            exercise,
                            Double(weight) ?? 0,
                            Int(reps) ?? 0,
                            note.isEmpty ? nil : note,
                            side
                        )
                        dismiss()
                    }
                    .disabled(canSave == false)
                }
            }
            .onAppear {
                normalizeSelection()
            }
            .onChange(of: bodyPart) { _, _ in
                normalizeSelection()
            }
        }
    }

    private func normalizeSelection() {
        if availableBodyParts.contains(bodyPart) == false {
            bodyPart = availableBodyParts.first ?? "胸"
        }
        if availableExercises.contains(exercise) == false {
            exercise = availableExercises.first ?? ""
        }
    }
}
