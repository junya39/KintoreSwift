// HomeView.swift

import SwiftUI
import UIKit

struct HomeView: View {
    private let xpHighlightDuration: TimeInterval = 2.8

    @StateObject private var viewModel = ContentViewModel()
    @EnvironmentObject private var userStatusVM: UserStatusViewModel
    @EnvironmentObject private var monsterManager: MonsterManager
    @EnvironmentObject private var timerVM: IntervalTimerViewModel
    @State private var selectedDate = Date()
    @State private var showDayHistory = false
    @State private var showMonsterSelection = false
    @State private var selectedBodyPart = "胸"
    @State private var selectedExercise = ""
    @State private var showExercisePickerSheet = false
    @State private var showAddExerciseSheet = false
    @State private var showCalendarSheet = false
    @State private var pendingShowHistory = false
    @State private var pendingAddExercise = false
    @State private var addExerciseInitialName = ""
    @State private var buddyMemo = ""
    @StateObject private var workoutAnalysisVM = WorkoutAnalysisViewModel()
    @State private var showAnalysisSheet = false

    // セット記録の入力フォーム
    @State private var showInputSheet = false
    @State private var weightText = ""
    @State private var repsText = ""
    @State private var note = ""
    @State private var isBodyweight = false
    @State private var selectedSide = ""
    @State private var showExerciseDetailFromInput = false
    @FocusState private var focusedInputField: WorkoutInputField?

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

    private var nextMonsterEncounter: NextMonsterEncounter {
        let metrics = MonsterUnlockEvaluator.makeMetrics(entries: viewModel.statusEligibleEntries)
        let unlockedIDs = monsterManager.state.unlockedMonsterIDs

        // 記録ゼロの間は「はじめての記録」が最短の出会いなので固定で案内する
        if metrics.hasAnyRecord == false, unlockedIDs.contains("014") == false {
            return NextMonsterEncounter(
                condition: MonsterMasterData.horaguma.unlockCondition,
                progressText: "あと1回",
                progress: 0,
                number: MonsterMasterData.horaguma.number
            )
        }

        let candidates = MonsterMasterData.monsters.compactMap { monster -> NextMonsterEncounter? in
            guard unlockedIDs.contains(monster.id) == false else { return nil }
            guard let info = Self.encounterProgress(
                for: monster.id,
                metrics: metrics,
                unlockedMonsterIDs: unlockedIDs
            ) else { return nil }
            return NextMonsterEncounter(
                condition: monster.unlockCondition,
                progressText: info.text,
                progress: info.progress,
                number: monster.number
            )
        }

        let best = candidates.max { lhs, rhs in
            if lhs.progress != rhs.progress { return lhs.progress < rhs.progress }
            return lhs.number > rhs.number
        }

        return best ?? NextMonsterEncounter(
            condition: "すべてのモンスターと出会った！",
            progressText: "コンプリート",
            progress: 1,
            number: 0
        )
    }

