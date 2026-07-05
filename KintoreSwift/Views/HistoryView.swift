// HistoryView.swift


import SwiftUI

struct HistoryView: View {

    let selectedDate: Date
    @StateObject private var viewModel = HistoryViewModel()
    @EnvironmentObject private var contentViewModel: ContentViewModel
    @State private var showAddSheet = false

    // 種目カードタップで種目別履歴へ遷移する
    @State private var exerciseForDetail = ""
    @State private var showExerciseDetail = false

    private var dateTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日（E）"
        return f.string(from: selectedDate)
    }

    private var exerciseCount: Int {
        Set(viewModel.entries.map { $0.exercise }).count
    }

    private var totalVolume: Int {
        Int(viewModel.entries.reduce(0) { $0 + ($1.weight * Double($1.reps)) })
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {

                    // 日付
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3.weight(.heavy))
                            .foregroundColor(.gameGold)

                        Text(dateTitle)
                            .font(.title.weight(.heavy))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 16)

                    if viewModel.entries.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.title2.weight(.bold))
                                .foregroundColor(.gamePurpleLight)

                            Text("この日の記録はありません")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                    } else {
                        HistorySummaryBand(
                            exerciseCount: exerciseCount,
                            setCount: viewModel.entries.count,
                            volume: totalVolume
                        )
                        .padding(.horizontal, 16)
                    }

                    ForEach(viewModel.entries) { entry in
                        DaySetRow(entry: entry) {
                            exerciseForDetail = entry.exercise
                            showExerciseDetail = true
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 32)
            }
        }
        .fontDesign(.rounded)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                }
                .tint(.gameGold)
            }
        }
        .onAppear {
            reload()
        }
        .navigationDestination(isPresented: $showExerciseDetail) {
            if exerciseForDetail.isEmpty == false {
                ExerciseDetailView(
                    exerciseName: exerciseForDetail,
                    contentViewModel: contentViewModel
                )
            }
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
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
    }

    private func reload() {
        contentViewModel.loadInitialData()
        viewModel.load(date: selectedDate)
    }
}

private struct HistorySummaryBand: View {
    let exerciseCount: Int
    let setCount: Int
    let volume: Int

    var body: some View {
        HStack(spacing: 0) {
            summaryItem(icon: "dumbbell.fill", value: "\(exerciseCount)", unit: "種目")
            summaryItem(icon: "checkmark.circle.fill", value: "\(setCount)", unit: "セット")
            summaryItem(icon: "scalemass.fill", value: volume.formatted(), unit: "kg")
        }
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.gameGold.opacity(0.3), lineWidth: 1)
        )
    }

    private func summaryItem(icon: String, value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
                .foregroundColor(.gameGold)

            Text(value)
                .font(.subheadline.weight(.heavy))
                .foregroundColor(.white)
                .monospacedDigit()

            Text(unit)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
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
                        .font(.headline.weight(.heavy))
                        .foregroundColor(.white)

                    Spacer()

                    Text(entry.bodyPart)
                        .font(.caption.weight(.heavy))
                        .foregroundColor(.gameGold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.gameGold.opacity(0.15))
                        .clipShape(Capsule())

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                }

                Text(setText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.86))
                    .monospacedDigit()

                if let note = entry.note, note.isEmpty == false {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.58))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
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
        NavigationStack {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
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
        .fontDesign(.rounded)
        .tint(.gameGold)
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
