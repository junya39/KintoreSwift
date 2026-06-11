import Foundation

final class MonsterManager: ObservableObject {
    private enum Storage {
        static let key = "UserMonsterState.v1"
    }

    let monsters: [Monster] = MonsterMasterData.monsters

    @Published private(set) var state: UserMonsterState {
        didSet {
            save()
        }
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.state = Self.load(from: userDefaults)
    }

    var unlockedMonsters: [Monster] {
        monsters.filter { state.unlockedMonsterIDs.contains($0.id) }
    }

    var buddyMonster: Monster? {
        guard let buddyMonsterID = state.buddyMonsterID else { return nil }
        return monsters.first { $0.id == buddyMonsterID && state.unlockedMonsterIDs.contains($0.id) }
    }

    /// 記録データから全モンスターの解放条件を判定し、新しく解放されたモンスターを返す。
    @discardableResult
    func evaluateUnlocks(entries: [SetEntry]) -> [Monster] {
        let newlyUnlockedIDs = MonsterUnlockEvaluator.newlyUnlockableMonsterIDs(
            entries: entries,
            unlockedMonsterIDs: state.unlockedMonsterIDs
        )
        return newlyUnlockedIDs.compactMap { id in
            guard unlock(monsterID: id) else { return nil }
            return monsters.first { $0.id == id }
        }
    }

    @discardableResult
    func unlock(monsterID: String) -> Bool {
        guard monsters.contains(where: { $0.id == monsterID }) else { return false }
        guard state.unlockedMonsterIDs.contains(monsterID) == false else { return false }
        state.unlockedMonsterIDs.insert(monsterID)
        return true
    }

    func setBuddy(monsterID: String) {
        guard state.unlockedMonsterIDs.contains(monsterID) else { return }
        state.buddyMonsterID = monsterID
    }

    func resetUnlockProgress() {
        state = .empty
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        userDefaults.set(data, forKey: Storage.key)
    }

    private static func load(from userDefaults: UserDefaults) -> UserMonsterState {
        guard
            let data = userDefaults.data(forKey: Storage.key),
            let state = try? JSONDecoder().decode(UserMonsterState.self, from: data)
        else {
            return .empty
        }
        return state
    }
}
