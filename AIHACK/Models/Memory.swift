import Foundation

/// 記憶されたトピック1件分。ディスクへ永続化される（表情・声の観測データとは異なり、
/// アプリを終了しても消えない）。元の発言全文は保持せず、簡潔な要約のみを保持する。
nonisolated struct MemoryTopic: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var topic: String
    let firstMentionedAt: Date
    var lastMentionedAt: Date
    var mentionCount: Int
    /// 関連する発言の簡潔な要約（元の発言そのものは保持しない）
    var relatedSummaries: [String]

    init(
        id: UUID = UUID(),
        topic: String,
        firstMentionedAt: Date,
        lastMentionedAt: Date,
        mentionCount: Int = 1,
        relatedSummaries: [String] = []
    ) {
        self.id = id
        self.topic = topic
        self.firstMentionedAt = firstMentionedAt
        self.lastMentionedAt = lastMentionedAt
        self.mentionCount = mentionCount
        self.relatedSummaries = relatedSummaries
    }
}

/// LLMが1ターン分の会話から抽出した、記憶候補1件分。
nonisolated struct MemoryExtractionCandidate: Codable, Sendable {
    let topic: String
    let summary: String
}

/// 記憶抽出1回分のLLM出力全体。記憶に値する内容がなければcandidatesは空になる。
nonisolated struct MemoryExtractionResult: Codable, Sendable {
    let candidates: [MemoryExtractionCandidate]
}
