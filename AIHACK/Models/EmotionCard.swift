import Foundation

/// 感情当てゲームで提示する感情・状況カード。
/// idは判定用LLMとのやり取り、および配色マッピング(GamePalette)の両方で使う安定したキー。
nonisolated struct EmotionCard: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let systemImage: String
}

extension EmotionCard {
    static let all: [EmotionCard] = [
        EmotionCard(id: "joy", label: "喜び", systemImage: "face.smiling.fill"),
        EmotionCard(id: "anger", label: "怒り", systemImage: "flame.fill"),
        EmotionCard(id: "sadness", label: "悲しみ", systemImage: "cloud.rain.fill"),
        EmotionCard(id: "surprise", label: "驚き", systemImage: "bolt.fill"),
        EmotionCard(id: "embarrassment", label: "照れ", systemImage: "heart.circle.fill"),
        EmotionCard(id: "doubt", label: "疑い", systemImage: "questionmark.circle.fill"),
        EmotionCard(id: "despair", label: "絶望", systemImage: "tornado"),
        EmotionCard(id: "excitement", label: "興奮", systemImage: "hands.clap.fill")
    ]
}
