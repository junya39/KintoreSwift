import Foundation

struct APIConfig {
    // シミュレーター: localhostがMacを指すので127.0.0.1でよい
    // 実機: localhostはiPhone自身を指すため、同じWi-Fi上のMacのローカルIPを指定する
    //       （MacのIPが変わったら ipconfig getifaddr en0 で確認して更新すること）
    #if targetEnvironment(simulator)
    static let baseURL = "http://127.0.0.1:8000"
    #else
    static let baseURL = "http://192.168.151.207:8000"
    #endif
}
