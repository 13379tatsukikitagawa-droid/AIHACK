import Foundation

/// 記憶されたトピック一覧を、LLMに渡すための短い参考情報テキストに変換する。
/// トピック名のみを渡し、要約や生の発言は渡さない。
nonisolated enum MemoryContextBuilder {
    /// プロンプトに含めるトピック数の上限（肥大化を避ける）
    private static let maxTopicsInPrompt = 8

    /// 直前のターンで言及されたばかりの話題を連続して繰り返さないよう、
    /// 最も直近に言及されたトピックはトピックが複数ある場合に限り除外する。
    static func build(from topics: [MemoryTopic]) -> String? {
        guard !topics.isEmpty else { return nil }

        let mostRecentID = topics.max(by: { $0.lastMentionedAt < $1.lastMentionedAt })?.id
        let candidates = topics
            .filter { topics.count == 1 || $0.id != mostRecentID }
            .sorted { $0.mentionCount > $1.mentionCount }
            .prefix(maxTopicsInPrompt)

        guard !candidates.isEmpty else { return nil }
        return candidates.map(\.topic).joined(separator: "、")
    }
}
