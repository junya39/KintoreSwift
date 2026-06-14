import Foundation
import Combine

@MainActor
final class WorkoutAnalysisViewModel: ObservableObject {
    enum AnalysisState: Equatable {
        case idle
        case loading
        case success(AnalysisResult)
        case empty(EmptyResult)
        case failure(String)
    }

    struct AnalysisResult: Identifiable, Equatable {
        let id = UUID()
        let request: WorkoutAnalysisRequest
        let jsonText: String

        var summary: Summary {
            Summary(request: request)
        }

        static func == (lhs: AnalysisResult, rhs: AnalysisResult) -> Bool {
            lhs.request == rhs.request && lhs.jsonText == rhs.jsonText
        }
    }

    struct EmptyResult: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String

        static let today = EmptyResult(
            title: "今日の記録はありません",
            message: "筋トレを記録すると、ここから分析用データを確認できます。"
        )

        static func == (lhs: EmptyResult, rhs: EmptyResult) -> Bool {
            lhs.title == rhs.title && lhs.message == rhs.message
        }
    }

    struct Summary: Equatable {
        let analysisDate: String
        let totalSets: Int
        let totalReps: Int
        let totalVolumeKg: Double
        let exerciseCount: Int

        init(request: WorkoutAnalysisRequest) {
            analysisDate = request.analysisDate
            totalSets = request.totalSets
            totalReps = request.totalReps
            totalVolumeKg = request.totalVolumeKg
            exerciseCount = request.exercises.count
        }
    }

    private let fetchEntries: (Date) throws -> [SetEntry]
    private let buildRequest: ([SetEntry], Date, TimeZone, Date) -> WorkoutAnalysisRequest
    private let encodeJSONString: (WorkoutAnalysisRequest) throws -> String
    private let now: () -> Date
    private let timeZone: () -> TimeZone

    @Published private(set) var state: AnalysisState = .idle

    var isLoading: Bool {
        state == .loading
    }

    init(
        fetchEntries: @escaping (Date) throws -> [SetEntry] = { date in
            DatabaseManager.shared.fetchSets(by: date)
        },
        builder: WorkoutAnalysisDataBuilder = WorkoutAnalysisDataBuilder(),
        now: @escaping () -> Date = Date.init,
        timeZone: @escaping () -> TimeZone = { .current }
    ) {
        self.fetchEntries = fetchEntries
        self.buildRequest = { entries, analysisDate, timeZone, generatedAt in
            builder.buildRequest(
                entries: entries,
                analysisDate: analysisDate,
                timeZone: timeZone,
                generatedAt: generatedAt
            )
        }
        self.encodeJSONString = { request in
            try builder.encodeJSONString(request, style: .debugPrettyPrinted)
        }
        self.now = now
        self.timeZone = timeZone
    }

    init(
        fetchEntries: @escaping (Date) throws -> [SetEntry],
        buildRequest: @escaping ([SetEntry], Date, TimeZone, Date) -> WorkoutAnalysisRequest,
        encodeJSONString: @escaping (WorkoutAnalysisRequest) throws -> String,
        now: @escaping () -> Date = Date.init,
        timeZone: @escaping () -> TimeZone = { .current }
    ) {
        self.fetchEntries = fetchEntries
        self.buildRequest = buildRequest
        self.encodeJSONString = encodeJSONString
        self.now = now
        self.timeZone = timeZone
    }

    func generateTodayAnalysisData() {
        generateAnalysisData(for: now())
    }

    func generateAnalysisData(for date: Date) {
        state = .loading

        do {
            let entries = try fetchEntries(date)
            guard entries.isEmpty == false else {
                state = .empty(.today)
                return
            }

            let currentTimeZone = timeZone()
            let generatedAt = now()
            let request = buildRequest(entries, date, currentTimeZone, generatedAt)
            let jsonText = try encodeJSONString(request)
            state = .success(AnalysisResult(request: request, jsonText: jsonText))
        } catch {
            #if DEBUG
            print("WorkoutAnalysisViewModel error: \(error)")
            #endif
            state = .failure("分析用データを作成できませんでした。時間をおいてもう一度お試しください。")
        }
    }

    func reset() {
        state = .idle
    }
}
