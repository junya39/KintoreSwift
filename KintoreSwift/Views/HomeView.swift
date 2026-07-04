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
    @State private var showTimerSheet = false
    @State private var pendingShowHistory = false
    @State private var pendingAddExercise = false
    @State private var addExerciseInitialName = ""
    @State private var showDexSheet = false
    @State private var showLevelSheet = false
    @State private var showQuestSheet = false
    @State private var showAnalysisSheet = false
    @StateObject private var workoutAnalysisVM = WorkoutAnalysisViewModel()

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

    private var todayEntries: [SetEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return viewModel.entries.filter { calendar.startOfDay(for: $0.date) == today }
    }

    private var todayExerciseCount: Int {
        Set(todayEntries.map { $0.exercise }).count
    }

    private var todayVolume: Int {
        Int(todayEntries.reduce(0) { $0 + ($1.weight * Double($1.reps)) })
    }

    private var todayBodyParts: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for entry in todayEntries where seen.insert(entry.bodyPart).inserted {
            result.append(entry.bodyPart)
        }
        return result
    }

    /// 相棒が実用的な案内をするひとこと。状態から決定的に生成する。
    private var guideMessage: String {
        if timerVM.isRunning {
            return "休憩は残り\(remainingTimeText)。終わったら次のセットだ。"
        }

        if case .success(let result) = workoutAnalysisVM.state {
            return result.response.summary
        }

        if homeMetrics.todaySetCount == 0 {
            if selectedExercise.isEmpty {
                return "今日は\(selectedBodyPart)トレだ。まずは種目を選ぼう。"
            }
            return "今日は\(selectedBodyPart)トレだ。\(selectedExercise)から始めよう！"
        }

        return "今日は\(homeMetrics.todaySetCount)セット記録済み。AI分析で振り返れるぞ。"
    }

    private var remainingTimeText: String {
        let seconds = timerVM.remainingSeconds
        if seconds >= 60 {
            return "\(seconds / 60)分\(seconds % 60)秒"
        }
        return "\(seconds)秒"
    }

    private var unlockedMonsterCount: Int {
        MonsterMasterData.monsters.filter {
            monsterManager.state.unlockedMonsterIDs.contains($0.id)
        }.count
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

    var body: some View {
        NavigationStack {
            ZStack {
                HomeStageBackground()

                ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        HomeHUDHeader(
                            dateText: todayText,
                            streakDays: homeMetrics.streakDays,
                            buddyName: monsterManager.buddyMonster?.name,
                            hasUnlockedMonsters: monsterManager.unlockedMonsters.isEmpty == false,
                            onSelectBuddy: { showMonsterSelection = true }
                        )
                        .id(HomeScrollAnchor.top)

                        CharacterStage(
                            buddyMonster: monsterManager.buddyMonster,
                            hasUnlockedMonsters: monsterManager.unlockedMonsters.isEmpty == false
                        )

                        GuideBubble(message: guideMessage)

                        StatusBand(
                            level: userStatusVM.level,
                            progress: userStatusVM.getProgress(),
                            currentXP: userStatusVM.currentXP,
                            requiredXP: userStatusVM.requiredXP(for: userStatusVM.level),
                            power: userStatusVM.power,
                            endurance: userStatusVM.endurance
                        )

                        OperationConsole(
                            selectedBodyPart: selectedBodyPart,
                            selectedExercise: selectedExercise,
                            exerciseVolumeText: selectedExerciseVolumeText,
                            onTapExerciseSelector: { showExercisePickerSheet = true },
                            onTapEditTimer: { showTimerSheet = true },
                            onTapStart: { showInputSheet = true }
                        )

                        QuestBannerRow(
                            encounter: nextMonsterEncounter,
                            onTap: { showQuestSheet = true }
                        )

                        CommandGrid(
                            dexSubtitle: "\(unlockedMonsterCount)/\(MonsterMasterData.monsters.count) 発見",
                            levelSubtitle: "Lv.\(userStatusVM.level) の成長記録",
                            onTapDex: { showDexSheet = true },
                            onTapLevel: { showLevelSheet = true },
                            onTapHistory: {
                                selectedDate = Date()
                                showDayHistory = true
                            },
                            onTapAnalysis: { showAnalysisSheet = true },
                            onTapCalendar: { showCalendarSheet = true },
                            onTapExerciseManage: { showExercisePickerSheet = true }
                        )

                        TodaySummaryLine(
                            exerciseCount: todayExerciseCount,
                            setCount: homeMetrics.todaySetCount,
                            volume: todayVolume,
                            bodyParts: todayBodyParts
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .padding(.bottom, 14)
                }
                .onAppear {
                    // iOS 26のTabView+ScrollViewで初回表示時にスクロール位置が
                    // 最下部へ飛ぶことがあるため、表示直後に先頭へ戻す
                    for delay in [0.05, 0.5, 1.2] {
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            scrollProxy.scrollTo(HomeScrollAnchor.top, anchor: .top)
                        }
                    }
                }
                }
            }
            .fontDesign(.rounded)
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
                monsterManager.evaluateUnlocks(entries: viewModel.statusEligibleEntries)
            }
            .onChange(of: selectedBodyPart) { _, _ in
                normalizeSelection()
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
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showAddExerciseSheet, onDismiss: {
                addExerciseInitialName = ""
                viewModel.loadInitialData()
                normalizeSelection()
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
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showMonsterSelection) {
                MonsterBuddySelectionView(monsterManager: monsterManager)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
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
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showDayHistory) {
                NavigationStack {
                    HistoryView(selectedDate: selectedDate)
                        .environmentObject(viewModel)
                        .navigationTitle("履歴")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("閉じる") {
                                    showDayHistory = false
                                }
                            }
                        }
                }
                .fontDesign(.rounded)
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showTimerSheet) {
                IntervalTimerSheet()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showDexSheet) {
                // MonsterDexViewは自前のNavigationStackを持つためそのまま提示する
                MonsterDexView()
                    .presentationDragIndicator(.visible)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showLevelSheet) {
                NavigationStack {
                    LevelView(
                        viewModel: LevelViewModel(userStatus: userStatusVM)
                    )
                    .navigationTitle("レベル")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("閉じる") {
                                showLevelSheet = false
                            }
                        }
                    }
                }
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showQuestSheet) {
                QuestSheet(encounter: nextMonsterEncounter)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showAnalysisSheet) {
                WorkoutAnalysisSheet(viewModel: workoutAnalysisVM)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
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
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
            }
        }
    }

    // MARK: - セット記録

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

