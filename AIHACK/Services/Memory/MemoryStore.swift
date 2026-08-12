import Foundation
import Observation
import os

/// 好み・関心・話題の記憶を保持する。表情・声の観測データ（SessionLog）とは異なり、
/// ディスクへ永続化され、アプリを終了しても消えない。
///
/// 抽出はターン完了ごとに独立したTaskとして非同期に行われ、会話の応答経路
/// （ChatViewModel.runStream）を一切ブロックしない。保存もactor経由で直列化された
/// バックグラウンド処理として行われ、メインスレッドをブロックしない。
@MainActor
@Observable
final class MemoryStore {
    private static let logger = Logger(subsystem: "com.tatsukikitagawa.AIHACK", category: "Memory")
    /// 1トピックあたりに保持する要約の上限（際限のない増加を防ぐ）
    private static let maxSummariesPerTopic = 5

    private(set) var topics: [MemoryTopic]

    private let llmService: LLMServiceProtocol
    private let persistenceQueue: MemoryPersistenceQueue

    init(llmService: LLMServiceProtocol, persistenceQueue: MemoryPersistenceQueue = MemoryPersistenceQueue()) {
        self.llmService = llmService
        self.persistenceQueue = persistenceQueue
        self.topics = MemoryPersistence.load()
    }

    /// 1ターン分の会話から記憶候補を抽出し、保存する。呼び出し元をブロックしない
    /// （内部で独立したTaskを起動して即座に返る）。
    func extractAndStore(userUtterance: String, assistantResponse: String) {
        guard !userUtterance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !assistantResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        Task { [weak self] in
            await self?.performExtraction(userUtterance: userUtterance, assistantResponse: assistantResponse)
        }
    }

    private func performExtraction(userUtterance: String, assistantResponse: String) async {
        let content = "ユーザー: \(userUtterance)\nAI: \(assistantResponse)"

        do {
            let result = try await llmService.completeStructured(
                for: [ChatMessage(role: .user, content: content)],
                model: ModelCatalog.memoryExtraction,
                systemPrompt: SystemPrompt.memoryExtraction,
                as: MemoryExtractionResult.self
            )

            guard !result.candidates.isEmpty else { return }
            Self.logger.info("記憶候補を\(result.candidates.count, privacy: .public)件抽出しました")
            for candidate in result.candidates {
                recordMention(topic: candidate.topic, summary: candidate.summary)
            }
            persist()
        } catch {
            // 記憶抽出はあくまで補助機能。失敗しても会話には一切影響させず、ログのみ残す。
            Self.logger.error("記憶の抽出に失敗しました: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func recordMention(topic: String, summary: String, at date: Date = Date()) {
        let normalizedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTopic.isEmpty else { return }

        if let index = topics.firstIndex(where: { $0.topic.caseInsensitiveCompare(normalizedTopic) == .orderedSame }) {
            topics[index].mentionCount += 1
            topics[index].lastMentionedAt = date
            topics[index].relatedSummaries.append(summary)
            if topics[index].relatedSummaries.count > Self.maxSummariesPerTopic {
                topics[index].relatedSummaries.removeFirst(topics[index].relatedSummaries.count - Self.maxSummariesPerTopic)
            }
        } else {
            topics.append(MemoryTopic(
                topic: normalizedTopic,
                firstMentionedAt: date,
                lastMentionedAt: date,
                mentionCount: 1,
                relatedSummaries: [summary]
            ))
        }
    }

    func deleteTopic(_ id: UUID) {
        topics.removeAll { $0.id == id }
        persist()
    }

    func deleteAll() {
        guard !topics.isEmpty else { return }
        topics.removeAll()
        persist()
    }

    private func persist() {
        let snapshot = topics
        Task {
            await persistenceQueue.save(snapshot)
        }
    }
}

#if DEBUG
extension MemoryStore {
    /// プレビュー専用。ディスクの実データには影響しない。
    func debugSetTopics(_ topics: [MemoryTopic]) {
        self.topics = topics
    }
}
#endif
