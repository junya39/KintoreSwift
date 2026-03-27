import Foundation
import SwiftUI

final class UserStatusViewModel: ObservableObject {
    @Published var level: Int { didSet { persistIfNeeded() } }
    @Published var currentXP: Int { didSet { persistIfNeeded() } }
    @Published var power: Int { didSet { persistIfNeeded() } }
    @Published var endurance: Int { didSet { persistIfNeeded() } }
    @Published var lastGainedXP: Int = 0
    @Published var didLevelUp: Bool = false
    @Published var levelUpEvent: Int?
    @Published var titleManager = TitleManager()

    // 種目ごとの基準値（将来の永続化対象）
    @Published private(set) var baselines: [String: Double] { didSet { persistIfNeeded() } }
    private var isHydrating = true

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
        self.isHydrating = false

        titleManager.evaluateTitles(
            powerLevel: resolvedPower,
            enduranceLevel: resolvedEndurance,
            totalLevel: resolvedLevel
        )
    }

    func addXP(volume: Double, exerciseId: String, baseXPOverride: Double? = nil) {
        guard volume > 0, !exerciseId.isEmpty else { return }

        let baseXP = max(0, baseXPOverride ?? sqrt(volume))

        // baseline未登録時は初回volumeを採用
        let baseline = baselines[exerciseId] ?? volume
        let growthRate = volume / baseline
        let multiplier = min(max(growthRate, 0.8), 1.2)
        let totalBonusMultiplier =
            1 + (Double(power) * 0.01) + (Double(endurance) * 0.01)
        let gainedXP = Int(baseXP * multiplier * totalBonusMultiplier)

        currentXP += gainedXP
        lastGainedXP = gainedXP

        // baselineを指数移動平均で更新
        baselines[exerciseId] = baseline * 0.9 + volume * 0.1

        // レベルアップ判定
        while currentXP >= requiredXP(for: level) {
            currentXP -= requiredXP(for: level)
            level += 1
            levelUpEvent = level
            didLevelUp = true
        }

        titleManager.evaluateTitles(
            powerLevel: power,
            enduranceLevel: endurance,
            totalLevel: level
        )
    }

    func requiredXP(for level: Int) -> Int {
        120 + Int(pow(Double(level), 1.8) * 8)
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