// MARK: - スクロールアンカー

private enum HomeScrollAnchor {
    static let top = "homeScrollTop"
}

// MARK: - AI分析表示部品

private struct AnalysisTextBlock: View {
    let title: String
    let text: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundColor(color)

            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - ステージ背景

private struct HomeStageBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.08, blue: 0.20),
                    Color(red: 0.03, green: 0.03, blue: 0.10),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // ステージ上部のほのかな光（モンスターの後光）
            RadialGradient(
                colors: [Color.gamePurple.opacity(0.20), .clear],
                center: .init(x: 0.5, y: 0.30),
                startRadius: 10,
                endRadius: 330
            )

            // 画面下部にかすかな青の光
            RadialGradient(
                colors: [Color.gameBlue.opacity(0.10), .clear],
                center: .init(x: 0.2, y: 0.95),
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
    let streakDays: Int
    let buddyName: String?
    let hasUnlockedMonsters: Bool
    let onSelectBuddy: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            Text(dateText)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white.opacity(0.75))

            Spacer()

            // 右上の情報チップ（連続記録・相棒名）
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.caption.weight(.heavy))
                        .foregroundColor(.orange)

                    Text("連続 \(streakDays)日")
                        .font(.caption.weight(.heavy))
                        .foregroundColor(.white.opacity(0.9))
                        .monospacedDigit()
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.4))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
                )

                if buddyName != nil || hasUnlockedMonsters {
                    Button {
                        onSelectBuddy()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "pawprint.fill")
                                .font(.caption.weight(.heavy))
                                .foregroundColor(.gameGold)

                            Text(buddyName ?? "相棒を選ぶ")
                                .font(.caption.weight(.heavy))
                                .foregroundColor(.white.opacity(0.9))

                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.gameGold.opacity(0.9))
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.gameGold.opacity(0.4), lineWidth: 1)
                        )
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(hasUnlockedMonsters == false)
                    .accessibilityLabel("相棒を選ぶ")
                }
            }
        }
    }
}

// MARK: - キャラクターステージ

private struct CharacterStage: View {
    let buddyMonster: Monster?
    let hasUnlockedMonsters: Bool

