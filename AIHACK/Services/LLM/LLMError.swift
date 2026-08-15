import Foundation

nonisolated enum LLMError: Error {
    case missingAPIKey
    case invalidURL
    case network(String)
    case decoding(String)
    case apiError(statusCode: Int, message: String)
    case unauthorized
    /// 429（レート制限）が発生し、規定回数のリトライを尽くしても解消しなかった
    case rateLimited
}

extension LLMError: LocalizedError {
    /// ユーザーに表示する文言。サーバーからの生のエラーメッセージやURL・システムエラー文字列など、
    /// 内部実装の詳細を一切含めない（それらは呼び出し側で既にos.Loggerへ記録済み）。
    /// 万一サーバー側のエラーメッセージにHTMLやプロンプト的な文字列が含まれていても、
    /// そのままUIへ表示されることを防ぐ狙いもある。
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "APIキーが設定されていません。アプリの設定を確認してください。"
        case .invalidURL:
            return "リクエストの生成に失敗しました。"
        case .network:
            return "通信エラーが発生しました。通信環境を確認し、もう一度お試しください。"
        case .decoding:
            return "応答の解析に失敗しました。もう一度お試しください。"
        case .apiError(let statusCode, _):
            return Self.safeAPIErrorMessage(statusCode: statusCode)
        case .unauthorized:
            return "認証に失敗しました。しばらくしてからもう一度お試しください。"
        case .rateLimited:
            return "現在混雑しています。しばらくしてからもう一度お試しください。"
        }
    }

    /// ログにのみ残す診断用の詳細情報。UIには絶対に表示しないこと。
    var diagnosticDescription: String {
        switch self {
        case .missingAPIKey, .invalidURL, .unauthorized, .rateLimited:
            return errorDescription ?? ""
        case .network(let message), .decoding(let message):
            return message
        case .apiError(let statusCode, let message):
            return "status=\(statusCode) message=\(message)"
        }
    }

    private static func safeAPIErrorMessage(statusCode: Int) -> String {
        switch statusCode {
        case 400..<500:
            return "リクエストを処理できませんでした。しばらくしてからもう一度お試しください。"
        case 500..<600:
            return "サーバー側で問題が発生しました。しばらくしてからもう一度お試しください。"
        default:
            return "予期しないエラーが発生しました。"
        }
    }
}
