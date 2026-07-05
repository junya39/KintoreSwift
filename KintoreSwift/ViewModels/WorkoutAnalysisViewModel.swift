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
        let response: WorkoutAnalysisResponse

        var summary: Summary {
            Summary(request: request)
        }

        static func == (lhs: AnalysisResult, rhs: AnalysisResult) -> Bool {
            lhs.request == rhs.request
                && lhs.jsonText == rhs.jsonText
                && lhs.response == rhs.response
        }
    }

    struct EmptyResult: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String

        static let today = EmptyResult(
            title: "今日の筋トレ記録がありません",
            message: "今日の筋トレ記録がありません"
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
    private let encodeJSON: (WorkoutAnalysisRequest) throws -> Data
    private let encodeJSONString: (WorkoutAnalysisRequest) throws -> String
    private let requestAnalysis: (Data) async throws -> WorkoutAnalysisResponse
    private let now: () -> Date
    private let timeZone: () -> TimeZone

    @Published private(set) var state: AnalysisState = .idle

    /// AI分析APIが401を返した（保存済みトークンが無効）。Home側でログイン誘導に使う
    @Published var sessionExpired = false

    var isLoading: Bool {
        state == .loading
    }

    init(
        fetchEntries: @escaping (Date) throws -> [SetEntry] = { date in
            DatabaseManager.shared.fetchSets(by: date)
        },
        builder: WorkoutAnalysisDataBuilder = WorkoutAnalysisDataBuilder(),
        apiClient: WorkoutAnalysisAPIClient = WorkoutAnalysisAPIClient(),
        requestAnalysis: ((Data) async throws -> WorkoutAnalysisResponse)? = nil,
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
        self.encodeJSON = { request in
            try builder.encodeJSON(request, style: .compact)
        }
        self.encodeJSONString = { request in
            try builder.encodeJSONString(request, style: .debugPrettyPrinted)
        }
        self.requestAnalysis = requestAnalysis ?? { body in
            try await apiClient.analyze(body: body)
        }
        self.now = now
        self.timeZone = timeZone
    }

    init(
        fetchEntries: @escaping (Date) throws -> [SetEntry],
        buildRequest: @escaping ([SetEntry], Date, TimeZone, Date) -> WorkoutAnalysisRequest,
        encodeJSON: @escaping (WorkoutAnalysisRequest) throws -> Data,
        encodeJSONString: @escaping (WorkoutAnalysisRequest) throws -> String,
        requestAnalysis: @escaping (Data) async throws -> WorkoutAnalysisResponse,
        now: @escaping () -> Date = Date.init,
        timeZone: @escaping () -> TimeZone = { .current }
    ) {
        self.fetchEntries = fetchEntries
        self.buildRequest = buildRequest
        self.encodeJSON = encodeJSON
        self.encodeJSONString = encodeJSONString
        self.requestAnalysis = requestAnalysis
        self.now = now
        self.timeZone = timeZone
    }

    func analyzeTodayWorkout() async {
        await analyzeWorkout(for: now())
    }

    func analyzeWorkout(for date: Date) async {
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
            let body = try encodeJSON(request)
            let jsonText = try encodeJSONString(request)
            let response = try await requestAnalysis(body)
            state = .success(AnalysisResult(request: request, jsonText: jsonText, response: response))
        } catch {
            #if DEBUG
            print("WorkoutAnalysisViewModel error: \(error)")
            #endif
            if case WorkoutAnalysisAPIClient.APIError.server(let code, let message) = error {
                if code == "UNAUTHORIZED" {
                    // 保存済みトークンが無効。Home側でログアウト処理とログイン誘導を行う
                    state = .failure("ログインの有効期限が切れました。もう一度ログインしてください。")
                    sessionExpired = true
                } else if code == "monthly_limit_exceeded" {
                    // 開発者向け文言ではなく、ユーザー向けの案内を表示する
                    state = .failure("今月の無料AI分析回数を使い切りました。\nプレミアム機能は今後追加予定です。")
                } else {
                    state = .failure(message)
                }
            } else {
                state = .failure("分析に失敗しました。通信環境を確認して、時間をおいて再度お試しください。")
            }
        }
    }

    func reset() {
        state = .idle
    }
}