    @State private var isBobbing = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // キャラクターの背後のグロー
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.gamePurple.opacity(0.32), Color.gameBlue.opacity(0.12), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 105
                        )
                    )
                    .frame(width: 200, height: 200)

                VStack(spacing: -5) {
                    Group {
                        if let buddyMonster, UIImage(named: buddyMonster.imageName) != nil {
                            Image(buddyMonster.imageName)
                                .resizable()
                                .scaledToFit()
                        } else {
                            MonsterPlaceholderIcon()
                        }
                    }
                    .frame(width: 165, height: 165)
                    .offset(y: isBobbing ? -6 : 4)
                    .animation(
                        .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                        value: isBobbing
                    )

                    // 足元の影
                    Ellipse()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: isBobbing ? 92 : 106, height: 15)
                        .blur(radius: 6)
                        .animation(
                            .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                            value: isBobbing
                        )
                }
            }

            if buddyMonster == nil {
                Text(hasUnlockedMonsters ? "右上のボタンから相棒を選べるよ" : "ワークアウトを記録すると最初の相棒に出会えるよ")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            isBobbing = true
        }
    }
}

// MARK: - 案内吹き出し

private struct GuideBubble: View {
    let message: String

    var body: some View {
        VStack(spacing: 0) {
            // キャラクターに向かう吹き出しのしっぽ
            GuideBubbleTail()
                .fill(Color.white.opacity(0.1))
                .frame(width: 16, height: 8)

            Text(message)
                .font(.footnote.weight(.bold))
                .foregroundColor(.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.gamePurple.opacity(0.25), lineWidth: 1)
                )
        }
    }
}

private struct GuideBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - コンパクトステータス帯

private struct StatusBand: View {
    let level: Int
    let progress: Double
    let currentXP: Int
    let requiredXP: Int
    let power: Int
    let endurance: Int

    var body: some View {
        VStack(spacing: 7) {
            // 1段目: Lv と POW / END
            HStack(alignment: .firstTextBaseline) {
                Text("Lv.\(level)")
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.gameGold)
                    .monospacedDigit()

                Spacer()

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.orange)
                        Text("POW \(power.formatted())")
                            .font(.caption.weight(.heavy))
                            .foregroundColor(.white.opacity(0.9))
                            .monospacedDigit()
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "bolt.heart.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.cyan)
                        Text("END \(endurance.formatted())")
                            .font(.caption.weight(.heavy))
                            .foregroundColor(.white.opacity(0.9))
                            .monospacedDigit()
                    }
                }
            }

            // 2段目: XPバー
            XPGaugeBar(progress: progress)
                .frame(height: 8)

            // 3段目: XP数値
            HStack {
                Spacer()

                Text("XP \(currentXP.formatted()) / \(requiredXP.formatted())")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 13)
        .padding(.top, 9)
        .padding(.bottom, 7)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - 司令パネル（クエスト・図鑑・レベル・AI分析・カレンダー）

private struct QuestBannerRow: View {
    let encounter: NextMonsterEncounter
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.gamePurpleLight)

                    Text("クエスト")
                        .font(.caption.weight(.heavy))
                        .foregroundColor(.gamePurpleLight)

                    Text(encounter.condition)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.62))
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    Text(encounter.progressText)
                        .font(.caption.weight(.heavy))
                        .foregroundColor(.gameGold)
                        .lineLimit(1)
                        .layoutPriority(1)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                }

                XPGaugeBar(progress: encounter.progress)
                    .frame(height: 6)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.gamePurple.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("クエスト")
    }
}

private struct CommandGrid: View {
    let dexSubtitle: String
    let levelSubtitle: String
    let onTapDex: () -> Void
    let onTapLevel: () -> Void
    let onTapHistory: () -> Void
    let onTapAnalysis: () -> Void
    let onTapCalendar: () -> Void
    let onTapExerciseManage: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 7) {
                CommandPanelButton(
                    icon: "book.fill",
                    title: "図鑑",
                    subtitle: dexSubtitle,
                    color: .gameGold,
                    action: onTapDex
                )

                CommandPanelButton(
                    icon: "chart.bar.fill",
                    title: "レベル",
                    subtitle: levelSubtitle,
                    color: .gameGold,
                    action: onTapLevel
                )
            }

            HStack(spacing: 7) {
                CommandPanelButton(
                    icon: "clock.arrow.circlepath",
                    title: "履歴",
                    subtitle: "過去のトレーニング",
                    color: .gameGold,
                    action: onTapHistory
                )

                CommandPanelButton(
                    icon: "sparkle.magnifyingglass",
                    title: "AI分析",
                    subtitle: "今日の振り返り",
                    color: .gamePurpleLight,
                    action: onTapAnalysis
                )
            }

            HStack(spacing: 7) {
                CommandPanelButton(
                    icon: "calendar",
                    title: "カレンダー",
                    subtitle: "日付から探す",
                    color: .gameGold,
                    action: onTapCalendar
                )

                CommandPanelButton(
                    icon: "dumbbell.fill",
                    title: "種目管理",
                    subtitle: "種目の選択・追加",
                    color: .gamePurpleLight,
                    action: onTapExerciseManage
                )
            }
        }
    }
}

