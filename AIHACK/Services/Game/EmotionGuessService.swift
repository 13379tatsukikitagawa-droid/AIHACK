import Foundation
import os

nonisolated protocol EmotionGuessServiceProtocol: Sendable {
    func guess(
        prompt: String,
        cards: [EmotionCard],
        faceDescription: String?,
        voiceDescription: String?
    ) async throws -> EmotionGuessResult
}

/// OrcaRouter経由で、演技中の観測記述とお題からプレイヤーが演じていた感情を推測させる。
/// ChatViewModel・SystemPrompt（会話用）とは完全に独立しており、ゲーム専用のプロンプト・モデルのみを使う。
/// llmServiceはGameViewModel側でOrcaRouterServiceの新規インスタンスとして注入され、
/// Mirror（ChatViewModel）が使う通信状態とは共有しない。
nonisolated struct EmotionGuessService: EmotionGuessServiceProtocol {
    private static let logger = Logger(subsystem: "com.tatsukikitagawa.AIHACK", category: "Game")

    private let llmService: LLMServiceProtocol

    init(llmService: LLMServiceProtocol) {
        self.llmService = llmService
    }

    func guess(
        prompt: String,
        cards: [EmotionCard],
        faceDescription: String?,
        voiceDescription: String?
    ) async throws -> EmotionGuessResult {
        let systemPrompt = GameSystemPrompt.judging(cards: cards)
        let userPrompt = GameSystemPrompt.userPrompt(prompt: prompt, faceDescription: faceDescription, voiceDescription: voiceDescription)

        Self.logger.info("感情推測リクエスト送信: prompt=\(prompt, privacy: .public) model=\(ModelCatalog.emotionGuessing, privacy: .public)")

        let response = try await llmService.completeStructured(
            for: [ChatMessage(role: .user, content: userPrompt)],
            model: ModelCatalog.emotionGuessing,
            systemPrompt: systemPrompt,
            as: EmotionGuessResponse.self
        )

        guard let card = cards.first(where: { $0.id == response.cardID }) else {
            Self.logger.error("未知のcardIDを受信: \(response.cardID, privacy: .public)")
            throw EmotionGuessError.unknownCardID
        }

        return EmotionGuessResult(guessedCard: card, reasoning: response.reasoning)
    }
}

nonisolated private struct EmotionGuessResponse: Decodable, Sendable {
    let cardID: String
    let reasoning: String
}

nonisolated enum EmotionGuessError: Error, LocalizedError {
    case unknownCardID

    var errorDescription: String? {
        "判定結果の解析に失敗しました。"
    }
}
