import Foundation

enum TitleEffectType: String, Codable {
    case totalXP
    case powerXP
    case enduranceXP
}

struct Title: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let description: String
    let effectType: TitleEffectType
    let multiplier: Double
    var isUnlocked: Bool
    var unlockedDate: Date?
}