private struct CommandPanelButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
                    .frame(width: 29, height: 29)
                    .background(color.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.footnote.weight(.heavy))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - 今日のトレーニングサマリー

private struct TodaySummaryLine: View {
    let exerciseCount: Int
    let setCount: Int
    let volume: Int
    let bodyParts: [String]

    private var summaryText: String {
        if setCount == 0 {
            return "今日はまだ記録がない"
        }
        var text = "今日: \(exerciseCount)種目・\(setCount)セット・\(volume.formatted())kg"
        if bodyParts.isEmpty == false {
            text += "（\(bodyParts.joined(separator: "・"))）"
        }
        return text
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "list.clipboard.fill")
                .font(.caption2.weight(.bold))
                .foregroundColor(.gameGold.opacity(0.8))

            Text(summaryText)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - 次の出会い

private struct NextMonsterEncounter {
    let condition: String
    let progressText: String
    let progress: Double
    let number: Int
}

private struct QuestSheet: View {
    let encounter: NextMonsterEncounter

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.caption.weight(.bold))
                            Text("つぎの出会い")
                                .font(.caption.weight(.heavy))
                        }
                        .foregroundColor(.gamePurpleLight)

                        Spacer()

                        Text(encounter.progressText)
                            .font(.subheadline.weight(.heavy))
                            .foregroundColor(.gameGold)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("？？？")
                            .font(.title3.weight(.heavy))
                            .foregroundColor(.white)

                        Text(encounter.condition)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    XPGaugeBar(progress: encounter.progress)
                        .frame(height: 12)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("クエスト")
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

// MARK: - 統合操作コンソール（種目・タイマー・スタート）

private struct OperationConsole: View {
    @EnvironmentObject private var timerVM: IntervalTimerViewModel

    let selectedBodyPart: String
    let selectedExercise: String
    let exerciseVolumeText: String
    let onTapExerciseSelector: () -> Void
    let onTapEditTimer: () -> Void
    let onTapStart: () -> Void

