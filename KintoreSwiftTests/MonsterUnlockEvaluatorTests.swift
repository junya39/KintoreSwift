import Foundation
import Testing
@testable import KintoreSwift

struct MonsterUnlockEvaluatorTests {
    private func entry(
        id: Int,
        day: Int,
        hour: Int = 12,
        bodyPart: String = "脚",
        exercise: String = "レッグエクステンション",
        weight: Double = 60,
        reps: Int = 15
    ) -> SetEntry {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = day
        components.hour = hour
        return SetEntry(
            id: id,
            date: Calendar.current.date(from: components)!,
            bodyPart: bodyPart,
            exercise: exercise,
            weight: weight,
            reps: reps,
            note: nil,
            side: nil
        )
    }

    private func unlockedIDs(
        entries: [SetEntry],
        alreadyUnlocked: Set<String> = ["014"]
    ) -> [String] {
        MonsterUnlockEvaluator.newlyUnlockableMonsterIDs(
            entries: entries,
            unlockedMonsterIDs: alreadyUnlocked
        )
    }

    @Test func 記録がなければ何も解放されない() {
        #expect(unlockedIDs(entries: [], alreadyUnlocked: []) == [])
    }

    @Test func 初記録でホラグマが解放される() {
        #expect(unlockedIDs(entries: [entry(id: 1, day: 1)], alreadyUnlocked: []) == ["014"])
    }

    @Test func 解放済みモンスターは再解放されない() {
        #expect(unlockedIDs(entries: [entry(id: 1, day: 1)]) == [])
    }

    @Test func 累計1万kgでバルグロスが解放される() {
        // 60kg × 15回 = 900kg/件 → 12件で10,800kg
        let entries = (1...12).map { entry(id: $0, day: 1) }
        #expect(unlockedIDs(entries: entries) == ["001"])
    }

    @Test func 三日連続でツノガルドが解放される() {
        let entries = (1...3).map { entry(id: $0, day: $0) }
        #expect(unlockedIDs(entries: entries) == ["005"])
    }

    @Test func 七日連続でツノガルドとガルドロードが連鎖解放される() {
        let entries = (1...7).map { entry(id: $0, day: $0) }
        #expect(unlockedIDs(entries: entries) == ["005", "004"])
    }

    @Test func 飛び石の記録は連続日数に数えない() {
        // 1日おきに10日分 → 累計10日でレンゾクンのみ
        let entries = (1...10).map { entry(id: $0, day: $0 * 2) }
        #expect(unlockedIDs(entries: entries) == ["008"])
    }

    @Test func 朝トレ累計3日でアサトレオンが解放される() {
        let entries = [
            entry(id: 1, day: 1, hour: 5),
            entry(id: 2, day: 3, hour: 10),
            entry(id: 3, day: 5, hour: 6)
        ]
        #expect(unlockedIDs(entries: entries) == ["006"])
    }

    @Test func 朝の時間帯は10時台までで11時は含まない() {
        let entries = [
            entry(id: 1, day: 1, hour: 11),
            entry(id: 2, day: 3, hour: 5),
            entry(id: 3, day: 5, hour: 6)
        ]
        #expect(unlockedIDs(entries: entries) == [])
    }

    @Test func 腕トレ累計3回でアームドリルが解放される() {
        let entries = [
            entry(id: 1, day: 1, bodyPart: "腕", exercise: "アームカール"),
            entry(id: 2, day: 1, bodyPart: "ALL", exercise: "ハンマーカール"),
            entry(id: 3, day: 1, bodyPart: "ALL", exercise: "プレスダウン")
        ]
        #expect(unlockedIDs(entries: entries) == ["007"])
    }

    @Test func レッグカールは腕トレに数えない() {
        let entries = (1...3).map {
            entry(id: $0, day: 1, bodyPart: "脚", exercise: "レッグカール")
        }
        #expect(unlockedIDs(entries: entries) == [])
    }

    @Test func ダンベル系累計5回でダンベルンが解放される() {
        let entries = (1...5).map {
            entry(id: $0, day: 1, bodyPart: "ALL", exercise: "ダンベルショルダープレス", weight: 20, reps: 10)
        }
        #expect(unlockedIDs(entries: entries) == ["010"])
    }

    @Test func ベンチプレス累計10回でベンチーノとベンチロードが連鎖解放される() {
        let entries = (1...10).map {
            entry(id: $0, day: 1, bodyPart: "胸", exercise: "ベンチプレス", weight: 100, reps: 5)
        }
        #expect(unlockedIDs(entries: entries) == ["002", "012"])
    }

    @Test func 背中トレ累計10回でデドリガンとデドリロードが連鎖解放される() {
        let entries = (1...10).map {
            entry(id: $0, day: 1, bodyPart: "背中", exercise: "デッドリフト", weight: 0, reps: 5)
        }
        #expect(unlockedIDs(entries: entries) == ["003", "013"])
    }

    @Test func 累計10万kgでバルグロス系統が一括連鎖解放される() {
        // 500kg × 20回 = 10,000kg/件 → 10件で100,000kg（飛び石日付で連続条件は回避）
        let entries = (1...10).map {
            entry(id: $0, day: $0 * 3, bodyPart: "脚", exercise: "レッグプレス", weight: 500, reps: 20)
        }
        #expect(unlockedIDs(entries: entries) == ["001", "008", "009", "011"])
    }

    @Test func 全条件達成でキングバルグが解放される() {
        // 35日連続・朝5日・胸/背中/腕/ダンベル混在・累計350,000kg
        let entries = (1...35).map { day in
            entry(
                id: day,
                day: day,
                hour: day <= 5 ? 6 : 12,
                bodyPart: day % 3 == 0 ? "胸" : (day % 3 == 1 ? "背中" : "腕"),
                exercise: day % 2 == 0 ? "ダンベルベンチプレス" : "デッドリフト",
                weight: 500,
                reps: 20
            )
        }
        let result = unlockedIDs(entries: entries, alreadyUnlocked: [])
        #expect(result.contains("015"))
        #expect(result.count == 15)
    }
}
