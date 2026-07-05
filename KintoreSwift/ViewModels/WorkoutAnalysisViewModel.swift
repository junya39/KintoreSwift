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
    private let fetchUsage: (() async throws -> AnalysisUsageInfo)?
    private let now: () -> Date
    private let timeZone: () -> TimeZone

    @Published private(set) var state: AnalysisState = .idle

    /// 今月のAI分析使用状況（残り回数表示用）。未ログイン時や取得失敗時はnil
    @Published private(set) var usage: AnalysisUsageInfo?

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
        self.fetchUsage = { try await apiClient.fetchUsage() }
        self.now = now
        self.timeZone = timeZone
    }

    init(
        fetchEntries: @escaping (Date) throws -> [SetEntry],
        buildRequest: @escaping ([SetEntry], Date, TimeZone, Date) -> WorkoutAnalysisRequest,
        encodeJSON: @escaping (WorkoutAnalysisRequest) throws -> Data,
        encodeJSONString: @escaping (WorkoutAnalysisRequest) throws -> String,
        requestAnalysis: @escaping (Data) async throws -> WorkoutAnalysisResponse,
        fetchUsage: (() async throws -> AnalysisUsageInfo)? = nil,
        now: @escaping () -> Date = Date.init,
        timeZone: @escaping () -> TimeZone = { .current }
    ) {
        self.fetchEntries = fetchEntries
        self.buildRequest = buildRequest
        self.encodeJSON = encodeJSON
        self.encodeJSONString = encodeJSONString
        self.requestAnalysis = requestAnalysis
        self.fetchUsage = fetchUsage
        self.now = now
        self.timeZone = timeZone
    }

    /// 残り回数表示の更新。未ログインや通信失敗時は現状維持（トークンはログに出さない）
    func refreshUsage() async {
        guard let fetchUsage else { return }
        if let latest = try? await fetchUsage() {
            usage = latest
        }
    }

    /// ログアウト時などに残り回数表示を消す
    func clearUsage() {
        usage = nil
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
            // 成功時は回数を消費しているので残り回数を更新する
            await refreshUsage()
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
                    // 403時は残り0として表示を更新（その後サーバー値で上書き）
                    if let current = usage {
                        usage = AnalysisUsageInfo(
                            limit: current.limit,
                            used: current.limit,
                            remaining: 0,
                            year: current.year,
                            month: current.month
                        )
                    }
                    await refreshUsage()
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
