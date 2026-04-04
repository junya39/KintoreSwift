//ExerciseDetailView.swift

// TODO: history を viewModel.history に統一する（Viewの@State削除）


import SwiftUI
import Charts

struct ExerciseDetailView: View {

    let exerciseName: String
    @StateObject private var viewModel: ExerciseDetailViewModel

    @State private var isEditSheetPresented = false
    @State private var isNewEntry = false
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

    init(exerciseName: String, contentViewModel: ContentViewModel) {
        self.exerciseName = exerciseName
        _viewModel = StateObject(wrappedValue: ExerciseDetailViewModel(contentViewModel: contentViewModel))
    }

    // ---------------------
    // 日付ごとに履歴をまとめる
    // ---------------------
    var groupedHistory: [(Date, [SetEntry])] {

        let grouped = Dictionary(grouping: viewModel.history) {
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
        viewModel.history.allSatisfy { $0.weight == 0 }
    }

    private func japaneseDateText(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .year()
                .month(.wide)
                .day()
                .locale(Locale(identifier: "ja_JP"))
        )
    }


    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            List {
                titleSection
                statsSection
                chartSection
                historySection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .onAppear {
                viewModel.load(exercise: exerciseName)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editingEntry = SetEntry(
                            id: -1,
                            date: Date(),
                            bodyPart: viewModel.bodyPart(for: exerciseName),
                            exercise: exerciseName,
                            weight: 0,
                            reps: 0,
                            note: nil,
                            side: ""
                        )
                        isNewEntry = true
                        isEditSheetPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isEditSheetPresented) {
                EditSetView(entry: $editingEntry) { updated in
                    if isNewEntry {
                        viewModel.addSet(
                            date: updated.date,
                            bodyPart: updated.bodyPart,
                            exercise: updated.exercise,
                            weight: updated.weight,
                            isBodyweight: updated.weight == 0,
                            reps: updated.reps,
                            note: updated.note,
                            side: updated.side ?? ""
                        )
                    } else {
                        viewModel.updateSet(updated)
                    }
                    viewModel.load(exercise: exerciseName)
                }
            }
        }

        .navigationTitle(exerciseName)
    }

    @ViewBuilder
    private var titleSection: some View {
        Section {
            Text("\(exerciseName) の履歴")
                .font(.title2)
                .bold()
                .foregroundColor(.white)
                .padding(.horizontal)
        }
        .listRowBackground(Color.black)
    }

    @ViewBuilder
    private var statsSection: some View {
        if !viewModel.history.isEmpty {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    if viewModel.maxWeight > 0 {
                        Text("平均重量: \(String(format: "%.1f", viewModel.averageWeight)) kg")
                        Text("最大重量: \(weightText(viewModel.maxWeight)) kg")
                    }

                    Text("総レップ数: \(viewModel.totalReps)")

                    if viewModel.bodyweightSets > 0 {
                        Divider().padding(.vertical, 4)
                        Text("チンニング最大回数: \(viewModel.bodyweightMaxReps) 回")
                        Text("チンニング合計回数: \(viewModel.bodyweightTotalReps) 回")
                    }
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal)
            }
            .listRowBackground(Color.black)
        }
    }

    @ViewBuilder
    private var chartSection: some View {
        if !groupedHistory.isEmpty {
            Section {
                Chart {
                    ForEach(groupedHistory, id: \.0) { day, entries in
                        if isBodyweightOnly {
                            if let maxReps = entries.map({ $0.reps }).max() {
                                LineMark(
                                    x: .value("日付", day),
                                    y: .value("回数", maxReps)
                                )
                                .symbol(.circle)
                            }
                        } else {
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
                .chartXAxis {
                    AxisMarks {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                            .foregroundStyle(Color.white.opacity(0.15))
                        AxisTick()
                            .foregroundStyle(Color.white.opacity(0.35))
                        AxisValueLabel(format: .dateTime.month().day().locale(Locale(identifier: "ja_JP")))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                            .foregroundStyle(Color.white.opacity(0.12))
                        AxisTick()
                            .foregroundStyle(Color.white.opacity(0.35))
                        AxisValueLabel()
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                }
            }
            .listRowBackground(Color.black)
        }
    }

    @ViewBuilder
    private var historySection: some View {
        if groupedHistory.isEmpty {
            Section {
                Text("この種目の記録はまだありません。")
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal)
            }
            .listRowBackground(Color.black)
        } else {
            ForEach(groupedHistory, id: \.0) { day, entries in
                Section {
                    ForEach(entries, id: \.id) { entry in
                        entryRow(entry)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    Text(japaneseDateText(day))
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                        .textCase(nil)
                }
                .listRowBackground(Color.clear)
            }
        }
    }

    private func entryRow(_ entry: SetEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if entry.weight == 0 {
                    Text("自重 × \(entry.reps) 回")
                        .font(.body)
                        .foregroundColor(.white)
                } else {
                    Text("\(weightText(entry.weight)) kg × \(entry.reps) 回")
                        .font(.body)
                        .foregroundColor(.white)
                }

                if let side = entry.side, !side.isEmpty {
                    Text(side == "R" ? "(右)" : "(左)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.55))
                }

                Spacer()

                Button(role: .destructive) {
                    viewModel.delete(entry: entry)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.red)
                        .padding(6)
                        .background(Color.red.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            if let note = entry.note, !note.isEmpty {
                Text("💬 \(note)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            editingEntry = entry
            isNewEntry = false
            isEditSheetPresented = true
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.delete(entry: entry)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    private func weightText(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}
