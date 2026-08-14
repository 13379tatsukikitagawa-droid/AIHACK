import Foundation

/// 感情当てゲーム1ラウンド分の判定結果。LLMが選んだカードと、その根拠の自然文をまとめて保持する。
nonisolated struct EmotionGuessResult: Sendable, Equatable {
    let guessedCard: EmotionCard
    let reasoning: String
}
