import Foundation

enum MonsterMasterData {
    static let monsters: [Monster] = [
        Monster(
            id: "001",
            number: 1,
            imageName: "monster_001",
            name: "バルグロン",
            nickname: "鉄棒の怪腕",
            evolutionStage: 1,
            description: "バーベルを握った瞬間に性格が変わる怪力モンスター。筋力の伸びに最も敏感で、重さに執着する。",
            unlockCondition: "総挙上重量が一定以上になる",
            nextEvolutionID: "011"
        ),
        Monster(
            id: "002",
            number: 2,
            imageName: "monster_002",
            name: "ベンチーノ",
            nickname: "胸圧の幼獣",
            evolutionStage: 1,
            description: "ベンチプレス台に棲みつく小型種。見た目は不安定だが、胸トレへの執念だけは異様に強い。",
            unlockCondition: "胸トレを3回記録",
            nextEvolutionID: "012"
        ),
        Monster(
            id: "003",
            number: 3,
            imageName: "monster_003",
            name: "デドリガン",
            nickname: "引力の支配者",
            evolutionStage: 2,
            description: "床に置かれたバーベルを見ると本能が目覚める。デッドリフト系統の中堅種。",
            unlockCondition: "背中トレを3回記録",
            nextEvolutionID: "013"
        ),
        Monster(
            id: "004",
            number: 4,
            imageName: "monster_004",
            name: "ホーンラック",
            nickname: "角持つ剛体",
            evolutionStage: 2,
            description: "ベンチ周辺を縄張りにする大型種。耐久力と重量耐性に優れ、簡単には倒れない。",
            unlockCondition: "高重量種目の記録を複数回行う",
            nextEvolutionID: nil
        ),
        Monster(
            id: "005",
            number: 5,
            imageName: "monster_005",
            name: "ツノガルド",
            nickname: "無口の剛腕",
            evolutionStage: 1,
            description: "感情を表に出さないが、静かに鍛え続ける堅実な種族。継続の象徴。",
            unlockCondition: "7日以上継続記録",
            nextEvolutionID: "004"
        ),
        Monster(
            id: "006",
            number: 6,
            imageName: "monster_006",
            name: "モフリフト",
            nickname: "眠れる白塊",
            evolutionStage: 1,
            description: "ふわふわの見た目とは裏腹に、持ち上げる重量はかなり重い。油断すると一気に覚醒する。",
            unlockCondition: "朝トレを一定回数達成",
            nextEvolutionID: nil
        ),
        Monster(
            id: "007",
            number: 7,
            imageName: "monster_007",
            name: "クロウガル",
            nickname: "爪牙の拳鬼",
            evolutionStage: 2,
            description: "闘争本能でダンベルを振り回す狂戦士タイプ。短時間で爆発力を発揮する。",
            unlockCondition: "腕トレ回数が一定以上",
            nextEvolutionID: nil
        ),
        Monster(
            id: "008",
            number: 8,
            imageName: "monster_008",
            name: "ガンマウス",
            nickname: "咆哮の細腕",
            evolutionStage: 1,
            description: "細身だが異様な気迫を放つ。大口を開けて気合いを集めることで出力を上げる。",
            unlockCondition: "連続記録日数を達成",
            nextEvolutionID: nil
        ),
        Monster(
            id: "009",
            number: 9,
            imageName: "monster_009",
            name: "メガドラン",
            nickname: "青眼の重装獣",
            evolutionStage: 3,
            description: "進化の最終段階に近い大型種。圧倒的な重量を好み、存在自体が威圧感を放つ。",
            unlockCondition: "上級者条件",
            nextEvolutionID: nil
        ),
        Monster(
            id: "010",
            number: 10,
            imageName: "monster_010",
            name: "ダンベルガ",
            nickname: "双鉄の暴君",
            evolutionStage: 2,
            description: "両手にダンベルを持つことを誇りとする。左右差を制することでさらに強くなる。",
            unlockCondition: "ダンベル種目を一定数実施",
            nextEvolutionID: nil
        ),
        Monster(
            id: "011",
            number: 11,
            imageName: "monster_011",
            name: "バルグロス",
            nickname: "鉄塊進化体",
            evolutionStage: 2,
            description: "バルグロンの進化体。筋密度が増し、体表に鋼のような質感が生まれている。",
            unlockCondition: "monster_001から進化",
            nextEvolutionID: "009"
        ),
        Monster(
            id: "012",
            number: 12,
            imageName: "monster_012",
            name: "ベンチザウル",
            nickname: "胸獣の覚醒体",
            evolutionStage: 2,
            description: "ベンチーノが成長した姿。胸トレの総負荷に反応して凶暴化する。",
            unlockCondition: "monster_002から進化",
            nextEvolutionID: nil
        ),
        Monster(
            id: "013",
            number: 13,
            imageName: "monster_013",
            name: "デドレックス",
            nickname: "断裂の王",
            evolutionStage: 3,
            description: "デドリガンの最終進化体。全身が重量に最適化され、背中系統の王として君臨する。",
            unlockCondition: "monster_003から進化",
            nextEvolutionID: nil
        ),
        Monster(
            id: "014",
            number: 14,
            imageName: "monster_014",
            name: "ホラグマ",
            nickname: "驚愕の怪力種",
            evolutionStage: 1,
            description: "常に驚いた表情をしているが、潜在能力は高い。初心者の成長に寄り添う種。",
            unlockCondition: "初回ワークアウト完了",
            nextEvolutionID: nil
        ),
        Monster(
            id: "015",
            number: 15,
            imageName: "monster_015",
            name: "ギガマウス",
            nickname: "絶叫の筋王",
            evolutionStage: 3,
            description: "極限の興奮状態でのみ姿を見せる希少種。限界突破の象徴。",
            unlockCondition: "高難度条件",
            nextEvolutionID: nil
        )
    ]

    static let horaguma = monster(id: "014")
    static let tsunogard = monster(id: "005")
    static let benchino = monster(id: "002")
    static let dedorigan = monster(id: "003")

    static func monster(id: String) -> Monster {
        guard let monster = monsters.first(where: { $0.id == id }) else {
            fatalError("Missing monster master data: \(id)")
        }
        return monster
    }
}
