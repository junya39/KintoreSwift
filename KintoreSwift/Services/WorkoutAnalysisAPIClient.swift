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
        case invalidURL
        case invalidResponse
        case badStatusCode(Int, String)
        /// サーバーが返したユーザー向けエラー（error.code / error.message）
        case server(code: String, message: String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid workout analysis URL."
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

    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let tokenProvider: () -> String?

    init(
        baseURL: String = APIConfig.baseURL,
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
        guard let url = URL(string: "\(baseURL)/api/workout-analysis/analyze/") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 15

        // AI分析はログイン必須。Keychainのトークンを付与する（トークンはログに出さない）
        if let token = tokenProvider() {
            request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            #if DEBUG
            print("WorkoutAnalysisAPIClient network error: \(error)")
            #endif
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
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
        guard let url = URL(string: "\(baseURL)/api/workout-analysis/usage/") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        if let token = tokenProvider() {
            request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let payload = try? decoder.decode(ServerErrorPayload.self, from: data) {
                throw APIError.server(code: payload.error.code, message: payload.error.message)
            }
            throw APIError.badStatusCode(httpResponse.statusCode, "")
        }

        return try decoder.decode(AnalysisUsageInfo.self, from: data)
    }
}
