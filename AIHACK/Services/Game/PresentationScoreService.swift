import Foundation
import os

nonisolated protocol PresentationScoreServiceProtocol: Sendable {
    func score(
        prompt: String,
        transcript: String,
        voiceDescription: String,
        faceDescription: String
    ) async throws -> PresentationScoreResult
}

/// OrcaRouter経由で、30秒間の観測記述とお題からプレゼンを採点させる。
/// ChatViewModel・SystemPrompt（会話用）・EmotionGuessService（はぁって言うゲーム用）とは
/// 完全に独立しており、このゲーム専用のプロンプト・モデルのみを使う。
nonisolated struct PresentationScoreService: PresentationScoreServiceProtocol {
    private static let logger = Logger(subsystem: "com.tatsukikitagawa.AIHACK", category: "Game")

    private let llmService: LLMServiceProtocol

    init(llmService: LLMServiceProtocol) {
        self.llmService = llmService
    }

    func score(
        prompt: String,
        transcript: String,
        voiceDescription: String,
        faceDescription: String
    ) async throws -> PresentationScoreResult {
        let userPrompt = PresentationSystemPrompt.userPrompt(
            prompt: prompt,
            transcript: transcript,
            voiceDescription: voiceDescription,
            faceDescription: faceDescription
        )

        Self.logger.info("プレゼン採点リクエスト送信: prompt=\(prompt, privacy: .public) model=\(ModelCatalog.presentationScoring, privacy: .public)")

        let response = try await llmService.completeStructured(
            for: [ChatMessage(role: .user, content: userPrompt)],
            model: ModelCatalog.presentationScoring,
            systemPrompt: PresentationSystemPrompt.scoring,
            as: PresentationScoreResponse.self
        )

        return PresentationScoreResult(
            content: PresentationAxisScore(score: Self.clamp(response.content.score), comment: response.content.comment),
            voice: PresentationAxisScore(score: Self.clamp(response.voice.score), comment: response.voice.comment),
            expression: PresentationAxisScore(score: Self.clamp(response.expression.score), comment: response.expression.comment)
        )
    }

    nonisolated private static func clamp(_ score: Int) -> Int {
        min(max(score, 0), 100)
    }
}

nonisolated private struct PresentationScoreResponse: Decodable, Sendable {
    struct Axis: Decodable, Sendable {
        let score: Int
        let comment: String
    }

    let content: Axis
    let voice: Axis
    let expression: Axis
}