    private var timerText: String {
        let minutes = timerVM.remainingSeconds / 60
        let seconds = timerVM.remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 種目セレクタ
            Button {
                onTapExerciseSelector()
            } label: {
                HStack(spacing: 10) {
                    Text(selectedBodyPart)
                        .font(.caption.weight(.heavy))
                        .foregroundColor(.gameGold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.gameGold.opacity(0.15))
                        .clipShape(Capsule())

                    Text(selectedExercise.isEmpty ? "種目を選択" : selectedExercise)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    Text(exerciseVolumeText)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.gameGold.opacity(0.85))
                        .monospacedDigit()

                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("exerciseSelector")

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 13)

            // 大型インターバルタイマー
            HStack(spacing: 12) {
                Button {
                    onTapEditTimer()
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("インターバル")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.gameGold.opacity(0.85))

                        Text(timerText)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("タイマー時間を設定")

                Spacer(minLength: 6)

                Button {
                    timerVM.reset()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("タイマーをリセット")

                Button {
                    if timerVM.isRunning {
                        timerVM.stop()
                    } else {
                        timerVM.start()
                    }
                } label: {
                    Image(systemName: timerVM.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(.black)
                        .frame(width: 52, height: 52)
                        .background(
                            LinearGradient(
                                colors: [.gameGold, .gameGoldDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: .gameGold.opacity(0.35), radius: 7)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(timerVM.isRunning ? "タイマー停止" : "タイマー開始")
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)

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
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.gameGold, .gameGoldDeep],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .shadow(color: .gameGold.opacity(0.3), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            .padding(.top, 2)
        }
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.gameGold.opacity(0.35), .gamePurple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .onAppear {
            timerVM.startTimerIfNeeded()
        }
    }
}

// MARK: - AI分析シート

private struct WorkoutAnalysisSheet: View {
    @ObservedObject var viewModel: WorkoutAnalysisViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        stateContent

                        if viewModel.isLoading == false {
                            Button {
                                runAnalysis()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkle.magnifyingglass")
                                        .font(.subheadline.weight(.heavy))
                                    Text("もう一度分析する")
                                        .font(.subheadline.weight(.heavy))
                                }
                                .foregroundColor(.gamePurpleLight)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gamePurple.opacity(0.16))
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .strokeBorder(Color.gamePurple.opacity(0.4), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("AI分析")
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
        .onAppear {
            // 開いたら自動で分析する（結果表示済みならそのまま見せる）
            if viewModel.state == .idle {
                runAnalysis()
            }
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            HStack(spacing: 12) {
                ProgressView()
                    .tint(.gamePurpleLight)

                Text("今日のトレーニングを分析しています…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 20)
        case .success(let result):
            VStack(alignment: .leading, spacing: 16) {
                AnalysisTextBlock(title: "総評", text: result.response.summary, color: .gameGold)
                AnalysisTextBlock(title: "アドバイス", text: result.response.advice, color: .gamePurpleLight)
                AnalysisTextBlock(title: "次回の目標", text: result.response.nextGoal, color: .gameBlue)
            }
        case .empty(let result):
            VStack(alignment: .leading, spacing: 8) {
                Text(result.title)
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.white)

                Text(result.message)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .failure(let message):
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.orange)

                Text(message)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func runAnalysis() {
        Task {
            await viewModel.analyzeTodayWorkout()
        }
    }
}

// MARK: - インターバルタイマー設定シート

private struct IntervalTimerSheet: View {
    @EnvironmentObject private var timerVM: IntervalTimerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var tempMinute = 1
    @State private var tempSecond = 30
    @State private var showTimerSoundInfoAlert = false

    private var selectedTimerSeconds: Int {
        tempMinute * 60 + tempSecond
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 10) {
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
                        .frame(maxWidth: .infinity)
                        .onChange(of: tempSecond) { _, _ in
                            timerVM.updateDuration(selectedTimerSeconds)
                        }
                    }
                    .frame(height: 190)

                    Button {
                        if selectedTimerSeconds > 0 {
                            timerVM.updateDuration(selectedTimerSeconds)
                            timerVM.reset()
                        }
                        dismiss()
                    } label: {
                        Text("この時間にセットする")
                            .font(.headline.weight(.heavy))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [.gameGold, .gameGoldDeep],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("インターバルタイマー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showTimerSoundInfoAlert = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .tint(.gameGold)
                }
            }
            .alert("通知音について", isPresented: $showTimerSoundInfoAlert) {
                Button("閉じる", role: .cancel) {}
            } message: {
                Text("アプリを開いている時は、マナーモードでもタイマー音が鳴ります。\n\nアプリを閉じている時や画面OFF時は、iPhoneの通知設定とマナーモードに従うため、タイマー音が鳴らない場合があります。")
            }
        }
        .fontDesign(.rounded)
        .onAppear {
            timerVM.stop()
            let total = min(timerVM.duration, 3600)
            tempMinute = total / 60
            tempSecond = total % 60
        }
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
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )

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

private struct MonsterPlaceholderIcon: View {
    var body: some View {
        Image(systemName: "pawprint")
            .font(.system(size: 34, weight: .semibold))
            .foregroundColor(.gameGold)
            .frame(width: 96, height: 96)
            .background(Color.gameGold.opacity(0.15))
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
                        .foregroundColor(.gameGold)
                } else {
                    Image(systemName: "circle")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.25))
                }
            }
            .padding(12)
            .background(isBuddy ? Color.gameGold.opacity(0.14) : Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isBuddy ? Color.gameGold.opacity(0.45) : Color.white.opacity(0.07),
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
                                                colors: [.gameGold, .gameGoldDeep],
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
                                            .foregroundColor(.gameGold)
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
                                                            .foregroundColor(.gameGold)
                                                    }
                                                    .padding(.vertical, 12)
                                                    .padding(.horizontal, 14)
                                                    .background(Color.white.opacity(0.06))
                                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                                    )
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
                    .foregroundColor(.gameGold)
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
            .background(Color.gameGold.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.gameGold.opacity(0.3), lineWidth: 1)
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
                            .foregroundColor(.gameGold)

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
                                        .background(bodyPart == part ? Color.gameGold : Color.white.opacity(0.08))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("種目名")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.gameGold)

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
                                    : [.gameGold, .gameGoldDeep],
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
