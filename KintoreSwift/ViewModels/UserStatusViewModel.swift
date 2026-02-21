import Foundation
import SwiftUI

final class UserStatusViewModel: ObservableObject {
    @Published var level: Int
    @Published var currentXP: Int
    @Published var lastGainedXP: Int = 0
    @Published var didLevelUp: Bool = false
    @Published var levelUpEvent: Int?

    // 種目ごとの基準値（将来の永続化対象）
    @Published private(set) var baselines: [String: Double]

    init(
        level: Int = 1,
        currentXP: Int = 0,
        baselines: [String: Double] = [:]
    ) {
        self.level = max(1, level)
        self.currentXP = max(0, currentXP)
        self.baselines = baselines
    }

    func addXP(volume: Double, exerciseId: String) {
        guard volume > 0, !exerciseId.isEmpty else { return }

        let baseXP = sqrt(volume)

        // baseline未登録時は初回volumeを採用
        let baseline = baselines[exerciseId] ?? volume
        let growthRate = volume / baseline
        let multiplier = min(max(growthRate, 0.8), 1.2)
        let gainedXP = Int(baseXP * multiplier)

        currentXP += gainedXP
        lastGainedXP = gainedXP

        // baselineを指数移動平均で更新
        baselines[exerciseId] = baseline * 0.9 + volume * 0.1

        // レベルアップ判定
        while currentXP >= requiredXP(for: level) {
            currentXP -= requiredXP(for: level)
            level += 1
            didLevelUp = true
        }
    }

    func requiredXP(for level: Int) -> Int {
        100 + level * 3
    }

    func getProgress() -> Double {
        let required = requiredXP(for: level)
        guard required > 0 else { return 0.0 }
        let progress = Double(currentXP) / Double(required)
        return min(max(progress, 0.0), 1.0)
    }
}