    /// 未解放モンスターの解放条件に対する進捗。前提条件（先行モンスター）未達のものは候補から外す。
    private static func encounterProgress(
        for monsterID: String,
        metrics: MonsterUnlockEvaluator.Metrics,
        unlockedMonsterIDs: Set<String>
    ) -> (progress: Double, text: String)? {
        func count(_ current: Int, of target: Int, unit: String) -> (Double, String) {
            let remaining = max(target - current, 0)
            return (
                min(Double(current) / Double(target), 1),
                remaining == 0 ? "条件達成！" : "あと\(remaining)\(unit)"
            )
        }
        func weight(of target: Double) -> (Double, String) {
            let remaining = max(target - metrics.totalLiftedWeight, 0)
            return (
                min(metrics.totalLiftedWeight / target, 1),
                remaining == 0 ? "条件達成！" : "あと\(Int(remaining).formatted())kg"
            )
        }

        switch monsterID {
        case "014":
            return metrics.hasAnyRecord ? (1, "条件達成！") : (0, "あと1回")
        case "005":
            return count(metrics.longestStreakDays, of: 3, unit: "日")
        case "002":
            return count(metrics.chestRecordCount, of: 3, unit: "回")
        case "003":
            return count(metrics.backRecordCount, of: 3, unit: "回")
        case "001":
            return weight(of: 10_000)
        case "006":
            return count(metrics.morningWorkoutDayCount, of: 3, unit: "日")
        case "007":
            return count(metrics.armRecordCount, of: 3, unit: "回")
        case "008":
            return count(metrics.workoutDayCount, of: 10, unit: "日")
        case "010":
            return count(metrics.dumbbellRecordCount, of: 5, unit: "回")
        case "004":
            guard unlockedMonsterIDs.contains("005") else { return nil }
            return count(metrics.longestStreakDays, of: 7, unit: "日")
        case "009":
            guard unlockedMonsterIDs.contains("001") else { return nil }
            return weight(of: 50_000)
        case "012":
            guard unlockedMonsterIDs.contains("002") else { return nil }
            return count(metrics.benchPressRecordCount, of: 10, unit: "回")
        case "013":
            guard unlockedMonsterIDs.contains("003") else { return nil }
            return count(metrics.backRecordCount, of: 10, unit: "回")
        case "011":
            guard unlockedMonsterIDs.contains("009") else { return nil }
            return weight(of: 100_000)
        case "015":
            let ratios = [
                metrics.totalLiftedWeight / 300_000,
                Double(metrics.workoutDayCount) / 30,
                Double(metrics.longestStreakDays) / 7,
                Double(unlockedMonsterIDs.count) / 10
            ]
            let progress = min(ratios.min() ?? 0, 1)
            return (progress, progress >= 1 ? "条件達成！" : "複合条件に挑戦中")
        default:
            return nil
        }
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

    private func refreshBuddyMemo() {
        buddyMemo = BuddyMemoGenerator.generate(
            monsterName: monsterManager.buddyMonster?.name,
            hasUnlockedMonsters: monsterManager.unlockedMonsters.isEmpty == false,
            todaySetCount: homeMetrics.todaySetCount,
            streakDays: homeMetrics.streakDays,
            totalVolume: homeMetrics.totalVolume,
            level: userStatusVM.level,
            remainingXP: max(userStatusVM.requiredXP(for: userStatusVM.level) - userStatusVM.currentXP, 0),
            isLevelUpEvent: viewModel.currentLogEvent == .levelUp
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HomeStageBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        HomeHUDHeader(
                            dateText: todayText,
                            level: userStatusVM.level,
                            progress: userStatusVM.getProgress(),
                            currentXP: userStatusVM.currentXP,
                            requiredXP: userStatusVM.requiredXP(for: userStatusVM.level),
                            power: userStatusVM.power,
                            endurance: userStatusVM.endurance
                        )

                        CharacterStage(
                            buddyMonster: monsterManager.buddyMonster,
                            hasUnlockedMonsters: monsterManager.unlockedMonsters.isEmpty == false,
                            onSelectBuddy: { showMonsterSelection = true }
                        )

                        SpeechBubble(message: buddyMemo) {
                            refreshBuddyMemo()
                        }

                        QuickStatsRow(
                            todaySetCount: homeMetrics.todaySetCount,
                            streakDays: homeMetrics.streakDays,
                            totalVolume: homeMetrics.totalVolume
                        )

                        NextEncounterCard(encounter: nextMonsterEncounter)

                        WorkoutAnalysisButtonCard(
                            isLoading: workoutAnalysisVM.isLoading,
                            onTap: generateWorkoutAnalysisData
                        )

                        IntervalTimerCard()

                        ActionDock(
                            selectedBodyPart: selectedBodyPart,
                            selectedExercise: selectedExercise,
                            exerciseVolumeText: selectedExerciseVolumeText,
                            onTapExerciseSelector: { showExercisePickerSheet = true },
                            onTapCalendar: { showCalendarSheet = true },
                            onTapAddExercise: { showAddExerciseSheet = true },
                            onTapBuddy: { showMonsterSelection = true },
                            onTapStart: { showInputSheet = true }
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .fontDesign(.rounded)
            .navigationDestination(isPresented: $showDayHistory) {
                HistoryView(selectedDate: selectedDate)
                    .environmentObject(viewModel)
            }
            .navigationDestination(isPresented: $showExerciseDetailFromInput) {
                if selectedExercise.isEmpty == false {
                    ExerciseDetailView(
                        exerciseName: selectedExercise,
                        contentViewModel: viewModel
                    )
                }
            }
            .onAppear {
                viewModel.loadInitialData()
                normalizeSelection()
                refreshBuddyMemo()
                monsterManager.evaluateUnlocks(entries: viewModel.statusEligibleEntries)
            }
            .onChange(of: selectedBodyPart) { _, _ in
                normalizeSelection()
            }
            .onChange(of: viewModel.entries.count) { _, _ in
                refreshBuddyMemo()
            }
            .onChange(of: monsterManager.buddyMonster?.id) { _, _ in
                refreshBuddyMemo()
            }
            .sheet(isPresented: $showExercisePickerSheet, onDismiss: {
                if pendingAddExercise {
                    pendingAddExercise = false
                    showAddExerciseSheet = true
                }
            }) {
                HomeExercisePickerSheet(
                    exercises: viewModel.exercises,
                    bodyPartOrder: bodyPartOrder,
                    onSelect: { bodyPart, exercise in
                        selectedBodyPart = bodyPart
                        selectedExercise = exercise
                    },
                    onRequestAdd: { suggestedName in
                        addExerciseInitialName = suggestedName
                        pendingAddExercise = true
                    }
                )
                .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showAddExerciseSheet, onDismiss: {
                addExerciseInitialName = ""
                viewModel.loadInitialData()
                normalizeSelection()
                refreshBuddyMemo()
            }) {
                HomeAddExerciseView(
                    initialBodyPart: selectedBodyPart,
                    initialName: addExerciseInitialName,
                    bodyPartOrder: bodyPartOrder
                ) { bodyPart, name in
                    viewModel.addNewExercise(name: name, bodyPart: bodyPart)
                    selectedBodyPart = bodyPart
                    selectedExercise = name
                }
                .presentationDetents([.medium])
                .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showMonsterSelection) {
                MonsterBuddySelectionView(monsterManager: monsterManager)
                    .presentationDetents([.medium])
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showCalendarSheet, onDismiss: {
                if pendingShowHistory {
                    pendingShowHistory = false
                    showDayHistory = true
                }
            }) {
                HomeCalendarSheet(
                    selectedDate: $selectedDate,
                    markedDates: viewModel.entries.map { $0.date },
                    onSelectDate: { pendingShowHistory = true }
                )
                .presentationDetents([.medium])
                .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showAnalysisSheet, onDismiss: {
                workoutAnalysisVM.reset()
            }) {
                workoutAnalysisSheet
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showInputSheet) {
                InputFormSection(
                    selectedBodyPart: selectedBodyPart,
                    selectedExercise: selectedExercise,
                    isBodyweight: $isBodyweight,
                    selectedSide: $selectedSide,
                    weightText: $weightText,
                    repsText: $repsText,
                    note: $note,
                    focusedField: $focusedInputField,
                    onTapExercise: {
                        openExerciseDetailFromInputForm()
                    },
                    onAdd: addSet
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .preferredColorScheme(.dark)
            }
        }
    }

    // MARK: - セット記録

    @ViewBuilder
    private var workoutAnalysisSheet: some View {
        switch workoutAnalysisVM.state {
        case .success(let result):
            WorkoutAnalysisDebugView(result: result)
        case .empty(let result):
            WorkoutAnalysisEmptyView(result: result)
                .presentationDetents([.medium])
        case .failure(let message):
            WorkoutAnalysisFailureView(message: message)
                .presentationDetents([.medium])
        case .idle, .loading:
            WorkoutAnalysisLoadingView()
                .presentationDetents([.medium])
        }
    }

    private func generateWorkoutAnalysisData() {
        workoutAnalysisVM.generateTodayAnalysisData()
        showAnalysisSheet = true
    }

    private func addSet() {
        guard let reps = Int(repsText), !selectedExercise.isEmpty else { return }

        let currentSide = selectedSide
        let weight = isBodyweight ? 0 : (Double(weightText) ?? 0)
        let actualBodyPart = selectedBodyPart == "ALL"
            ? viewModel.bodyPart(for: selectedExercise)
            : selectedBodyPart

        viewModel.addSet(
            date: Date(),
            bodyPart: actualBodyPart,
            exercise: selectedExercise,
            weight: weight,
            reps: reps,
            note: note.isEmpty ? nil : note,
            side: selectedSide,
            userStatusVM: userStatusVM
        )
        let newlyUnlockedMonsters = monsterManager.evaluateUnlocks(
            entries: viewModel.statusEligibleEntries
        )
        for monster in newlyUnlockedMonsters {
            MonsterUnlockToastCenter.shared.show(monsterName: monster.name)
        }

        let postSaveSideAction = viewModel.postSaveSideAction(for: currentSide)

        let gainedXP = userStatusVM.lastGainedXP
        if gainedXP > 0 {
            XPToastCenter.shared.show(xp: gainedXP)
            userStatusVM.lastGainedXP = 0
        }

        if postSaveSideAction != .none {
            let delay = gainedXP > 0 ? xpHighlightDuration : 0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                applySideTransition(postSaveSideAction)
            }
        } else {
            weightText = ""
            repsText = ""
            note = ""
            selectedSide = ""
            isBodyweight = false
        }

        timerVM.reset()
        timerVM.start()
    }

    private func applySideTransition(_ action: ContentViewModel.PostSaveSideAction) {
        switch action {
        case .switchToLeft:
            selectedSide = "L"
        case .switchToRight:
            selectedSide = "R"
        case .none:
            return
        }

        repsText = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        DispatchQueue.main.async {
            focusedInputField = .reps
        }
    }

    private func openExerciseDetailFromInputForm() {
        guard !selectedExercise.isEmpty else { return }
        showInputSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showExerciseDetailFromInput = true
        }
    }
}

// MARK: - AI分析入口

private struct WorkoutAnalysisButtonCard: View {
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            guard isLoading == false else { return }
            onTap()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.16))

                    if isLoading {
                        ProgressView()
                            .tint(.green)
                    } else {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.title3.weight(.heavy))
                            .foregroundColor(.green)
                    }
                }
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("今日の筋トレ記録を分析")
                        .font(.headline.weight(.heavy))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("今日のセット内容をAI分析用データに変換します")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white.opacity(0.56))
            }
            .padding(15)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.green.opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel("今日の筋トレ記録を分析用データに変換")
    }
}

