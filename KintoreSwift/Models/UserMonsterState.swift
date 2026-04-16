import Foundation

struct UserMonsterState: Codable, Equatable {
    var unlockedMonsterIDs: Set<String>
    var buddyMonsterID: String?

    static let empty = UserMonsterState(
        unlockedMonsterIDs: [],
        buddyMonsterID: nil
    )
}
