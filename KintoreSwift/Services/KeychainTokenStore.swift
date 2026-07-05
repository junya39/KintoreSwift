// KeychainTokenStore.swift
// 認証トークンのKeychain保存（UserDefaultsは使わない）
// 保存するのはauthTokenのみ。OpenAI APIキーやDB接続情報は絶対に保存しない。

import Foundation
import Security

protocol AuthTokenStoring {
    func save(_ token: String)
    func load() -> String?
    func delete()
}

struct KeychainTokenStore: AuthTokenStoring {
    private let service = "com.junya.KintoreSwift"
    private let account = "authToken"

    func save(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }

        // 同一キーの既存項目を消してから追加する（更新を単純化）
        delete()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            // 初回ロック解除後は再起動をまたいでも読める（バックグラウンド動作は不要）
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
