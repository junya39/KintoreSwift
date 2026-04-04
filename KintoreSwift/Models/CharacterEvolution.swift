import Foundation

struct EvolutionEvent: Identifiable, Equatable {
    let id = UUID()
    let fromName: String
    let toName: String
}

struct EvolutionStageInfo: Equatable {
    let name: String
    let assetName: String
    let imageNames: [String]
    let form: CharacterForm
}

func evolutionStage(for level: Int) -> EvolutionStageInfo {
    if level >= 30 {
        return EvolutionStageInfo(
            name: "マッチョ",
            assetName: "lv30_idle_1",
            imageNames: ["lv30_idle_1", "lv30_idle_2", "lv30_idle_3"],
            form: .finalForm
        )
    } else if level >= 15 {
        return EvolutionStageInfo(
            name: "ホソマッチョ",
            assetName: "lv15_idle_1",
            imageNames: ["lv15_idle_1", "lv15_idle_2", "lv15_idle_3"],
            form: .macho
        )
    } else {
        return EvolutionStageInfo(
            name: "フツウ",
            assetName: "lv1_idle_1",
            imageNames: ["lv1_idle_1", "lv1_idle_2", "lv1_idle_3"],
            form: .skinny
        )
    }
}

func evolutionEventForTransition(oldLevel: Int, newLevel: Int) -> EvolutionEvent? {
    guard newLevel > oldLevel else { return nil }

    if oldLevel < 30 && newLevel >= 30 {
        return EvolutionEvent(
            fromName: oldLevel >= 15 ? "ホソマッチョ" : "フツウ",
            toName: "マッチョ"
        )
    } else if oldLevel < 15 && newLevel >= 15 {
        return EvolutionEvent(
            fromName: "フツウ",
            toName: "ホソマッチョ"
        )
    } else {
        return nil
    }
}

func evolutionImageNames(for event: EvolutionEvent) -> [String] {
    switch event.toName {
    case "ホソマッチョ":
        return ["lv15_idle_1", "lv15_idle_2", "lv15_idle_3"]
    case "マッチョ":
        return ["lv30_idle_1", "lv30_idle_2", "lv30_idle_3"]
    default:
        return ["lv1_idle_1", "lv1_idle_2", "lv1_idle_3"]
    }
}