private struct WorkoutAnalysisFailureView: View {
    let message: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundColor(.orange)
                        .frame(width: 78, height: 78)
                        .background(Color.orange.opacity(0.14))
                        .clipShape(Circle())

                    Text("データを作成できませんでした")
                        .font(.title3.weight(.heavy))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white.opacity(0.66))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        dismiss()
                    } label: {
                        Text("閉じる")
                            .font(.headline.weight(.heavy))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(24)
            }
            .navigationTitle("AI分析用データ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .fontDesign(.rounded)
    }
}

private struct WorkoutAnalysisLoadingView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .tint(.green)

                Text("分析用データを作成しています")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white.opacity(0.76))
            }
        }
        .fontDesign(.rounded)
    }
}

// MARK: - ステージ背景

private struct HomeStageBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.09, blue: 0.07),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // ステージ上部のほのかな光
            RadialGradient(
                colors: [Color.green.opacity(0.14), .clear],
                center: .init(x: 0.5, y: 0.32),
                startRadius: 10,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - HUDヘッダー

private struct HomeHUDHeader: View {
    let dateText: String
    let level: Int
    let progress: Double
    let currentXP: Int
    let requiredXP: Int
    let power: Int
    let endurance: Int

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateText)
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white.opacity(0.65))
                    Text("きょうもきたえよう！")
                        .font(.title3.weight(.heavy))
                        .foregroundColor(.white)
                }

                Spacer()

                LevelBadge(level: level)
            }

            VStack(spacing: 6) {
                XPGaugeBar(progress: progress)

                HStack(spacing: 8) {
                    Text("XP \(currentXP.formatted()) / \(requiredXP.formatted())")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.66))
                        .monospacedDigit()

                    Spacer()

                    StatChip(icon: "flame.fill", label: "POW", value: power, color: .orange)
                    StatChip(icon: "bolt.heart.fill", label: "END", value: endurance, color: .cyan)
                }
            }
        }
    }
}

