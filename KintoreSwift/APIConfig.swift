import Foundation

struct APIConfig {
    #if DEBUG
    // 開発中はMac上のDjangoサーバーを使う
    #if targetEnvironment(simulator)
    // シミュレーター: localhostがMacを指すので127.0.0.1でよい
    static let baseURL = "http://127.0.0.1:8000"
    #else
    // 実機: localhostはiPhone自身を指すため、同じWi-Fi上のMacのローカルIPを指定する
    // - MacのIPが変わったら ipconfig getifaddr en0 で確認して更新すること
    // - Mac側は `runserver 0.0.0.0:8000` で起動しないとLANから届かない（127.0.0.1バインドはNG）
    // - バックエンドの .env DJANGO_ALLOWED_HOSTS にこのIPを含めること
    static let baseURL = "http://192.168.151.207:8000"
    #endif
    #else
    // 本番: Render上のDjangoバックエンド
    static let baseURL = "https://kintore-ai-backend.onrender.com"
    #endif
}
