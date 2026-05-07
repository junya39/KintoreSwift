// HomeView.swift

import SwiftUI
import UIKit

struct HomeView: View {
    @StateObject private var viewModel = ContentViewModel()
    @EnvironmentObject private var userStatusVM: UserStatusViewModel
    @EnvironmentObject private var monsterManager: MonsterManager
    @State private var selectedDate = Date()
    @State private var showDayHistory = false
    @State private var showMonsterSelection = false
    @State private var selectedBodyPart = "胸"
    @State private var selectedExercise = ""
    @State private var showExercisePickerSheet = false
    @State private var showAddExerciseSheet = false
    @State private var buddyMemo = ""

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
        if monsterManager.state.unlockedMonsterIDs.contains(Monster.horaguma.id) == false {
            return NextMonsterEncounter(
                monsterName: Monster.horaguma.name,
                progressText: viewModel.entries.isEmpty ? "あと1回" : "出会いは目前",
                progress: viewModel.entries.isEmpty ? 0 : 1
            )
        }

        if monsterManager.state.unlockedMonsterIDs.contains(MonsterMasterData.tsunogard.id) == false {
            let days = threeDayStreakProgress()
            let remaining = max(3 - days, 0)
            return NextMonsterEncounter(
                monsterName: MonsterMasterData.tsunogard.name,
                progressText: remaining == 0 ? "達成済み" : "あと\(remaining)日",
                progress: Double(days) / 3
            )
        }

        if monsterManager.state.unlockedMonsterIDs.contains(MonsterMasterData.benchino.id) == false {
            let count = min(trainingCount(matching: isChestTraining), 3)
            let remaining = max(3 - count, 0)
            return NextMonsterEncounter(
                monsterName: MonsterMasterData.benchino.name,
                progressText: remaining == 0 ? "達成済み" : "あと\(remaining)回",
                progress: Double(count) / 3
            )
        }

        if monsterManager.state.unlockedMonsterIDs.contains(MonsterMasterData.dedorigan.id) == false {
            let count = min(trainingCount(matching: isBackTraining), 3)
            let remaining = max(3 - count, 0)
            return NextMonsterEncounter(
                monsterName: MonsterMasterData.dedorigan.name,
                progressText: remaining == 0 ? "達成済み" : "あと\(remaining)回",
                progress: Double(count) / 3
            )
        }

        return NextMonsterEncounter(
            monsterName: "未確認のモンスター",
            progressText: "次の出会いを準備中",
            progress: 1
        )
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

    private func threeDayStreakProgress() -> Int {
        let calendar = Calendar.current
        let workoutDays = Set(viewModel.entries.map { calendar.startOfDay(for: $0.date) })
        let today = calendar.startOfDay(for: Date())

        return (0..<3).reduce(0) { count, offset in
            guard count == offset,
                  let day = calendar.date(byAdding: .day, value: -offset, to: today),
                  workoutDays.contains(day) else {
                return count
            }
            return count + 1
        }
    }

    private func trainingCount(matching predicate: (SetEntry) -> Bool) -> Int {
        viewModel.entries.filter(predicate).count
    }

    private func isChestTraining(_ entry: SetEntry) -> Bool {
        if entry.bodyPart == "胸" { return true }
        let exercise = entry.exercise.lowercased()
        let chestKeywords = ["ベンチ", "チェスト", "胸", "フライ", "だっちゅーの"]
        return chestKeywords.contains { exercise.contains($0) }
    }

