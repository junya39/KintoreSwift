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

struct WorkoutAnalysisAPIClient {
    enum APIError: Error, LocalizedError {
        case invalidURL
        case invalidResponse
        case badStatusCode(Int, String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid workout analysis URL."
            case .invalidResponse:
                return "Workout analysis response was not HTTPURLResponse."
            case .badStatusCode(let statusCode, let body):
                return "Workout analysis API returned status \(statusCode): \(body)"
            }
        }
    }

    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        baseURL: String = APIConfig.baseURL,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
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
}
