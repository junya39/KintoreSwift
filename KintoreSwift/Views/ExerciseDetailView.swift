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

    private var totalVolume: Int {
        Int(viewModel.history.reduce(0) { $0 + ($1.weight * Double($1.reps)) })
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日（E）"
        return formatter
    }()

    private func japaneseDateText(_ date: Date) -> String {
        Self.dayFormatter.string(from: date)
    }


    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    titleHeader
                    statsBand
                    chartCard
                    historyList
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .fontDesign(.rounded)
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
                        .font(.system(size: 16, weight: .bold))
                }
                .tint(.gameGold)
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
                        reps: updated.reps,
                        note: updated.note,
                        side: updated.side ?? ""
                    )
                } else {
                    viewModel.updateSet(updated)
                }
                viewModel.load(exercise: exerciseName)
            }
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
        .navigationTitle("種目別履歴")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 見出し（種目名＋部位バッジ）

    private var titleHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "dumbbell.fill")
                .font(.title3.weight(.heavy))
                .foregroundColor(.gameGold)

            Text(exerciseName)
                .font(.title.weight(.heavy))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 6)

            let bodyPart = viewModel.bodyPart(for: exerciseName)
            if bodyPart.isEmpty == false {
                Text(bodyPart)
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.gameGold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.gameGold.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - 統計バンド（履歴画面のサマリーバンドと同意匠）

    @ViewBuilder
    private var statsBand: some View {
        if viewModel.history.isEmpty == false {
            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    if viewModel.maxWeight > 0 {
                        statItem(icon: "chart.bar.fill", value: String(format: "%.1f", viewModel.averageWeight), unit: "kg 平均")
                        statItem(icon: "crown.fill", value: weightText(viewModel.maxWeight), unit: "kg 最大")
                    }
                    statItem(icon: "checkmark.circle.fill", value: "\(viewModel.totalReps)", unit: "レップ")
                    if totalVolume > 0 {
                        statItem(icon: "scalemass.fill", value: totalVolume.formatted(), unit: "kg 総量")
                    }
                }

                if viewModel.bodyweightSets > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)

                    HStack(spacing: 0) {
                        statItem(icon: "figure.strengthtraining.traditional", value: "\(viewModel.bodyweightMaxReps)", unit: "回 自重最大")
                        statItem(icon: "sum", value: "\(viewModel.bodyweightTotalReps)", unit: "回 自重合計")
                    }
                }
            }
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.gameGold.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func statItem(icon: String, value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
                .foregroundColor(.gameGold)

            Text(value)
                .font(.subheadline.weight(.heavy))
                .foregroundColor(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(unit)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - グラフカード

    @ViewBuilder
    private var chartCard: some View {
        if groupedHistory.isEmpty == false {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.caption.weight(.heavy))
                        .foregroundColor(.gamePurpleLight)

                    Text(isBodyweightOnly ? "最大回数の推移" : "最大重量の推移")
                        .font(.caption.weight(.heavy))
                        .foregroundColor(.gamePurpleLight)
                }

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
                    .foregroundStyle(Color.gameGold)
                }
                .frame(height: 190)
                .chartXAxis {
                    AxisMarks {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                            .foregroundStyle(Color.white.opacity(0.12))
                        AxisTick()
                            .foregroundStyle(Color.white.opacity(0.3))
                        AxisValueLabel(format: .dateTime.month().day().locale(Locale(identifier: "ja_JP")))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                            .foregroundStyle(Color.white.opacity(0.1))
                        AxisTick()
                            .foregroundStyle(Color.white.opacity(0.3))
                        AxisValueLabel()
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    // MARK: - 日付ごとのセット一覧

    @ViewBuilder
    private var historyList: some View {
        if groupedHistory.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "moon.zzz.fill")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.gamePurpleLight)

                Text("この種目の記録はまだありません")
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
        } else {
            ForEach(groupedHistory, id: \.0) { day, entries in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption.weight(.heavy))
                            .foregroundColor(.gameGold)

                        Text(japaneseDateText(day))
                            .font(.subheadline.weight(.heavy))
                            .foregroundColor(.white.opacity(0.9))
                            .monospacedDigit()
                    }
                    .padding(.top, 4)

                    ForEach(entries, id: \.id) { entry in
                        entryRow(entry)
                    }
                }
            }
        }
    }

    private func entryRow(_ entry: SetEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if entry.weight == 0 {
                    Text("自重 × \(entry.reps) 回")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .monospacedDigit()
                } else {
                    Text("\(weightText(entry.weight)) kg × \(entry.reps) 回")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .monospacedDigit()
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
                        .padding(7)
                        .background(Color.red.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            if let note = entry.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.58))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            editingEntry = entry
            isNewEntry = false
            isEditSheetPresented = true
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
