import Foundation

enum MonsterMasterData {
    static let monsters: [Monster] = [
        Monster(
            id: "001",
            number: 1,
            imageName: "monster_001",
            name: "バルグロス",
            nickname: "鉄を喰らう怪物",
            type: .power,
            evolutionStage: 1,
            description: "バーベルを握るほど力を増す重量型モンスター。重さへの執着が強く、総挙上重量の伸びに反応して姿を現す。",
            unlockCondition: "累計総挙上重量 10,000kg を達成する",
            nextEvolutionID: "monster_009"
        ),
        Monster(
            id: "002",
            number: 2,
            imageName: "monster_002",
            name: "ベンチーノ",
            nickname: "胸圧の幼獣",
            type: .power,
            evolutionStage: 1,
            description: "胸トレの熱気に引き寄せられる幼獣。ベンチ台の近くに現れ、胸の成長を静かに見守る。",
            unlockCondition: "胸トレを累計3回記録する",
            nextEvolutionID: "monster_012"
        ),
        Monster(
            id: "003",
            number: 3,
            imageName: "monster_003",
            name: "デドリガン",
            nickname: "引力の支配者",
            type: .power,
            evolutionStage: 1,
            description: "背中の力に反応する怪力モンスター。引く動作を好み、ローイングやチンニングの記録に引き寄せられる。",
            unlockCondition: "背中トレを累計3回記録する",
            nextEvolutionID: "monster_013"
        ),
        Monster(
            id: "004",
            number: 4,
            imageName: "monster_004",
            name: "ガルドロード",
            nickname: "継続の剛角",
            type: .habit,
            evolutionStage: 2,
            description: "継続の力で角をさらに硬くしたツノガルドの進化形。連続して鍛える者の前にだけ姿を現す。",
            unlockCondition: "ツノガルド解放後、7日連続で筋トレを記録する",
            nextEvolutionID: nil
        ),
        Monster(
            id: "005",
            number: 5,
            imageName: "monster_005",
            name: "ツノガルド",
            nickname: "無口の剛腕",
            type: .habit,
            evolutionStage: 1,
            description: "黙々と積み重ねる者に寄り添う継続型モンスター。派手さはないが、毎日の記録によって確実に力を増す。",
            unlockCondition: "3日連続で筋トレを記録する",
            nextEvolutionID: "monster_004"
        ),
        Monster(
            id: "006",
            number: 6,
            imageName: "monster_006",
            name: "アサトレオン",
            nickname: "朝を制する獣",
            type: .habit,
            evolutionStage: 1,
            description: "朝の静かな時間帯にだけ現れる習慣型モンスター。眠気に勝って記録した者を好む。",
            unlockCondition: "朝5:00〜10:59に筋トレを累計3日記録する",
            nextEvolutionID: nil
        ),
        Monster(
            id: "007",
            number: 7,
            imageName: "monster_007",
            name: "アームドリル",
            nickname: "鋼腕の穴掘り獣",
            type: .power,
            evolutionStage: 1,
            description: "腕のパンプに反応して地中から飛び出すモンスター。カールやプレスダウンの刺激を好む。",
            unlockCondition: "腕トレを累計3回記録する",
            nextEvolutionID: nil
        ),
        Monster(
            id: "008",
            number: 8,
            imageName: "monster_008",
            name: "レンゾクン",
            nickname: "記録を食べる小獣",
            type: .habit,
            evolutionStage: 1,
            description: "日々の記録をエネルギーにする小さなモンスター。連続でなくても、積み重ねた日数に反応する。",
            unlockCondition: "筋トレ記録日数を累計10日にする",
            nextEvolutionID: nil
        ),
        Monster(
            id: "009",
            number: 9,
            imageName: "monster_009",
            name: "バルグロス改",
            nickname: "鉄塊を砕く者",
            type: .power,
            evolutionStage: 2,
            description: "より大きな総挙上重量に適応したバルグロスの進化形。重い記録を重ねるほど体が硬く大きくなる。",
            unlockCondition: "バルグロス解放後、累計総挙上重量 50,000kg を達成する",
            nextEvolutionID: "monster_011"
        ),
        Monster(
            id: "010",
            number: 10,
            imageName: "monster_010",
            name: "ダンベルン",
            nickname: "片手重量の番人",
            type: .balanced,
            evolutionStage: 1,
            description: "片手ずつ扱う重量に反応するバランス型モンスター。左右差を整えるような種目を好む。",
            unlockCondition: "ダンベル系種目を累計5回記録する",
            nextEvolutionID: nil
        ),
        Monster(
            id: "011",
            number: 11,
            imageName: "monster_011",
            name: "バルグロン",
            nickname: "重量界の暴君",
            type: .power,
            evolutionStage: 3,
            description: "バルグロス系統の最終進化。圧倒的な総挙上重量を積み重ねた者の前に現れる重量界の暴君。",
            unlockCondition: "バルグロス改解放後、累計総挙上重量 100,000kg を達成する",
            nextEvolutionID: nil
        ),
        Monster(
            id: "012",
            number: 12,
            imageName: "monster_012",
            name: "ベンチロード",
            nickname: "胸圧の王",
            type: .power,
            evolutionStage: 2,
            description: "胸トレを積み重ねたベンチーノの進化形。押す力と胸の厚みに誇りを持つ。",
            unlockCondition: "ベンチーノ解放後、ベンチプレス系種目を累計10回記録する",
            nextEvolutionID: nil
        ),
        Monster(
            id: "013",
            number: 13,
            imageName: "monster_013",
            name: "デドリロード",
            nickname: "背面の覇者",
            type: .power,
            evolutionStage: 2,
            description: "背中の記録を積み重ねたデドリガンの進化形。広背筋と引く力を象徴する背面の覇者。",
            unlockCondition: "デドリガン解放後、背中トレを累計10回記録する",
            nextEvolutionID: nil
        ),
        Monster(
            id: "014",
            number: 14,
            imageName: "monster_014",
            name: "ホラグマ",
            nickname: "驚愕の怪力種",
            type: .special,
            evolutionStage: 1,
            description: "初めての記録に驚いて現れる不思議なモンスター。最初の一歩を踏み出した者の相棒になる。",
            unlockCondition: "はじめて筋トレを記録する",
            nextEvolutionID: nil
        ),
        Monster(
            id: "015",
            number: 15,
            imageName: "monster_015",
            name: "キングバルグ",
            nickname: "図鑑の王",
            type: .special,
            evolutionStage: 3,
            description: "多くの記録、多くの出会い、長い継続を積み重ねた者だけが出会えるMonsterDexの王。",
            unlockCondition: "累計300,000kg・記録30日・7日連続・10体解放を達成する",
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
