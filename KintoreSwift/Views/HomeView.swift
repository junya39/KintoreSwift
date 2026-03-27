// HomeView.swift

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = ContentViewModel()
    @EnvironmentObject private var userStatusVM: UserStatusViewModel
    @State private var selectedDate = Date()
    @State private var showDayHistory = false
    @State private var debugOverrideEnabled: Bool = false
    @State private var debugLevel: Int = 1
    @State private var selectedBodyPart = "胸"
    @State private var selectedExercise = ""
    @State private var showAddExerciseSheet = false

    private let bodyPartOrder = ["胸", "背中", "脚", "肩", "腕", "腹筋"]
    private static let homeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日（E）"
        return formatter
    }()
    private var homeMetrics: ContentViewModel.HomeMetrics { viewModel.homeMetrics }
    private var todayText: String {
        Self.homeDateFormatter.string(from: Date())
    }

    private var selectedExerciseVolumeText: String {
        guard !selectedExercise.isEmpty else { return "--" }
        let total = Int(
            viewModel.entries
                .filter { $0.exercise == selectedExercise }
                .reduce(0) { $0 + ($1.weight * Double($1.reps)) }
        )
        return "\(total.formatted()) kg"
    }

    private func normalizeSelection() {
        if selectedExercise.isEmpty || viewModel.exercises[selectedBodyPart, default: []].contains(selectedExercise) == false {
            selectedExercise = viewModel.exercises[selectedBodyPart]?.first ?? ""
        }
    }

    private var displayLevel: Int {
        debugOverrideEnabled ? debugLevel : userStatusVM.level
    }

    private var isEventLogActive: Bool {
        switch viewModel.currentLogEvent {
        case .normalLog:
            return false
        default:
            return true
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // タイトル
                    Text("KintoreSwift")
                        .font(.largeTitle)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(.white)

                    Text(todayText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white.opacity(0.72))
                        .padding(.top, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    CharacterHeaderView(
                        level: displayLevel,
                        progress: userStatusVM.getProgress(),
                        currentXP: userStatusVM.currentXP,
                        requiredXP: userStatusVM.requiredXP(for: userStatusVM.level),
                        power: userStatusVM.power,
                        endurance: userStatusVM.endurance
                    )

                    Text(viewModel.currentLogMessage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: 260, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(isEventLogActive ? 0.95 : 1.0))
                        .overlay(Rectangle().stroke(Color.white, lineWidth: 2))
                        .multilineTextAlignment(.leading)
                        .padding(.vertical, 4)

                    #if DEBUG
                    DebugEvolutionPanelView(
                        enabled: $debugOverrideEnabled,
                        debugLevel: $debugLevel,
                        displayLevel: displayLevel
                    )
                    #endif

                    CalendarSection(
                        selectedDate: $selectedDate,
                        entries: viewModel.entries,
                        onDateTap: {
                            showDayHistory = true
                        }
                    )

                    // 今日のワークアウト
                    VStack(alignment: .leading, spacing: 8) {
                        Text("本日のトレーニング")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.72))

                        Menu {
                            Button {
                                showAddExerciseSheet = true
                            } label: {
                                Label("種目を追加", systemImage: "plus")
                            }

                                Divider()

                                ForEach(bodyPartOrder, id: \.self) { part in
                                    let exercises = viewModel.exercises[part] ?? []
                                    if !exercises.isEmpty {
                                        Section(part) {
                                            ForEach(exercises, id: \.self) { exercise in
                                                Button {
                                                    selectedBodyPart = part
                                                    selectedExercise = exercise
                                                } label: {
                                                    Text(exercise)
                                                }
                                            }
                                        }
                                    }
                                }
                        } label: {
                            HStack {
                                Text(selectedBodyPart)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.15))
                                    .clipShape(Capsule())

                                    Text(selectedExercise.isEmpty ? "種目を選択" : selectedExercise)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    Spacer()

                                    Image(systemName: "chevron.down")
                                        .font(.caption.bold())
                                        .foregroundColor(.white.opacity(0.85))
                            }
                        }

                        HStack {
                            Spacer()

                            Text(selectedExerciseVolumeText)
                                .foregroundColor(.green)
                        }

                        NavigationLink {
                            WorkoutView(
                                initialSelectedBodyPart: selectedBodyPart,
                                initialSelectedExercise: selectedExercise,
                                showInputOnAppear: true
                            )
                        } label: {
                            Text("スタート")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.black)
                                .cornerRadius(16)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.15))
                    .cornerRadius(14)

                    // 全体進捗（仮）
                    VStack(alignment: .leading, spacing: 8) {
                        Text("進捗")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.72))

                            HStack {
                                VStack(alignment: .leading) {
                                    Text("総重量")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.78))
                                    Text("\(homeMetrics.totalVolume.formatted()) kg")
                                        .bold()
                                        .foregroundColor(.white)
                                }

                                Spacer()

                                VStack(alignment: .leading) {
                                    Text("連続")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.78))
                                    Text("\(homeMetrics.streakDays)日")
                                        .bold()
                                        .foregroundColor(.white)
                                }
                            }
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(14)
                }
                .padding()
            }
            .background(Color.black) // ← ★ここが正解位置
            .navigationDestination(isPresented: $showDayHistory) {
                HistoryView(selectedDate: selectedDate)
                    .environmentObject(viewModel)
            }
            .onAppear {
                viewModel.loadInitialData()
                normalizeSelection()
            }
            .onChange(of: selectedBodyPart) { _, _ in
                normalizeSelection()
            }
            .sheet(isPresented: $showAddExerciseSheet, onDismiss: {
                viewModel.loadInitialData()
                normalizeSelection()
            }) {
                HomeAddExerciseView(
                    initialBodyPart: selectedBodyPart,
                    bodyPartOrder: bodyPartOrder
                ) { bodyPart, name in
                    viewModel.addNewExercise(name: name, bodyPart: bodyPart)
                    selectedBodyPart = bodyPart
                    selectedExercise = name
                }
            }
        }
    }
}

