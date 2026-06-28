import Foundation
import Testing
@testable import KintoreSwift

@MainActor
struct WorkoutAnalysisViewModelTests {
    private let timeZone = TimeZone(identifier: "Asia/Tokyo")!

    private func date(
        hour: Int,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = timeZone
        components.year = 2026
        components.month = 6
        components.day = 14
        components.hour = hour
        components.minute = minute
        components.second = second
        return components.date!
    }

    private func entry(
        id: Int = 1,
        hour: Int = 9,
        bodyPart: String = "胸",
        exercise: String = "ベンチプレス",
        weight: Double = 100,
        reps: Int = 5
    ) -> SetEntry {
        SetEntry(
            id: id,
            date: date(hour: hour),
            bodyPart: bodyPart,
            exercise: exercise,
            weight: weight,
            reps: reps,
            note: nil,
            side: nil
        )
    }

    private func mockResponse() -> WorkoutAnalysisResponse {
        WorkoutAnalysisResponse(
            summary: "summary",
            advice: "advice",
            nextGoal: "next_goal"
        )
    }

    @Test func 記録ありでsuccessになり概要値が一致する() async {
        let builder = WorkoutAnalysisDataBuilder()
        let viewModel = WorkoutAnalysisViewModel(
            fetchEntries: { _ in
                [
                    entry(id: 1, hour: 9, weight: 100, reps: 5),
                    entry(id: 2, hour: 10, weight: 80, reps: 8)
                ]
            },
            builder: builder,
            requestAnalysis: { _ in mockResponse() },
            now: { date(hour: 20, minute: 30) },
            timeZone: { timeZone }
        )

        await viewModel.analyzeTodayWorkout()

        guard case .success(let result) = viewModel.state else {
            Issue.record("successになる必要があります")
            return
        }

        #expect(result.request.analysisDate == "2026-06-14")
        #expect(result.request.totalSets == 2)
        #expect(result.request.totalReps == 13)
        #expect(result.request.totalVolumeKg == 1_140)
        #expect(result.summary.totalSets == result.request.totalSets)
        #expect(result.summary.totalReps == result.request.totalReps)
        #expect(result.summary.totalVolumeKg == result.request.totalVolumeKg)
        #expect(result.summary.exerciseCount == result.request.exercises.count)
        #expect(result.jsonText.contains("\"totalSets\" : 2"))
        #expect(result.response == mockResponse())
    }

    @Test func 記録なしでemptyになる() async {
        let viewModel = WorkoutAnalysisViewModel(
            fetchEntries: { _ in [] },
            builder: WorkoutAnalysisDataBuilder(),
            requestAnalysis: { _ in mockResponse() },
            now: { date(hour: 20) },
            timeZone: { timeZone }
        )

        await viewModel.analyzeTodayWorkout()

        #expect(viewModel.state == .empty(.today))
    }

    @Test func JSON生成失敗でfailureになる() async {
        struct JSONStubError: Error {}

        let builder = WorkoutAnalysisDataBuilder()
        let viewModel = WorkoutAnalysisViewModel(
            fetchEntries: { _ in [entry()] },
            buildRequest: { entries, analysisDate, timeZone, generatedAt in
                builder.buildRequest(
                    entries: entries,
                    analysisDate: analysisDate,
                    timeZone: timeZone,
                    generatedAt: generatedAt
                )
            },
            encodeJSON: { _ in throw JSONStubError() },
            encodeJSONString: { _ in throw JSONStubError() },
            requestAnalysis: { _ in mockResponse() },
            now: { date(hour: 20) },
            timeZone: { timeZone }
        )

        await viewModel.analyzeTodayWorkout()

        guard case .failure(let message) = viewModel.state else {
            Issue.record("failureになる必要があります")
            return
        }

        #expect(message == "分析に失敗しました。Djangoサーバーが起動しているか確認してください。")
    }

    @Test func 連続実行しても最新の結果へ更新される() async {
        var callCount = 0
        let viewModel = WorkoutAnalysisViewModel(
            fetchEntries: { _ in
                callCount += 1
                if callCount == 1 {
                    return [entry(id: 1, weight: 60, reps: 10)]
                }
                return [
                    entry(id: 1, weight: 60, reps: 10),
                    entry(id: 2, weight: 70, reps: 8)
                ]
            },
            builder: WorkoutAnalysisDataBuilder(),
            requestAnalysis: { _ in mockResponse() },
            now: { date(hour: 20) },
            timeZone: { timeZone }
        )

        await viewModel.analyzeTodayWorkout()
        guard case .success(let firstResult) = viewModel.state else {
            Issue.record("1回目はsuccessになる必要があります")
            return
        }

        await viewModel.analyzeTodayWorkout()
        guard case .success(let secondResult) = viewModel.state else {
            Issue.record("2回目もsuccessになる必要があります")
            return
        }

        #expect(firstResult.request.totalSets == 1)
        #expect(secondResult.request.totalSets == 2)
        #expect(secondResult.request.totalVolumeKg == 1_160)
    }
}
