import Foundation

struct Monster: Identifiable, Codable, Equatable {
    let id: String
    let number: Int
    let imageName: String
    let name: String
    let nickname: String
    let evolutionStage: Int
    let description: String
    let unlockCondition: String
    let nextEvolutionID: String?

    var displayNumber: String {
        String(format: "#%03d", number)
    }
}

extension Monster {
    static let horaguma = MonsterMasterData.horaguma
}