    private func isBackTraining(_ entry: SetEntry) -> Bool {
        if entry.bodyPart == "背中" { return true }
        let exercise = entry.exercise.lowercased()
        let backKeywords = ["チンニング", "ロー", "ラットプル", "デッド", "プルアップ"]
        return backKeywords.contains { exercise.contains($0) }
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

                    BuddyMonsterSection(
                        buddyMonster: monsterManager.buddyMonster,
                        hasUnlockedMonsters: monsterManager.unlockedMonsters.isEmpty == false,
                        level: userStatusVM.level,
                        progress: userStatusVM.getProgress(),
                        currentXP: userStatusVM.currentXP,
                        requiredXP: userStatusVM.requiredXP(for: userStatusVM.level),
                        power: userStatusVM.power,
                        endurance: userStatusVM.endurance,
                        buddyMemo: buddyMemo,
                        nextEncounter: nextMonsterEncounter,
                        onSelectBuddy: {
                            showMonsterSelection = true
                        }
                    )

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

                        HStack(spacing: 10) {
                            Button {
                                showExercisePickerSheet = true
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
                            .buttonStyle(.plain)

                            Button {
                                showAddExerciseSheet = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 34, height: 34)
                                    .background(Color.accent)
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("新しい種目を追加")
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
                refreshBuddyMemo()
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
            .sheet(isPresented: $showExercisePickerSheet) {
                HomeExercisePickerSheet(
                    exercises: viewModel.exercises,
                    bodyPartOrder: bodyPartOrder
                ) { bodyPart, exercise in
                    selectedBodyPart = bodyPart
                    selectedExercise = exercise
                }
                .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showAddExerciseSheet, onDismiss: {
                viewModel.loadInitialData()
                normalizeSelection()
                refreshBuddyMemo()
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
            .sheet(isPresented: $showMonsterSelection) {
                MonsterBuddySelectionView(monsterManager: monsterManager)
                    .presentationDetents([.medium])
                    .preferredColorScheme(.dark)
            }
        }
    }
}

private struct BuddyMonsterSection: View {
    let buddyMonster: Monster?
    let hasUnlockedMonsters: Bool
    let level: Int
    let progress: Double
    let currentXP: Int
    let requiredXP: Int
    let power: Int
    let endurance: Int
    let buddyMemo: String
    let nextEncounter: NextMonsterEncounter
    let onSelectBuddy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()

                Button {
                    onSelectBuddy()
                } label: {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(hasUnlockedMonsters ? .black : .white.opacity(0.35))
                        .frame(width: 36, height: 36)
                        .background(hasUnlockedMonsters ? Color.green : Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .disabled(hasUnlockedMonsters == false)
                .accessibilityLabel("相棒を選ぶ")
            }

            VStack(spacing: 8) {
                if let buddyMonster {
                    MonsterArtworkView(monster: buddyMonster)
                } else {
                    MonsterPlaceholderIcon()
                }

                VStack(spacing: 4) {
                    if let buddyMonster {
                        Text(buddyMonster.name)
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("相棒はまだ設定されていません")
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text(hasUnlockedMonsters ? "解放済みモンスターから選べます" : "ワークアウトを保存すると解放されます")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, -4)

            MonsterMessageView(message: buddyMemo)

            MonsterStatusStrip(
                level: level,
                progress: progress,
                currentXP: currentXP,
                requiredXP: requiredXP,
                power: power,
                endurance: endurance
            )

            NextEncounterCard(encounter: nextEncounter)
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(14)
    }
}

private struct NextMonsterEncounter {
    let monsterName: String
    let progressText: String
    let progress: Double
}

private struct NextEncounterCard: View {
    let encounter: NextMonsterEncounter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("次の出会い")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.green.opacity(0.85))

            HStack(alignment: .firstTextBaseline) {
                Text(encounter.monsterName)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)

                Spacer()

                Text(encounter.progressText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.78))
            }

            ProgressView(value: min(max(encounter.progress, 0), 1))
                .tint(.green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.28))
        .cornerRadius(10)
    }
}

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

private struct MonsterMessageView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ひとこと")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white.opacity(0.55))

            Text(message.isEmpty ? BuddyMemoGenerator.fallback(monsterName: nil) : message)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.28))
        .cornerRadius(10)
    }
}

private struct MonsterArtworkView: View {
    let monster: Monster

    var body: some View {
        if UIImage(named: monster.imageName) != nil {
            Image(monster.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 172, height: 172)
                .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
        } else {
            MonsterPlaceholderIcon()
        }
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

private struct MonsterStatusStrip: View {
    let level: Int
    let progress: Double
    let currentXP: Int
    let requiredXP: Int
    let power: Int
    let endurance: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Lv \(level)")
                Spacer()
                Text("POW \(power)")
                Text("END \(endurance)")
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(.white.opacity(0.88))

            ProgressView(value: progress)
                .tint(.green)

            HStack {
                Text("XP \(currentXP.formatted()) / \(requiredXP.formatted())")
                Spacer()
                Text("次のレベルまであと \(max(requiredXP - currentXP, 0).formatted())XP")
            }
            .font(.caption2)
            .foregroundColor(.white.opacity(0.68))
            .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.28))
        .cornerRadius(10)
    }
}

private struct MonsterBuddySelectionView: View {
    @ObservedObject var monsterManager: MonsterManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if monsterManager.unlockedMonsters.isEmpty {
                    Text("解放済みモンスターはいません")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(monsterManager.unlockedMonsters) { monster in
                        Button {
                            monsterManager.setBuddy(monsterID: monster.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                MonsterThumbnailView(monster: monster)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(monster.name)
                                        .font(.headline)
                                    Text(monster.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if monsterManager.buddyMonster?.id == monster.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("相棒を選ぶ")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
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

private struct EvolutionStage {
    let name: String
    let assetName: String

    static func from(level: Int) -> EvolutionStage {
        switch level {
        case 1...14:
            return EvolutionStage(name: "フツウ", assetName: "lv1_idle_1")
        case 15...29:
            return EvolutionStage(name: "ホソマッチョ", assetName: "lv15_idle_1")
        default:
            return EvolutionStage(name: "マッチョ", assetName: "lv30_idle_1")
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
        ("フツウ", 1),
        ("フツウ", 14),
        ("ホソマッチョ", 15),
        ("ホソマッチョ", 29),
        ("マッチョ", 30),
        ("マッチョ", 100)
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
                ForEach(Array(presets.enumerated()), id: \.offset) { _, preset in
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

private struct HomeExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let exercises: [String: [String]]
    let bodyPartOrder: [String]
    let onSelect: (String, String) -> Void

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

                    if filteredSections.isEmpty {
                        Text("該当する種目がありません")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.62))
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
            .navigationTitle("種目を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
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
            .navigationTitle("新しい種目を追加")
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