private struct LevelBadge: View {
    let level: Int

    var body: some View {
        VStack(spacing: 0) {
            Text("Lv")
                .font(.caption2.weight(.heavy))
                .foregroundColor(.green.opacity(0.9))
            Text("\(level)")
                .font(.title3.weight(.heavy))
                .foregroundColor(.white)
                .monospacedDigit()
        }
        .frame(width: 54, height: 54)
        .background(
            Circle()
                .fill(Color.black.opacity(0.55))
        )
        .overlay(
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
        )
        .shadow(color: .green.opacity(0.35), radius: 8, x: 0, y: 0)
    }
}

private struct XPGaugeBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(geometry.size.width * min(max(progress, 0), 1), 12))
                    .shadow(color: .green.opacity(0.5), radius: 4, x: 0, y: 0)
            }
        }
        .frame(height: 14)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
    }
}

private struct StatChip: View {
    let icon: String
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
                .foregroundColor(color)
            Text("\(label) \(value.formatted())")
                .font(.caption2.weight(.bold))
                .foregroundColor(.white.opacity(0.88))
                .monospacedDigit()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.16))
        .clipShape(Capsule())
    }
}

// MARK: - キャラクターステージ

private struct CharacterStage: View {
    let buddyMonster: Monster?
    let hasUnlockedMonsters: Bool
    let onSelectBuddy: () -> Void

