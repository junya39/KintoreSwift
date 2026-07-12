import Foundation

/// APIベースURLの一元管理。
///
/// 実機はビルド構成にかかわらず常にRender本番（HTTPS）へ接続する。
/// MacのDjango起動・同一Wi-Fi接続・MacのローカルIP設定は一切不要。
/// ローカルDjangoを使うのはシミュレーターのDEBUGビルドのみ。
struct APIConfig {
    #if DEBUG && targetEnvironment(simulator)
    // 開発用: シミュレーターのlocalhostはMacを指す（runserver 127.0.0.1:8000 でOK）
    private static let baseURLString = "http://127.0.0.1:8000"
    #else
    // 本番: Render上のDjangoバックエンド（Neon PostgreSQL / OpenAI接続）
    private static let baseURLString = "https://kintore-ai-backend.onrender.com"
    #endif

    static let baseURL: URL = {
        guard let url = URL(string: baseURLString) else {
            fatalError("Invalid API base URL: \(baseURLString)")
        }
        return url
    }()
}
