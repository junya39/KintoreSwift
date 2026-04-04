import Foundation
import SwiftUI

final class TitleManager: ObservableObject {
    @Published var titles: [Title]
    @Published var equippedTitleId: String?
    @Published var newlyUnlockedTitle: Title?

    init(
        titles: [Title] = TitleManager.defaultTitles,
        equippedTitleId: String? = nil
    ) {
        self.titles = titles
        self.equippedTitleId = equippedTitleId
    }

    func evaluateTitles(
        powerLevel: Int,
        enduranceLevel: Int,
        totalLevel: Int,
        shouldEmitEvent: Bool = true
    ) {
        _ = totalLevel // SQLite永続化追加時に保存条件へ利用しやすい受け口を維持
        let diff = powerLevel - enduranceLevel
        let unlockDate = Date()

        unlockIfNeeded(
            id: "brute",
            condition: diff >= 10,
            unlockDate: unlockDate,
            shouldEmitEvent: shouldEmitEvent
        )
        unlockIfNeeded(
            id: "stoic",
            condition: diff <= -10,
            unlockDate: unlockDate,
            shouldEmitEvent: shouldEmitEvent
        )
        unlockIfNeeded(
            id: "balanced",
            condition: abs(diff) <= 5,
            unlockDate: unlockDate,
            shouldEmitEvent: shouldEmitEvent
        )
    }

    func equip(titleId: String) {
        guard titles.contains(where: { $0.id == titleId && $0.isUnlocked }) else { return }
        equippedTitleId = titleId
    }

    func applyBonus(baseXP: Double, type: TitleEffectType) -> Double {
        guard
            baseXP > 0,
            let equippedTitleId,
            let equipped = titles.first(where: { $0.id == equippedTitleId && $0.isUnlocked })
        else {
            return baseXP
        }

        switch equipped.effectType {
        case .totalXP:
            return baseXP * equipped.multiplier
        case .powerXP, .enduranceXP:
            return equipped.effectType == type ? (baseXP * equipped.multiplier) : baseXP
        }
    }

    private func unlockIfNeeded(
        id: String,
        condition: Bool,
        unlockDate: Date,
        shouldEmitEvent: Bool
    ) {
        guard condition, let index = titles.firstIndex(where: { $0.id == id }) else { return }
        guard titles[index].isUnlocked == false else { return }

        titles[index].isUnlocked = true
        titles[index].unlockedDate = unlockDate
        if shouldEmitEvent {
            newlyUnlockedTitle = titles[index]
        }
    }

    private static let defaultTitles: [Title] = [
        Title(
            id: "brute",
            name: "ブルート",
            description: "POWER特化。POWER系XP +5%",
            effectType: .powerXP,
            multiplier: 1.05,
            isUnlocked: false,
            unlockedDate: nil
        ),
        Title(
            id: "stoic",
            name: "ストイック",
            description: "ENDURANCE特化。ENDURANCE系XP +5%",
            effectType: .enduranceXP,
            multiplier: 1.05,
            isUnlocked: false,
            unlockedDate: nil
        ),
        Title(
            id: "balanced",
            name: "バランスド",
            description: "万能型。全XP +3%",
            effectType: .totalXP,
            multiplier: 1.03,
            isUnlocked: false,
            unlockedDate: nil
        )
    ]
}
