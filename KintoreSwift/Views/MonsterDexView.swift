import SwiftUI
import UIKit

struct MonsterDexView: View {
    @EnvironmentObject private var monsterManager: MonsterManager

    private var sortedMonsters: [Monster] {
        MonsterMasterData.monsters.sorted { lhs, rhs in
            let lhsUnlocked = monsterManager.state.unlockedMonsterIDs.contains(lhs.id)
            let rhsUnlocked = monsterManager.state.unlockedMonsterIDs.contains(rhs.id)
            if lhsUnlocked != rhsUnlocked {
                return lhsUnlocked
            }
            return lhs.number < rhs.number
        }
    }

    private var unlockedCount: Int {
        MonsterMasterData.monsters.filter {
            monsterManager.state.unlockedMonsterIDs.contains($0.id)
        }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text("解放済み \(unlockedCount) / \(MonsterMasterData.monsters.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.green.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())

                    ForEach(sortedMonsters) { monster in
                        MonsterDexRow(
                            monster: monster,
                            isUnlocked: monsterManager.state.unlockedMonsterIDs.contains(monster.id),
                            isBuddy: monsterManager.buddyMonster?.id == monster.id
                        )
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("MonsterDex")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct MonsterDexRow: View {
    let monster: Monster
    let isUnlocked: Bool
    let isBuddy: Bool

    var body: some View {
        HStack(spacing: 14) {
            MonsterDexArtwork(monster: monster, isUnlocked: isUnlocked)

            VStack(alignment: .leading, spacing: 6) {
                Text(monster.displayNumber)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.55))

                Text(isUnlocked ? monster.name : "???")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)

                Text(isUnlocked ? monster.nickname : lockedHint(for: monster))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.72))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    MonsterDexBadge(
                        text: isUnlocked ? "解放済み" : "未解放",
                        color: isUnlocked ? .green : .white.opacity(0.28),
                        foregroundColor: .white
                    )

                    if isBuddy {
                        MonsterDexBadge(
                            text: "相棒中",
                            color: .yellow,
                            foregroundColor: .black
                        )
                    }
                }
            }

            Spacer()
        }
        .padding(12)
        .background(isUnlocked ? Color.green.opacity(0.14) : Color.white.opacity(0.08))
        .cornerRadius(14)
    }

    private func lockedHint(for monster: Monster) -> String {
        if let sourceMonster = MonsterMasterData.monsters.first(where: {
            guard let nextEvolutionID = $0.nextEvolutionID else { return false }
            return normalizedMonsterID(nextEvolutionID) == normalizedMonsterID(monster.id)
        }) {
            return "\(sourceMonster.name)から進化"
        }

        if monster.unlockCondition.contains("から進化") {
            return "あるモンスターから進化"
        }

        return monster.unlockCondition
    }

    private func normalizedMonsterID(_ id: String) -> String {
        id.replacingOccurrences(of: "monster_", with: "")
    }
}

private struct MonsterDexArtwork: View {
    let monster: Monster
    let isUnlocked: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.35))
                .frame(width: 72, height: 72)

            if isUnlocked, UIImage(named: monster.imageName) != nil {
                Image(monster.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 66, height: 66)
                    .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
            } else {
                Image(systemName: "questionmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))
            }
        }
    }
}

private struct MonsterDexBadge: View {
    let text: String
    let color: Color
    let foregroundColor: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.9))
            .clipShape(Capsule())
    }
}
