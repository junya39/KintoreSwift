// AuthAPIClient.swift
// kintore-ai-backend の認証API（登録・ログイン・me・ログアウト）クライアント

import Foundation

struct AuthUser: Codable, Equatable, Sendable {
    let id: Int
    let email: String
}

struct AuthResponse: Codable, Equatable, Sendable {
    let user: AuthUser
    let token: String
}

struct AuthAPIClient {
    enum APIError: Error, LocalizedError {
        case invalidURL
        case invalidResponse
        case badStatusCode(Int)
        /// サーバーが返したユーザー向けエラー（error.code / error.message）
        case server(code: String, message: String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid auth URL."
            case .invalidResponse:
                return "Auth response was not HTTPURLResponse."
            case .badStatusCode(let statusCode):
                return "Auth API returned status \(statusCode)."
            case .server(let code, let message):
                return "Auth API error \(code): \(message)"
            }
        }
    }

    private struct ServerErrorPayload: Decodable {
        struct Detail: Decodable {
            let code: String
            let message: String
            let details: [String: [String]]?
        }

        let error: Detail

        /// 項目別エラー（メール重複・パスワード強度不足など）があればそれを優先して表示する
        var displayMessage: String {
            for field in ["email", "password", "password_confirm"] {
                if let first = error.details?[field]?.first {
                    return first
                }
            }
            return error.message
        }
    }

    private let baseURL: String
    private let session: URLSession

    init(baseURL: String = APIConfig.baseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func register(email: String, password: String, passwordConfirm: String) async throws -> AuthResponse {
        try await request(
            path: "/api/auth/register/",
            method: "POST",
            body: [
                "email": email,
                "password": password,
                "password_confirm": passwordConfirm,
            ],
            decode: AuthResponse.self
        )
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        try await request(
            path: "/api/auth/login/",
            method: "POST",
            body: ["email": email, "password": password],
            decode: AuthResponse.self
        )
    }

    func me(token: String) async throws -> AuthUser {
        try await request(
            path: "/api/auth/me/",
            method: "GET",
            token: token,
            decode: AuthUser.self
        )
    }

    func logout(token: String) async throws {
        _ = try await request(
            path: "/api/auth/logout/",
            method: "POST",
            token: token,
            decode: EmptyResponse.self
        )
    }

    private struct EmptyResponse: Decodable {}

    private func request<T: Decodable>(
        path: String,
        method: String,
        body: [String: String]? = nil,
        token: String? = nil,
        decode: T.Type
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        if let token {
            request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            // 接続不可・タイムアウト等の切り分け用。URLとエラー種別のみ（認証情報は出さない）
            #if DEBUG
            print("❌ Auth API 通信失敗: \(method) \(url.absoluteString) error=\(error.localizedDescription)")
            #endif
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            #if DEBUG
            print("❌ Auth API エラー応答: \(method) \(url.absoluteString) status=\(httpResponse.statusCode)")
            #endif
            // サーバーの日本語エラーメッセージを優先。トークンや内部情報はログに出さない
            if let payload = try? JSONDecoder().decode(ServerErrorPayload.self, from: data) {
                throw APIError.server(code: payload.error.code, message: payload.displayMessage)
            }
            throw APIError.badStatusCode(httpResponse.statusCode)
        }

        if data.isEmpty, let empty = EmptyResponse() as? T {
            return empty
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