    @State private var isBobbing = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 2) {
                ZStack {
                    // キャラクターの背後のグロー
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.green.opacity(0.28), .clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 150
                            )
                        )
                        .frame(width: 280, height: 280)

                    VStack(spacing: -6) {
                        Group {
                            if let buddyMonster, UIImage(named: buddyMonster.imageName) != nil {
                                Image(buddyMonster.imageName)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                MonsterPlaceholderIcon()
                            }
                        }
                        .frame(width: 200, height: 200)
                        .offset(y: isBobbing ? -7 : 5)
                        .animation(
                            .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                            value: isBobbing
                        )

                        // 足元の影
                        Ellipse()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: isBobbing ? 110 : 130, height: 20)
                            .blur(radius: 6)
                            .animation(
                                .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                                value: isBobbing
                            )
                    }
                }

                // ネームプレート
                HStack(spacing: 6) {
                    if buddyMonster != nil {
                        Image(systemName: "pawprint.fill")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.green)
                    }
                    Text(buddyMonster?.name ?? "相棒を探しに行こう")
                        .font(.headline.weight(.heavy))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.55))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.green.opacity(0.45), lineWidth: 1.2)
                )

                if buddyMonster == nil {
                    Text(hasUnlockedMonsters ? "右上のボタンで相棒を選べるよ" : "ワークアウトを記録すると最初の相棒に出会えるよ")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity)

            // 相棒切り替えボタン
            Button {
                onSelectBuddy()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(hasUnlockedMonsters ? .black : .white.opacity(0.35))
                    .frame(width: 38, height: 38)
                    .background(hasUnlockedMonsters ? Color.green : Color.white.opacity(0.1))
                    .clipShape(Circle())
                    .shadow(color: hasUnlockedMonsters ? .green.opacity(0.4) : .clear, radius: 6)
            }
            .disabled(hasUnlockedMonsters == false)
            .accessibilityLabel("相棒を選ぶ")
        }
        .onAppear {
            isBobbing = true
        }
    }
}

// MARK: - 吹き出し

private struct SpeechBubble: View {
    let message: String
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 0) {
                // キャラクターに向かう吹き出しのしっぽ
                Triangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 18, height: 9)

                Text(message.isEmpty ? BuddyMemoGenerator.fallback(monsterName: nil) : message)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("タップするとひとことが変わります")
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - クイックステータス

private struct QuickStatsRow: View {
    let todaySetCount: Int
    let streakDays: Int
    let totalVolume: Int

    var body: some View {
        HStack(spacing: 10) {
            QuickStatCapsule(
                icon: "dumbbell.fill",
                title: "今日",
                value: "\(todaySetCount)セット",
                color: .green
            )
            QuickStatCapsule(
                icon: "flame.fill",
                title: "連続",
                value: "\(streakDays)日",
                color: .orange
            )
            QuickStatCapsule(
                icon: "scalemass.fill",
                title: "総重量",
                value: "\(totalVolume.formatted())kg",
                color: .cyan
            )
        }
    }
}

private struct QuickStatCapsule: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(color)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white.opacity(0.6))
            }

            Text(value)
                .font(.footnote.weight(.heavy))
                .foregroundColor(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(color.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - 次の出会い

private struct NextMonsterEncounter {
    let condition: String
    let progressText: String
    let progress: Double
    let number: Int
}

private struct NextEncounterCard: View {
    let encounter: NextMonsterEncounter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                    Text("つぎの出会い")
                        .font(.caption.weight(.heavy))
                }
                .foregroundColor(.green.opacity(0.9))

                Spacer()

                Text(encounter.progressText)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white.opacity(0.82))
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("？？？")
                    .font(.headline.weight(.heavy))
                    .foregroundColor(.white)

                Text(encounter.condition)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white.opacity(0.62))
                    .lineLimit(2)
            }

            XPGaugeBar(progress: encounter.progress)
                .frame(height: 10)
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.green.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - インターバルタイマー

private struct IntervalTimerCard: View {
    @EnvironmentObject private var timerVM: IntervalTimerViewModel
    @State private var isEditingTimer = false
    @State private var tempMinute = 1
    @State private var tempSecond = 30
    @State private var showTimerSoundInfoAlert = false

    private var selectedTimerSeconds: Int {
        tempMinute * 60 + tempSecond
    }

    private var displaySeconds: Int {
        isEditingTimer ? selectedTimerSeconds : timerVM.remainingSeconds
    }