private struct EvolutionStage {
    let name: String
    let assetName: String

    static func from(level: Int) -> EvolutionStage {
        switch level {
        case 1...4:
            return EvolutionStage(name: "がりがり", assetName: "lv1_idle_1")
        case 5...9:
            return EvolutionStage(name: "ほそ", assetName: "lv1_idle_1")
        case 10...14:
            return EvolutionStage(name: "ふつう", assetName: "macho_idle_1")
        case 15...19:
            return EvolutionStage(name: "ほそまっちょ", assetName: "macho_idle_1")
        case 20...29:
            return EvolutionStage(name: "まっちょ", assetName: "lv20_idle_1")
        case 30...39:
            return EvolutionStage(name: "ごりまっちょ", assetName: "lv20_idle_1")
        case 40...99:
            return EvolutionStage(name: "ごりらっちょ", assetName: "lv20_idle_1")
        default:
            return EvolutionStage(name: "れじぇんど", assetName: "lv20_idle_1")
        }
    }
}

private struct CalendarSection: View {
    @Binding var selectedDate: Date
    let entries: [SetEntry]
    let onDateTap: () -> Void

    var body: some View {
        CalendarView(
            selectedDate: $selectedDate,
            markedDates: entries.map { $0.date }
        )
        .frame(height: 220)
        .background(Color.card)
        .cornerRadius(16)
        .onChange(of: selectedDate) { _, _ in
            onDateTap()
        }
    }
}

private struct CharacterHeaderView: View {
    let level: Int
    let progress: Double
    let currentXP: Int
    let requiredXP: Int
    let power: Int
    let endurance: Int

    private var stage: EvolutionStage { EvolutionStage.from(level: level) }
    private var statusBoxView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stage.name)
                .font(.caption.weight(.semibold))
            Text("Lv \(level)")
                .font(.caption2.weight(.semibold))
            Text("POW \(power)")
                .font(.caption2.weight(.semibold))
            Text("END \(endurance)")
                .font(.caption2.weight(.semibold))

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 3)

                ProgressView(value: progress)
                    .tint(.green)
                    .frame(height: 3)
            }
            .frame(maxWidth: 95, alignment: .leading)

            Text("XP \(currentXP.formatted()) / \(requiredXP.formatted())")
                .font(.caption2)
                .monospacedDigit()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.9))
        .overlay(
            Rectangle().stroke(Color.white, lineWidth: 2)
        )
    }

    var body: some View {
        Button {
            // TODO: キャラ詳細画面へ遷移
        } label: {
            ZStack {
                Color.black

                VStack(spacing: 16) {
                    Spacer()
                    CharacterView(level: level)
                        .frame(width: 256, height: 256)
                        .clipped()
                    Spacer()
                }

                VStack {
                    HStack {
                        statusBoxView
                            .frame(width: 120)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.leading, 16)
            }
            .frame(maxWidth: .infinity, minHeight: 320)
            .padding(.top, 4)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
private struct DebugEvolutionPanelView: View {
    @Binding var enabled: Bool
    @Binding var debugLevel: Int
    let displayLevel: Int

    private let presets: [(name: String, level: Int)] = [
        ("がりがり", 1),
        ("ほそ", 5),
        ("ふつう", 10),
        ("ほそまっちょ", 15),
        ("まっちょ", 20),
        ("ごりまっちょ", 30),
        ("ごりらっちょ", 40),
        ("れじぇんど", 100)
    ]

    private var stage: EvolutionStage {
        EvolutionStage.from(level: displayLevel)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("DEBUG: 手動レベル", isOn: $enabled)
                .foregroundColor(.white)

            Stepper(value: $debugLevel, in: 1...120) {
                Text("DEBUG Level: \(debugLevel)")
                    .foregroundColor(.white.opacity(enabled ? 0.95 : 0.5))
            }
            .disabled(!enabled)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(presets, id: \.name) { preset in
                    Button(preset.name) {
                        debugLevel = preset.level
                        enabled = true
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            Text("表示Lv: \(displayLevel) / 進化: \(stage.name) / asset: \(stage.assetName)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.78))
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
#endif

private struct HomeAddExerciseView: View {
    @Environment(\.dismiss) private var dismiss

    let initialBodyPart: String
    let bodyPartOrder: [String]
    let onAdd: (String, String) -> Void

    @State private var bodyPart: String = ""
    @State private var exerciseName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("部位", selection: $bodyPart) {
                    ForEach(bodyPartOrder, id: \.self) { part in
                        Text(part).tag(part)
                    }
                }

                TextField("種目名", text: $exerciseName)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            .navigationTitle("種目を追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let trimmed = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onAdd(bodyPart, trimmed)
                        dismiss()
                    }
                }
            }
            .onAppear {
                bodyPart = bodyPartOrder.contains(initialBodyPart) ? initialBodyPart : (bodyPartOrder.first ?? "胸")
            }
        }
    }
}
