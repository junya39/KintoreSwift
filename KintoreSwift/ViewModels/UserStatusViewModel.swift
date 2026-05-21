import Foundation
import SwiftUI

struct LevelUpEvent: Equatable {
    let level: Int
    let powerGain: Int
    let enduranceGain: Int
}

final class UserStatusViewModel: ObservableObject {
    @Published var level: Int { didSet { persistIfNeeded() } }
    @Published var currentXP: Int { didSet { persistIfNeeded() } }
    @Published var power: Int { didSet { persistIfNeeded() } }
    @Published var endurance: Int { didSet { persistIfNeeded() } }
    @Published var lastGainedXP: Int = 0
    @Published var didLevelUp: Bool = false
    @Published var levelUpEvent: LevelUpEvent?
    @Published var titleManager = TitleManager()
    @Published private(set) var statusResetDate: Date?

    // 種目ごとの基準値（将来の永続化対象）
    @Published private(set) var baselines: [String: Double] { didSet { persistIfNeeded() } }
    private var isHydrating = true
    private var pendingLevelUpLevel: Int?
    private let maxXPPerSet = 500

    init(
        level: Int = 1,
        currentXP: Int = 0,
        baselines: [String: Double] = [:]
    ) {
        let persisted = DatabaseManager.shared.fetchUserStatus()
        let resolvedLevel = max(1, persisted?.level ?? level)
        let resolvedCurrentXP = max(0, persisted?.currentXP ?? currentXP)
        let resolvedPower = max(0, persisted?.power ?? 0)
        let resolvedEndurance = max(0, persisted?.endurance ?? 0)
        let resolvedBaselines = persisted
            .map { Self.decodeBaselines(from: $0.baselinesJSON) }
            ?? baselines

        self.level = resolvedLevel
        self.currentXP = resolvedCurrentXP
        self.power = resolvedPower
        self.endurance = resolvedEndurance
        self.baselines = resolvedBaselines
        self.statusResetDate = UserStatusResetStore.statusResetDate()
        self.isHydrating = false

        titleManager.evaluateTitles(
            powerLevel: resolvedPower,
            enduranceLevel: resolvedEndurance,
            totalLevel: resolvedLevel,
            showUnlockToast: false
        )
    }

    @discardableResult
    func addXP(
        weight: Double,
        reps: Int,
        exerciseId: String,
        isBodyweight: Bool,
        previousBestVolume: Double?,
        isFirstSetOfDay: Bool,
        baseXPOverride: Double? = nil
    ) -> Int {
        guard !exerciseId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return recordNoXP()
        }

        let gainedXP = calculateXP(
            weight: weight,
            reps: reps,
            exerciseId: exerciseId,
            isBodyweight: isBodyweight,
            previousBestVolume: previousBestVolume,
            isFirstSetOfDay: isFirstSetOfDay,
            baseXPOverride: baseXPOverride
        )
        guard gainedXP > 0 else { return recordNoXP() }

        currentXP += gainedXP
        lastGainedXP = gainedXP

        let calculationWeight = isBodyweight ? 30.0 : min(max(weight, 0), 500)
        let calculationReps = min(max(reps, 1), 100)
        let volume = calculationWeight * Double(calculationReps)
        if volume.isFinite, volume > 0 {
            if let baseline = baselines[exerciseId], baseline.isFinite, baseline > 0 {
                baselines[exerciseId] = baseline * 0.9 + volume * 0.1
            } else {
                baselines[exerciseId] = volume
            }
        }

        // レベルアップ判定
        while currentXP >= requiredXP(for: level) {
            currentXP -= requiredXP(for: level)
            level += 1
            pendingLevelUpLevel = level
            didLevelUp = true
        }

        titleManager.evaluateTitles(
            powerLevel: power,
            enduranceLevel: endurance,
            totalLevel: level,
            showUnlockToast: false
        )