    private var timerText: String {
        let minutes = displaySeconds / 60
        let seconds = displaySeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.caption.weight(.bold))
                    Text("インターバルタイマー")
                        .font(.caption.weight(.heavy))
                }
                .foregroundColor(.green.opacity(0.9))

                Spacer()

                Text(timerText)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .onTapGesture(perform: beginEditingTimer)
            }

            HStack(alignment: .center, spacing: 10) {
                Spacer()

                if !isEditingTimer {
                    Button {
                        showTimerSoundInfoAlert = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }

                    Button {
                        if timerVM.isRunning {
                            timerVM.stop()
                        } else {
                            timerVM.start()
                        }
                    } label: {
                        Text(timerVM.isRunning ? "停止" : "開始")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.black)
                            .frame(minWidth: 76, minHeight: 44)
                            .padding(.horizontal, 4)
                            .background(Color.accent)
                            .clipShape(Capsule())
                    }

                    Button {
                        timerVM.reset()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
            }

            if isEditingTimer {
                VStack(spacing: 8) {
                    HStack(spacing: 0) {
                        Picker("", selection: $tempMinute) {
                            ForEach(0...60, id: \.self) { value in
                                Text("\(value)分")
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                                    .tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .colorScheme(.dark)
                        .tint(.green)
                        .frame(maxWidth: .infinity)
                        .onChange(of: tempMinute) { _, _ in
                            timerVM.updateDuration(selectedTimerSeconds)
                        }

                        Picker("", selection: $tempSecond) {
                            ForEach(0..<60, id: \.self) { value in
                                Text("\(value)秒")
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                                    .tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .colorScheme(.dark)
                        .tint(.green)
                        .frame(maxWidth: .infinity)
                        .onChange(of: tempSecond) { _, _ in
                            timerVM.updateDuration(selectedTimerSeconds)
                        }
                    }
                    .frame(height: 200)

                    Button("完了") {
                        finishEditingTimer()
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.accent)
                    .clipShape(Capsule())
                }
                .transition(.move(edge: .bottom))
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.green.opacity(0.18), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isEditingTimer)
        .onAppear {
            timerVM.startTimerIfNeeded()
        }
        .alert("通知音について", isPresented: $showTimerSoundInfoAlert) {
            Button("閉じる", role: .cancel) {}
        } message: {
            Text("アプリを開いている時は、マナーモードでもタイマー音が鳴ります。\n\nアプリを閉じている時や画面OFF時は、iPhoneの通知設定とマナーモードに従うため、タイマー音が鳴らない場合があります。")
        }
    }

    private func beginEditingTimer() {
        timerVM.stop()
        let total = min(timerVM.duration, 3600)
        tempMinute = total / 60
        tempSecond = total % 60
        isEditingTimer = true
    }

    private func finishEditingTimer() {
        let newValue = tempMinute * 60 + tempSecond
        if newValue > 0 {
            timerVM.updateDuration(newValue)
            timerVM.reset()
        }
        isEditingTimer = false
    }
}

// MARK: - アクションドック

private struct ActionDock: View {
    let selectedBodyPart: String
    let selectedExercise: String
    let exerciseVolumeText: String
    let onTapExerciseSelector: () -> Void
    let onTapCalendar: () -> Void
    let onTapAddExercise: () -> Void
    let onTapBuddy: () -> Void
    let onTapStart: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // 種目セレクタ
            Button {
                onTapExerciseSelector()
            } label: {
                HStack(spacing: 10) {
                    Text(selectedBodyPart)
                        .font(.caption.weight(.heavy))
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())

                    Text(selectedExercise.isEmpty ? "種目を選択" : selectedExercise)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    Text(exerciseVolumeText)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.green.opacity(0.85))
                        .monospacedDigit()

                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("exerciseSelector")

            // スタートボタン
            Button {
                onTapStart()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill")
                        .font(.headline.weight(.black))
                    Text("トレーニングスタート！")
                        .font(.headline.weight(.heavy))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .green.opacity(0.35), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            // サブアクション
            HStack(spacing: 10) {
                DockButton(icon: "calendar", title: "カレンダー", action: onTapCalendar)
                DockButton(icon: "plus.circle.fill", title: "種目追加", action: onTapAddExercise)
                DockButton(icon: "pawprint.fill", title: "相棒", action: onTapBuddy)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct DockButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.green)
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - カレンダーシート

private struct HomeCalendarSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedDate: Date
    let markedDates: [Date]
    let onSelectDate: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 10) {
                    Text("日付をタップすると、その日の記録が見られるよ")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.6))

                    CalendarView(
                        selectedDate: $selectedDate,
                        markedDates: markedDates
                    )
                    .frame(height: 240)
                    .background(Color.card)
                    .cornerRadius(16)

                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("カレンダー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedDate) { _, _ in
                onSelectDate()
                dismiss()
            }
        }
        .fontDesign(.rounded)
    }
}

// MARK: - ひとこと生成

