import SwiftUI
import UIKit

struct MonsterDexView: View {
    @EnvironmentObject private var monsterManager: MonsterManager
    @Environment(\.dismiss) private var dismiss

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
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 5) {
                        Image(systemName: "book.fill")
                            .font(.caption.weight(.heavy))
                            .foregroundColor(.gameGold)

                        Text("発見 \(unlockedCount) / \(MonsterMasterData.monsters.count)")
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
                            .strokeBorder(Color.gameGold.opacity(0.4), lineWidth: 1)
                    )

                    ForEach(sortedMonsters) { monster in
                        MonsterDexRow(
                            monster: monster,
                            isUnlocked: monsterManager.state.unlockedMonsterIDs.contains(monster.id),
                            isBuddy: monsterManager.buddyMonster?.id == monster.id
                        )
                    }
                }
                .padding(16)
            }
            .background(Color.black)
            .navigationTitle("図鑑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                evaluateUnlocksFromStoredRecords()
            }
        }
        .fontDesign(.rounded)
    }

    /// 過去の記録だけで条件を満たしているモンスターを、図鑑を開いたタイミングで解放する
    private func evaluateUnlocksFromStoredRecords() {
        let entries = UserStatusResetStore.statusEligibleEntries(DatabaseManager.shared.fetchAll())
        monsterManager.evaluateUnlocks(entries: entries)
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
                    .monospacedDigit()

                Text(isUnlocked ? monster.name : "???")
                    .font(.headline.weight(.heavy))
                    .foregroundColor(.white)

                Text(isUnlocked ? monster.nickname : lockedHint(for: monster))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.72))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if isUnlocked {
                        MonsterDexBadge(
                            text: monster.type.displayName,
                            color: .gameBlue,
                            foregroundColor: .white
                        )

                        MonsterDexBadge(
                            text: monster.stageDisplayName,
                            color: .gamePurple,
                            foregroundColor: .white
                        )
                    }

                    MonsterDexBadge(
                        text: isUnlocked ? "発見済み" : "未発見",
                        color: isUnlocked ? .gameGold : .white.opacity(0.28),
                        foregroundColor: isUnlocked ? .black : .white
                    )

                    if isBuddy {
                        MonsterDexBadge(
                            text: "相棒中",
                            color: .gameGold,
                            foregroundColor: .black
                        )
                    }
                }

                if isUnlocked {
                    Text(monster.description)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.68))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if isUnlocked, let nextEvolutionText {
                    Text(nextEvolutionText)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.62))
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(isUnlocked ? Color.gameGold.opacity(0.1) : Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isUnlocked ? Color.gameGold.opacity(0.3) : Color.white.opacity(0.08),
                    lineWidth: 1
                )
        )
    }

    private var nextEvolutionText: String? {
        guard let nextEvolutionID = monster.nextEvolutionID else { return nil }

        if let nextMonster = MonsterMasterData.monsters.first(where: {
            normalizedMonsterID($0.id) == normalizedMonsterID(nextEvolutionID)
        }) {
            return "次の進化: \(nextMonster.name)（\(nextEvolutionID)）"
        }

        return "次の進化: \(nextEvolutionID)"
    }

    private func lockedHint(for monster: Monster) -> String {
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
