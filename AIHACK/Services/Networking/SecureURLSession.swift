import Foundation

/// LLM/TTSバックエンドとの通信に使う、設定を明示的に固定したURLSession。
///
/// - App Transport Security: Info.plistに `NSAppTransportSecurity` の例外設定を一切
///   追加していないため、OS層でHTTP（非TLS）通信・既知の弱い暗号スイートは自動的に拒否される。
///   ここではさらに `tlsMinimumSupportedProtocolVersion` を明示し、将来設定が緩んでも
///   TLS1.2未満へは決して落ちないようにする。
/// - タイムアウト: 接続が無応答のままハングし続けないよう明示的に上限を設ける。
///   ストリーミング応答（SSE）は長時間かかりうるため、resource側のタイムアウトは
///   request側より大きく取っている。
/// - キャッシュ・Cookie: 会話内容を含みうるリクエスト/レスポンスをディスクに残さないよう
///   `.ephemeral` 構成を使い、URLキャッシュ・Cookie保存を無効化する。
enum SecureURLSession {
    static let shared: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        configuration.waitsForConnectivity = false
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()
}
