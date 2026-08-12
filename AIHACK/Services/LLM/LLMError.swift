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
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "APIキーが設定されていません。Configuration/Secrets.swift を確認してください。"
        case .invalidURL:
            return "リクエストの生成に失敗しました。"
        case .network(let message):
            return "通信エラーが発生しました: \(message)"
        case .decoding(let message):
            return "応答の解析に失敗しました: \(message)"
        case .apiError(let statusCode, let message):
            return "APIエラー (\(statusCode)): \(message)"
        case .unauthorized:
            return "認証に失敗しました。APIキーを確認してください。"
        case .rateLimited:
            return "現在混雑しています。しばらくしてからもう一度お試しください。"
        }
    }
}