private enum BuddyMemoGenerator {
    static func generate(
        monsterName: String?,
        hasUnlockedMonsters: Bool,
        todaySetCount: Int,
        streakDays: Int,
        totalVolume: Int,
        level: Int,
        remainingXP: Int,
        isLevelUpEvent: Bool
    ) -> String {
        guard let monsterName else {
            return hasUnlockedMonsters
                ? "相棒にしたいモンスターがこちらを見ている。"
                : "まだ見ぬモンスターの気配がする。最初の記録を待っている。"
        }

        if isLevelUpEvent {
            return [
                "\(monsterName)は、Lv\(level)になったあなたを誇らしげに見ている。",
                "\(monsterName)は、新しいレベルまで来た努力をちゃんと覚えている。",
                "\(monsterName)は、成長したあなたを静かに見守っている。"
            ].randomElement() ?? fallback(monsterName: monsterName)
        }

        var candidates: [String] = []

        if todaySetCount == 0 {
            candidates.append(contentsOf: [
                "\(monsterName)は、今日の最初の1セットを待っている。",
                "\(monsterName)は、まだ今日の記録がないことに気づいている。",
                "\(monsterName)は、今日のスタートを静かに待っている。"
            ])
        } else {
            candidates.append(contentsOf: [
                "\(monsterName)は、今日の\(todaySetCount)セットをちゃんと覚えている。",
                "\(monsterName)は、今日積み上げた\(todaySetCount)セットを見てうなずいている。",
                "\(monsterName)は、今日の\(todaySetCount)セット分だけあなたが進んだことを知っている。"
            ])
        }

        if streakDays >= 2 {
            candidates.append(contentsOf: [
                "\(monsterName)は、\(streakDays)日連続の努力を見逃していない。",
                "\(monsterName)は、\(streakDays)日連続で続いていることを覚えている。",
                "\(monsterName)は、\(streakDays)日続けたあなたを誇らしげに見ている。"
            ])
        }

        if totalVolume >= 1 {
            let volumeText = totalVolume.formatted()
            candidates.append(contentsOf: [
                "\(monsterName)は、これまでに\(volumeText)kg分の努力を見てきた。",
                "\(monsterName)は、積み上げた\(volumeText)kgの重みを知っている。",
                "\(monsterName)は、あなたが動かしてきた\(volumeText)kgを覚えている。"
            ])
        }

        candidates.append(contentsOf: [
            "\(monsterName)は、Lv\(level)まで来たあなたを見ている。",
            "\(monsterName)は、Lv\(level)の努力をちゃんと覚えている。",
            "\(monsterName)は、次のレベルまであと\(remainingXP.formatted())XPだと知っている。"
        ])

        candidates.append(contentsOf: [
            "\(monsterName)がじっとこちらを見ている。",
            "\(monsterName)は今日のトレーニングを待っている。",
            "\(monsterName)が小さくうなずいた。",
            "\(monsterName)は少しだけ強くなった気がする。",
            "\(monsterName)はバーベルを見つめている。",
            "\(monsterName)はまだ本気を出していない。",
            "\(monsterName)がこちらに気合いを送っている。",
            "\(monsterName)は次のセットを楽しみにしている。",
            "\(monsterName)は静かに燃えている。",
            "\(monsterName)は今日も成長したがっている。"
        ])

        return candidates.randomElement() ?? fallback(monsterName: monsterName)
    }

    static func fallback(monsterName: String?) -> String {
        guard let monsterName else { return "相棒がこちらを見ている。" }
        return "\(monsterName)がこちらを見ている。"
    }
}

private struct MonsterPlaceholderIcon: View {
    var body: some View {
        Image(systemName: "pawprint")
            .font(.system(size: 34, weight: .semibold))
            .foregroundColor(.green)
            .frame(width: 96, height: 96)
            .background(Color.green.opacity(0.15))
            .clipShape(Circle())
    }
}

// MARK: - 相棒選択

