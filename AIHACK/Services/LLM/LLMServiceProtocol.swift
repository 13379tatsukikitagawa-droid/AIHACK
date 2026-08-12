import Foundation

/// 429（レート制限）発生時の自動リトライ状況をUIへ伝えるための通知。
nonisolated struct LLMRetryEvent: Sendable {
    /// 何回目のリトライか（1始まり）
    let attempt: Int
    /// リトライの最大回数
    let maxAttempts: Int
    /// このリトライまでの待機時間（秒）
    let delay: TimeInterval
    /// 代替モデルへ切り替えた上でのリトライかどうか
    let usingFallbackModel: Bool
}

nonisolated protocol LLMServiceProtocol: Sendable {
    /// 会話履歴を送信し、差分テキストを逐次流すストリームを返す。
    func streamResponse(for messages: [ChatMessage], model: String, systemPrompt: String?) -> AsyncThrowingStream<String, Error>

    /// 会話履歴を送信し、非ストリーミングでJSON形式の応答を取得してデコードする。
    func completeStructured<T: Decodable & Sendable>(
        for messages: [ChatMessage],
        model: String,
        systemPrompt: String?,
        as type: T.Type
    ) async throws -> T

    /// 429（レート制限）による自動リトライが発生するたびに通知するストリーム。
    func retryEvents() -> AsyncStream<LLMRetryEvent>
}
