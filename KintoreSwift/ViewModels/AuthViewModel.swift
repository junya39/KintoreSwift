// AuthViewModel.swift
// ログイン状態の管理。トークンはKeychainにのみ保存し、printやログには出さない。

import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: AuthUser?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let api: AuthAPIClient
    private let tokenStore: AuthTokenStoring

    init(
        api: AuthAPIClient = AuthAPIClient(),
        tokenStore: AuthTokenStoring = KeychainTokenStore()
    ) {
        self.api = api
        self.tokenStore = tokenStore
    }

    /// 起動時の復元: Keychainのトークンを /api/auth/me/ で検証する
    func restoreSession() async {
        guard let token = tokenStore.load() else {
            isAuthenticated = false
            currentUser = nil
            return
        }

        do {
            let user = try await api.me(token: token)
            currentUser = user
            isAuthenticated = true
        } catch {
            // トークン失効・削除済みなどはKeychainから消して未ログインに戻す。
            // 通信エラー（サーバー未起動等）ではトークンを消さず、次回起動時に再検証する。
            if case AuthAPIClient.APIError.server = error {
                tokenStore.delete()
            }
            isAuthenticated = false
            currentUser = nil
        }
    }

    func login(email: String, password: String) async -> Bool {
        await authenticate {
            try await self.api.login(email: email, password: password)
        }
    }

    func register(email: String, password: String, passwordConfirm: String) async -> Bool {
        await authenticate {
            try await self.api.register(
                email: email,
                password: password,
                passwordConfirm: passwordConfirm
            )
        }
    }

    /// パスワードリセットの確認コード送信を依頼する
    func requestPasswordReset(email: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await api.requestPasswordReset(email: email)
            return true
        } catch {
            errorMessage = Self.userMessage(for: error)
            return false
        }
    }

    /// 確認コードと新しいパスワードで再設定する。成功してもログインはさせず、
    /// 新パスワードでのログインをユーザー自身に行ってもらう
    func confirmPasswordReset(
        email: String,
        code: String,
        newPassword: String,
        newPasswordConfirm: String
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await api.confirmPasswordReset(
                email: email,
                code: code,
                newPassword: newPassword,
                newPasswordConfirm: newPasswordConfirm
            )
            return true
        } catch {
            errorMessage = Self.userMessage(for: error)
            return false
        }
    }

    /// 保存済みトークンがサーバーに拒否された（401）ときの強制ログアウト。
    /// サーバー呼び出しは行わず、ローカルの状態だけを未ログインへ戻す。
    func invalidateSession(message: String) {
        tokenStore.delete()
        isAuthenticated = false
        currentUser = nil
        errorMessage = message
    }

    func logout() async {
        isLoading = true
        defer { isLoading = false }

        // サーバー側のトークン失効はベストエフォート（失敗してもローカルは必ずログアウト）
        if let token = tokenStore.load() {
            try? await api.logout(token: token)
        }

        tokenStore.delete()
        isAuthenticated = false
        currentUser = nil
        errorMessage = nil
    }

    private func authenticate(_ operation: @escaping () async throws -> AuthResponse) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await operation()
            tokenStore.save(response.token)
            currentUser = response.user
            isAuthenticated = true
            return true
        } catch {
            errorMessage = Self.userMessage(for: error)
            return false
        }
    }

    private static func userMessage(for error: Error) -> String {
        // サーバーが返した日本語メッセージ（メール重複・パスワード強度など）を最優先
        if case AuthAPIClient.APIError.server(_, let message) = error {
            return message
        }
        // エラーJSONを持たない応答（Renderの502/503など）はステータスコードで案内を分ける
        if case AuthAPIClient.APIError.badStatusCode(let statusCode) = error {
            return APIErrorMessage.message(forStatusCode: statusCode)
        }
        // サーバー未到達（圏外・接続不可・タイムアウト）の切り分け
        if let urlError = error as? URLError {
            return APIErrorMessage.message(for: urlError)
        }
        return APIErrorMessage.generic
    }
}
