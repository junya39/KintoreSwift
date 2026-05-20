import Foundation

enum MonsterType: String, Codable, Equatable {
    case power
    case endurance
    case balanced
    case habit
    case special

    var displayName: String {
        switch self {
        case .power:
            return "Power"
        case .endurance:
            return "Endurance"
        case .balanced:
            return "Balanced"
        case .habit:
            return "Habit"
        case .special:
            return "Special"
        }
    }
}

struct Monster: Identifiable, Codable, Equatable {
    let id: String
    let number: Int
    let imageName: String
    let name: String
    let nickname: String
    let type: MonsterType
    let evolutionStage: Int
    let description: String
    let unlockCondition: String
    let nextEvolutionID: String?

    var displayNumber: String {
        String(format: "#%03d", number)
    }

    var stageDisplayName: String {
        "Stage \(evolutionStage)"
    }
}

extension Monster {
    static let horaguma = MonsterMasterData.horaguma
}