        return gainedXP
    }

    private func calculateXP(
        weight: Double,
        reps: Int,
        exerciseId: String,
        isBodyweight: Bool,
        previousBestVolume: Double?,
        isFirstSetOfDay: Bool,
        baseXPOverride: Double?
    ) -> Int {
        guard reps > 0, weight >= 0 else { return 0 }

        let calculationReps = min(reps, 100)
        let calculationWeight = isBodyweight ? 30.0 : min(weight, 500)
        let volume = calculationWeight * Double(calculationReps)
        guard volume.isFinite, volume > 0 else { return 0 }

        let baseXP = 10.0
        let volumeXP = sqrt(volume)
        let repsMultiplier = repsCorrection(for: calculationReps)
        let baselineMultiplier = baselineGrowthMultiplier(for: exerciseId, volume: volume)
        let titleAdjustedXP = baseXPOverride.flatMap { value -> Double? in
            guard value.isFinite, value >= 0 else { return nil }
            return value
        }
        let effortXP = titleAdjustedXP ?? (baseXP + volumeXP * repsMultiplier * baselineMultiplier)
        let prBonus = prBonus(currentVolume: volume, previousBestVolume: previousBestVolume)
        let dailyBonus = isFirstSetOfDay ? 20.0 : 0.0
        // TODO: 日別XP付与履歴を永続化したら、ストリークボーナスと1日1500XP上限をここで1日1回だけ適用する。
        let streakBonus = 0.0

        var finalXP = effortXP + prBonus + dailyBonus + streakBonus
        let setCap = prBonus > 0 ? 250.0 : 150.0
        finalXP = min(finalXP, setCap)

        guard finalXP.isFinite, finalXP >= 0 else { return 0 }
        return min(max(Int(finalXP.rounded()), 0), maxXPPerSet)
    }

    private func repsCorrection(for reps: Int) -> Double {
        switch reps {
        case 1...3:
            return 1.15
        case 4...8:
            return 1.10
        case 9...17:
            return 1.05
        default:
            return 1.10
        }
    }

    private func baselineGrowthMultiplier(for exerciseId: String, volume: Double) -> Double {
        guard
            let baseline = baselines[exerciseId],
            baseline.isFinite,
            baseline > 1,
            volume.isFinite,
            volume > 0
        else {
            return 1.0
        }

        let rawGrowthRate = volume / baseline
        guard rawGrowthRate.isFinite, rawGrowthRate > 0 else { return 1.0 }
        return min(max(rawGrowthRate, 0.5), 2.0)
    }

    private func prBonus(currentVolume: Double, previousBestVolume: Double?) -> Double {
        guard
            let previousBestVolume,
            previousBestVolume.isFinite,
            previousBestVolume > 0,
            currentVolume > previousBestVolume
        else {
            return 0
        }

        return currentVolume >= previousBestVolume * 1.10 ? 50 : 30
    }

    private func recordNoXP() -> Int {
        lastGainedXP = 0
        return 0
    }

    func publishPendingLevelUpIfNeeded(powerGain: Int, enduranceGain: Int) {
        guard let pendingLevelUpLevel else { return }
        levelUpEvent = LevelUpEvent(
            level: pendingLevelUpLevel,
            powerGain: max(0, powerGain),
            enduranceGain: max(0, enduranceGain)
        )
        self.pendingLevelUpLevel = nil
    }

    func requiredXP(for level: Int) -> Int {
        300 + max(1, level) * 50
    }

    func resetUserStatusForDebug() {
        resetStatusProgress()
    }

    func resetStatusProgress(resetDate: Date = Date()) {
        UserStatusResetStore.saveStatusResetDate(resetDate)
        statusResetDate = resetDate
        level = 1
        currentXP = 0
        power = 0
        endurance = 0
        lastGainedXP = 0
        didLevelUp = false
        levelUpEvent = nil
        pendingLevelUpLevel = nil
        baselines = [:]
        titleManager.resetProgress()
    }

    func getProgress() -> Double {
        let required = requiredXP(for: level)
        guard required > 0 else { return 0.0 }
        let progress = Double(currentXP) / Double(required)
        return min(max(progress, 0.0), 1.0)
    }

    private func persistIfNeeded() {
        guard !isHydrating else { return }

        DatabaseManager.shared.saveUserStatus(
            level: max(1, level),
            currentXP: max(0, currentXP),
            power: max(0, power),
            endurance: max(0, endurance),
            baselinesJSON: Self.encodeBaselines(baselines)
        )
    }

    private static func encodeBaselines(_ baselines: [String: Double]) -> String {
        guard
            let data = try? JSONEncoder().encode(baselines),
            let text = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return text
    }

    private static func decodeBaselines(from text: String) -> [String: Double] {
        guard let data = text.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
    }
}
