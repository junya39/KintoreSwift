import Foundation

struct WorkoutAnalysisResponse: Codable, Equatable, Sendable {
    let summary: String
    let advice: String
    let nextGoal: String

    enum CodingKeys: String, CodingKey {
        case summary
        case advice
        case nextGoal = "next_goal"
    }
}

/// 今月のAI分析使用状況（無料回数制限）
struct AnalysisUsageInfo: Codable, Equatable, Sendable {
    let limit: Int
    let used: Int
    let remaining: Int
    let year: Int
    let month: Int
}

struct WorkoutAnalysisAPIClient {
    enum APIError: Error, LocalizedError {
        case invalidResponse
        case badStatusCode(Int, String)
        /// サーバーが返したユーザー向けエラー（error.code / error.message）
        case server(code: String, message: String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Workout analysis response was not HTTPURLResponse."
            case .badStatusCode(let statusCode, let body):
                return "Workout analysis API returned status \(statusCode): \(body)"
            case .server(let code, let message):
                return "Workout analysis API error \(code): \(message)"
            }
        }
    }

    private struct ServerErrorPayload: Decodable {
        struct Detail: Decodable {
            let code: String
            let message: String
        }

        let error: Detail
    }

    /// 回数制限などのフラット形式エラー（{"error": "monthly_limit_exceeded", "message": ...}）
    private struct FlatServerErrorPayload: Decodable {
        let error: String
        let message: String?
    }

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let tokenProvider: () -> String?

    init(
        baseURL: URL = APIConfig.baseURL,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        tokenProvider: @escaping () -> String? = { KeychainTokenStore().load() }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.tokenProvider = tokenProvider
    }

    func analyze(body: Data) async throws -> WorkoutAnalysisResponse {
        let url = baseURL.appendingPathComponent("/api/workout-analysis/analyze/")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        // AI分析はサーバー側でOpenAI呼び出しを待つため、認証系より長めに取る
        request.timeoutInterval = 30

        // AI分析はログイン必須。Keychainのトークンを付与する（トークンはログに出さない）
        if let token = tokenProvider() {
            request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            APIDebugLogger.logTransportError(label: "AI分析API", method: "POST", url: url, error: error)
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            APIDebugLogger.logHTTPError(
                label: "AI分析API",
                method: "POST",
                url: url,
                statusCode: httpResponse.statusCode,
                responseBody: data
            )
            // サーバーのエラーJSONに日本語メッセージが入っていればそれを優先する
            if let payload = try? decoder.decode(ServerErrorPayload.self, from: data) {
                throw APIError.server(code: payload.error.code, message: payload.error.message)
            }
            if let payload = try? decoder.decode(FlatServerErrorPayload.self, from: data) {
                throw APIError.server(code: payload.error, message: payload.message ?? "")
            }
            let bodyText = String(decoding: data, as: UTF8.self)
            throw APIError.badStatusCode(httpResponse.statusCode, bodyText)
        }

        do {
            return try decoder.decode(WorkoutAnalysisResponse.self, from: data)
        } catch {
            #if DEBUG
            let bodyText = String(decoding: data, as: UTF8.self)
            print("WorkoutAnalysisAPIClient decode error: \(error), body: \(bodyText)")
            #endif
            throw error
        }
    }

    /// 今月のAI分析使用状況を取得する（要ログイン）
    func fetchUsage() async throws -> AnalysisUsageInfo {
        let url = baseURL.appendingPathComponent("/api/workout-analysis/usage/")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        if let token = tokenProvider() {
            request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            APIDebugLogger.logTransportError(label: "AI分析使用状況API", method: "GET", url: url, error: error)
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            APIDebugLogger.logHTTPError(
                label: "AI分析使用状況API",
                method: "GET",
                url: url,
                statusCode: httpResponse.statusCode,
                responseBody: data
            )
            if let payload = try? decoder.decode(ServerErrorPayload.self, from: data) {
                throw APIError.server(code: payload.error.code, message: payload.error.message)
            }
            throw APIError.badStatusCode(httpResponse.statusCode, "")
        }

        return try decoder.decode(AnalysisUsageInfo.self, from: data)
    }
}
