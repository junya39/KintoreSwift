import Foundation

/// MonsterMasterData の解放条件を記録データから判定する。
/// 判定は冪等で、すでに解放済みのモンスターは結果に含めない。
enum MonsterUnlockEvaluator {
    struct Metrics {
        let hasAnyRecord: Bool
        let totalLiftedWeight: Double
        let workoutDayCount: Int
        let longestStreakDays: Int
        let morningWorkoutDayCount: Int
        let chestRecordCount: Int
        let backRecordCount: Int
        let armRecordCount: Int
        let dumbbellRecordCount: Int
        let benchPressRecordCount: Int
    }

    /// 条件を満たした未解放モンスターのIDを、前提条件の依存順で返す。
    static func newlyUnlockableMonsterIDs(
        entries: [SetEntry],
        unlockedMonsterIDs: Set<String>,
        calendar: Calendar = .current
    ) -> [String] {
        let metrics = makeMetrics(entries: entries, calendar: calendar)
        var unlocked = unlockedMonsterIDs
        var newlyUnlocked: [String] = []

        // 前提条件付きモンスター（〇〇解放後）が同じ評価内で連鎖解放できるよう、依存順に判定する
        let conditions: [(id: String, isSatisfied: () -> Bool)] = [
            ("014", { metrics.hasAnyRecord }),                                  // ホラグマ: はじめて記録
            ("005", { metrics.longestStreakDays >= 3 }),                        // ツノガルド: 3日連続
            ("002", { metrics.chestRecordCount >= 3 }),                         // ベンチーノ: 胸トレ累計3回
            ("003", { metrics.backRecordCount >= 3 }),                          // デドリガン: 背中トレ累計3回
            ("001", { metrics.totalLiftedWeight >= 10_000 }),                   // バルグロス: 累計10,000kg
            ("006", { metrics.morningWorkoutDayCount >= 3 }),                   // アサトレオン: 朝トレ累計3日
            ("007", { metrics.armRecordCount >= 3 }),                           // アームドリル: 腕トレ累計3回
            ("008", { metrics.workoutDayCount >= 10 }),                         // レンゾクン: 記録日数累計10日
            ("010", { metrics.dumbbellRecordCount >= 5 }),                      // ダンベルン: ダンベル系累計5回
            ("004", { unlocked.contains("005") && metrics.longestStreakDays >= 7 }),        // ガルドロード
            ("009", { unlocked.contains("001") && metrics.totalLiftedWeight >= 50_000 }),    // バルグロス改
            ("012", { unlocked.contains("002") && metrics.benchPressRecordCount >= 10 }),    // ベンチロード
            ("013", { unlocked.contains("003") && metrics.backRecordCount >= 10 }),          // デドリロード
            ("011", { unlocked.contains("009") && metrics.totalLiftedWeight >= 100_000 }),   // バルグロン
            ("015", {                                                           // キングバルグ
                metrics.totalLiftedWeight >= 300_000
                    && metrics.workoutDayCount >= 30
                    && metrics.longestStreakDays >= 7
                    && unlocked.count >= 10
            })
        ]

        for condition in conditions where unlocked.contains(condition.id) == false {
            if condition.isSatisfied() {
                unlocked.insert(condition.id)
                newlyUnlocked.append(condition.id)
            }
        }

        return newlyUnlocked
    }

    static func makeMetrics(entries: [SetEntry], calendar: Calendar = .current) -> Metrics {
        let workoutDays = Set(entries.map { calendar.startOfDay(for: $0.date) })

        let morningDays = Set(
            entries
                .filter { (5...10).contains(calendar.component(.hour, from: $0.date)) }
                .map { calendar.startOfDay(for: $0.date) }
        )

        return Metrics(
            hasAnyRecord: entries.isEmpty == false,
            totalLiftedWeight: entries.reduce(0) { $0 + $1.weight * Double($1.reps) },
            workoutDayCount: workoutDays.count,
            longestStreakDays: longestStreak(of: workoutDays, calendar: calendar),
            morningWorkoutDayCount: morningDays.count,
            chestRecordCount: entries.filter(isChestTraining).count,
            backRecordCount: entries.filter(isBackTraining).count,
            armRecordCount: entries.filter(isArmTraining).count,
            dumbbellRecordCount: entries.filter { $0.exercise.contains("ダンベル") }.count,
            benchPressRecordCount: entries.filter { $0.exercise.contains("ベンチ") }.count
        )
    }

    private static func longestStreak(of days: Set<Date>, calendar: Calendar) -> Int {
        guard days.isEmpty == false else { return 0 }

        var longest = 1
        var current = 1
        let sortedDays = days.sorted()

        for (previous, day) in zip(sortedDays, sortedDays.dropFirst()) {
            if let next = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(next, inSameDayAs: day) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }

        return longest
    }

    static func isChestTraining(_ entry: SetEntry) -> Bool {
        if entry.bodyPart == "胸" { return true }

        let exercise = entry.exercise.lowercased()
        let chestKeywords = ["ベンチ", "チェスト", "胸", "フライ", "だっちゅーの"]
        return chestKeywords.contains { exercise.contains($0) }
    }

    static func isBackTraining(_ entry: SetEntry) -> Bool {
        if entry.bodyPart == "背中" { return true }

        let exercise = entry.exercise.lowercased()
        let backKeywords = ["チンニング", "ロー", "ラットプル", "デッド", "プルアップ"]
        return backKeywords.contains { exercise.contains($0) }
    }

    static func isArmTraining(_ entry: SetEntry) -> Bool {
        if entry.bodyPart == "腕" { return true }

        let exercise = entry.exercise.lowercased()
        // 「レッグカール」など脚種目の「カール」を腕と誤判定しないよう除外する
        if exercise.contains("レッグ") { return false }

        let armKeywords = ["カール", "プレスダウン", "トライセプス", "キックバック", "スカルクラッシャー"]
        return armKeywords.contains { exercise.contains($0) }
    }
}
