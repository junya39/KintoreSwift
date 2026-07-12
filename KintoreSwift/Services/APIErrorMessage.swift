// APIErrorMessage.swift
// 通信エラーをユーザー向けの日本語メッセージへ変換する共通ヘルパー。
// 技術的な詳細はDEBUGログ側（APIDebugLogger）に出し、画面には平易な文言だけを表示する。

import Foundation

enum APIErrorMessage {
    /// 原因を特定できなかったときの汎用フォールバック
    static let generic = "通信に失敗しました。通信環境を確認して、時間をおいて再度お試しください。"

    /// URLSessionレベルの失敗（サーバー未到達）をユーザー向け文言にする
    static func message(for urlError: URLError) -> String {
        switch urlError.code {
        case .notConnectedToInternet, .dataNotAllowed:
            return "インターネット接続を確認してください。"
        case .timedOut:
            return "サーバーの応答に時間がかかっています。しばらくしてからもう一度お試しください。"
        case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
             .networkConnectionLost, .secureConnectionFailed:
            return "サーバーに接続できませんでした。しばらくしてからもう一度お試しください。"
        default:
            return generic
        }
    }

    /// HTTPステータスコード別のユーザー向け文言。
    /// サーバーが個別のエラーメッセージ（error.message）を返した場合はそちらを優先すること。
    static func message(forStatusCode statusCode: Int) -> String {
        switch statusCode {
        case 400:
            return "入力内容をご確認ください。"
        case 401:
            return "ログインの有効期限が切れています。もう一度ログインしてください。"
        case 403:
            return "この操作は許可されていません。"
        case 404:
            return "接続先が見つかりませんでした。アプリを最新版へ更新してお試しください。"
        case 429:
            return "アクセスが集中しています。しばらくしてからもう一度お試しください。"
        case 500, 502, 503:
            return "サーバーで問題が発生しました。しばらくしてからもう一度お試しください。"
        default:
            return generic
        }
    }
}

/// DEBUGビルド限定の通信ログ。原因切り分け用にURL・メソッド・ステータス・本文を出す。
/// Authorizationトークン・パスワード等の機密はここへ渡さないこと（リクエスト本文は出さない）。
enum APIDebugLogger {
    static func logHTTPError(label: String, method: String, url: URL, statusCode: Int, responseBody: Data) {
        #if DEBUG
        let bodyText = String(decoding: responseBody, as: UTF8.self)
        print("❌ \(label) エラー応答: \(method) \(url.absoluteString) status=\(statusCode) body=\(bodyText)")
        #endif
    }

    static func logTransportError(label: String, method: String, url: URL, error: Error) {
        #if DEBUG
        print("❌ \(label) 通信失敗: \(method) \(url.absoluteString) error=\(error)")
        #endif
    }
}