private struct MonsterBuddySelectionView: View {
    @ObservedObject var monsterManager: MonsterManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if monsterManager.unlockedMonsters.isEmpty {
                    Text("解放済みモンスターはいません")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white.opacity(0.62))
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(monsterManager.unlockedMonsters) { monster in
                                BuddyCandidateCard(
                                    monster: monster,
                                    isBuddy: monsterManager.buddyMonster?.id == monster.id
                                ) {
                                    monsterManager.setBuddy(monsterID: monster.id)
                                    dismiss()
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("相棒を選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .fontDesign(.rounded)
    }
}

private struct BuddyCandidateCard: View {
    let monster: Monster
    let isBuddy: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 12) {
                MonsterThumbnailView(monster: monster)

                VStack(alignment: .leading, spacing: 4) {
                    Text(monster.name)
                        .font(.headline.weight(.heavy))
                        .foregroundColor(.white)
                    Text(monster.description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.68))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                Spacer()

                if isBuddy {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "circle")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.25))
                }
            }
            .padding(12)
            .background(isBuddy ? Color.green.opacity(0.14) : Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isBuddy ? Color.green.opacity(0.45) : Color.white.opacity(0.07),
                        lineWidth: 1.2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MonsterThumbnailView: View {
    let monster: Monster

    var body: some View {
        if UIImage(named: monster.imageName) != nil {
            Image(monster.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
        }
    }
}

// MARK: - 種目ピッカー

private struct HomeExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let exercises: [String: [String]]
    let bodyPartOrder: [String]
    let onSelect: (String, String) -> Void
    let onRequestAdd: (String) -> Void

    @State private var searchText = ""

    private var normalizedSearchText: String {
        searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private var filteredSections: [(bodyPart: String, exercises: [String])] {
        bodyPartOrder.compactMap { bodyPart in
            let bodyPartExercises = exercises[bodyPart] ?? []
            let filteredExercises: [String]
            if normalizedSearchText.isEmpty {
                filteredExercises = bodyPartExercises
            } else {
                filteredExercises = bodyPartExercises.filter {
                    $0.lowercased().contains(normalizedSearchText)
                }
            }

            guard filteredExercises.isEmpty == false else { return nil }
            return (bodyPart, filteredExercises)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    searchField

                    addExerciseButton

                    if filteredSections.isEmpty {
                        VStack(spacing: 14) {
                            Text("該当する種目がありません")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white.opacity(0.62))

                            if normalizedSearchText.isEmpty == false {
                                Button {
                                    requestAdd(suggestedName: searchText.trimmingCharacters(in: .whitespacesAndNewlines))
                                } label: {
                                    Text("「\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))」を新しく追加する")
                                        .font(.subheadline.weight(.heavy))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 12)
                                        .background(
                                            LinearGradient(
                                                colors: [.green, .mint],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                ForEach(filteredSections, id: \.bodyPart) { section in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(section.bodyPart)
                                            .font(.caption.weight(.bold))
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 4)

                                        VStack(spacing: 8) {
                                            ForEach(section.exercises, id: \.self) { exercise in
                                                Button {
                                                    onSelect(section.bodyPart, exercise)
                                                    dismiss()
                                                } label: {
                                                    HStack {
                                                        Text(exercise)
                                                            .font(.subheadline.weight(.semibold))
                                                            .foregroundColor(.white)
                                                            .multilineTextAlignment(.leading)
                                                        Spacer()
                                                        Image(systemName: "plus.circle.fill")
                                                            .foregroundColor(.green)
                                                    }
                                                    .padding(.vertical, 12)
                                                    .padding(.horizontal, 14)
                                                    .background(Color.card)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 18)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }
            .navigationTitle("種目を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .fontDesign(.rounded)
    }

    private func requestAdd(suggestedName: String) {
        onRequestAdd(suggestedName)
        dismiss()
    }

    private var addExerciseButton: some View {
        Button {
            requestAdd(suggestedName: "")
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.subheadline.weight(.black))
                    .foregroundColor(.green)
                Text("新しい種目を追加")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Color.green.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.55))

            TextField("種目を検索", text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .foregroundColor(.white)

            if searchText.isEmpty == false {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct HomeAddExerciseView: View {
    @Environment(\.dismiss) private var dismiss

    let initialBodyPart: String
    var initialName: String = ""
    let bodyPartOrder: [String]
    let onAdd: (String, String) -> Void

    @State private var bodyPart: String = ""
    @State private var exerciseName: String = ""

    private var trimmedName: String {
        exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var bodyPartColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("部位")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.green)

                        LazyVGrid(columns: bodyPartColumns, spacing: 8) {
                            ForEach(bodyPartOrder, id: \.self) { part in
                                Button {
                                    bodyPart = part
                                } label: {
                                    Text(part)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(bodyPart == part ? .black : .white.opacity(0.85))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(bodyPart == part ? Color.green : Color.white.opacity(0.08))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("種目名")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.green)

                        TextField("例: インクラインベンチプレス", text: $exerciseName)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .background(Color.white.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }

                    Button {
                        guard trimmedName.isEmpty == false else { return }
                        onAdd(bodyPart, trimmedName)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.headline.weight(.black))
                            Text("この種目を追加する")
                                .font(.headline.weight(.heavy))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(
                                colors: trimmedName.isEmpty
                                    ? [Color.white.opacity(0.18), Color.white.opacity(0.18)]
                                    : [.green, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(trimmedName.isEmpty)

                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("新しい種目を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                bodyPart = bodyPartOrder.contains(initialBodyPart) ? initialBodyPart : (bodyPartOrder.first ?? "胸")
                if exerciseName.isEmpty {
                    exerciseName = initialName
                }
            }
        }
        .fontDesign(.rounded)
    }
}
