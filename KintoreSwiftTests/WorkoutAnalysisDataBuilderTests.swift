import Foundation
import Testing
@testable import KintoreSwift

struct WorkoutAnalysisDataBuilderTests {
    private let timeZone = TimeZone(identifier: "Asia/Tokyo")!
    private let builder = WorkoutAnalysisDataBuilder(fetchEntries: { _ in [] })

    private func date(
        _ day: Int = 14,
        hour: Int,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = timeZone
        components.year = 2026
        components.month = 6
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return components.date!
    }

    private func entry(
        id: Int,
        hour: Int,
        minute: Int = 0,
        bodyPart: String = "胸",
        exercise: String = "ベンチプレス",
        weight: Double = 100,
        reps: Int = 5,
        note: String? = nil,
        side: String? = nil
    ) -> SetEntry {
        SetEntry(
            id: id,
            date: date(hour: hour, minute: minute),
            bodyPart: bodyPart,
            exercise: exercise,
            weight: weight,
            reps: reps,
            note: note,
            side: side
        )
    }

    @Test func 記録が0件でも空のリクエストを生成できる() {
        let request = builder.buildRequest(
            entries: [],
            analysisDate: date(hour: 0),
            timeZone: timeZone,
            generatedAt: date(hour: 20, minute: 30)
        )

        #expect(request.analysisDate == "2026-06-14")
        #expect(request.generatedAt == "2026-06-14T20:30:00+09:00")
        #expect(request.timezone == "Asia/Tokyo")
        #expect(request.totalSets == 0)
        #expect(request.totalReps == 0)
        #expect(request.totalVolumeKg == 0)
        #expect(request.bodyParts == [])
        #expect(request.exercises == [])
    }

    @Test func 1種目複数セットを集計できる() {
        let request = builder.buildRequest(
            entries: [
                entry(id: 2, hour: 10, minute: 5, weight: 105, reps: 3),
                entry(id: 1, hour: 10, weight: 100, reps: 5)
            ],
            analysisDate: date(hour: 0),
            timeZone: timeZone,
            generatedAt: date(hour: 20)
        )

        #expect(request.totalSets == 2)
        #expect(request.totalReps == 8)
        #expect(request.totalVolumeKg == 815)
        #expect(request.bodyParts == ["胸"])
        #expect(request.exercises.count == 1)
        #expect(request.exercises[0].exerciseName == "ベンチプレス")
        #expect(request.exercises[0].setCount == 2)
        #expect(request.exercises[0].totalReps == 8)
        #expect(request.exercises[0].totalVolumeKg == 815)
        #expect(request.exercises[0].sets.map(\.id) == [1, 2])
    }

    @Test func 複数種目は最初の記録時刻順で並ぶ() {
        let request = builder.buildRequest(
            entries: [
                entry(id: 3, hour: 11, bodyPart: "背中", exercise: "デッドリフト", weight: 140, reps: 3),
                entry(id: 1, hour: 9, bodyPart: "胸", exercise: "ベンチプレス", weight: 100, reps: 5),
                entry(id: 2, hour: 10, bodyPart: "脚", exercise: "スクワット", weight: 120, reps: 5)
            ],
            analysisDate: date(hour: 0),
            timeZone: timeZone
        )

        #expect(request.exercises.map(\.exerciseName) == ["ベンチプレス", "スクワット", "デッドリフト"])
        #expect(request.bodyParts == ["胸", "脚", "背中"])
    }

    @Test func 同じ種目名でもbodyPartが異なる場合は別種目として扱う() {
        let request = builder.buildRequest(
            entries: [
                entry(id: 1, hour: 9, bodyPart: "胸", exercise: "プレス", weight: 50, reps: 10),
                entry(id: 2, hour: 10, bodyPart: "肩", exercise: "プレス", weight: 30, reps: 10)
            ],
            analysisDate: date(hour: 0),
            timeZone: timeZone
        )

        #expect(request.exercises.count == 2)
        #expect(request.exercises.map(\.bodyPart) == ["胸", "肩"])
        #expect(request.exercises.map(\.exerciseName) == ["プレス", "プレス"])
    }

    @Test func 同じ時刻の種目とセットはid順で並ぶ() {
        let request = builder.buildRequest(
            entries: [
                entry(id: 4, hour: 9, bodyPart: "脚", exercise: "スクワット", weight: 120, reps: 3),
                entry(id: 2, hour: 9, bodyPart: "胸", exercise: "ベンチプレス", weight: 100, reps: 5),
                entry(id: 3, hour: 9, bodyPart: "胸", exercise: "ベンチプレス", weight: 100, reps: 4),
                entry(id: 1, hour: 9, bodyPart: "背中", exercise: "ロー", weight: 60, reps: 10)
            ],
            analysisDate: date(hour: 0),
            timeZone: timeZone
        )

        #expect(request.exercises.map(\.exerciseName) == ["ロー", "ベンチプレス", "スクワット"])
        #expect(request.exercises[1].sets.map(\.id) == [2, 3])
    }

    @Test func noteが空の場合はnilになりsideは保持される() {
        let request = builder.buildRequest(
            entries: [
                entry(id: 1, hour: 9, weight: 20, reps: 12, note: "", side: "R"),
                entry(id: 2, hour: 9, minute: 1, weight: 20, reps: 12, note: "軽め", side: "L")
            ],
            analysisDate: date(hour: 0),
            timeZone: timeZone
        )

        #expect(request.exercises[0].sets[0].note == nil)
        #expect(request.exercises[0].sets[0].side == "R")
        #expect(request.exercises[0].sets[1].note == "軽め")
        #expect(request.exercises[0].sets[1].side == "L")
    }

    @Test func weightが0の記録はvolumeを0にして自重とは断定しない() {
        let request = builder.buildRequest(
            entries: [
                entry(id: 1, hour: 9, bodyPart: "背中", exercise: "チンニング", weight: 0, reps: 10)
            ],
            analysisDate: date(hour: 0),
            timeZone: timeZone
        )

        #expect(request.totalVolumeKg == 0)
        #expect(request.exercises[0].totalVolumeKg == 0)
        #expect(request.exercises[0].sets[0].isBodyweight == false)
    }

    @Test func JSONエンコードできる() throws {
        let request = builder.buildRequest(
            entries: [
                entry(id: 1, hour: 9, weight: 100, reps: 5, note: "良い", side: nil)
            ],
            analysisDate: date(hour: 0),
            timeZone: timeZone,
            generatedAt: date(hour: 20, minute: 30)
        )

        let json = try builder.encodeJSONString(request, style: .debugPrettyPrinted)

        #expect(json.contains("\"analysisDate\" : \"2026-06-14\""))
        #expect(json.contains("\"generatedAt\" : \"2026-06-14T20:30:00+09:00\""))
        #expect(json.contains("\"totalSets\" : 1"))
        #expect(json.contains("\"exerciseName\" : \"ベンチプレス\""))
    }
}
