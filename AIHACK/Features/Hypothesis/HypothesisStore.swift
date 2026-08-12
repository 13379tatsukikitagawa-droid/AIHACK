import Foundation
import Observation
import os

/// セッション全体の観察に基づく仮説生成の状態と結果を保持する。
/// 会話の応答経路（ChatViewModel.runStream）とは完全に独立したTaskで動作し、
/// 会話の応答速度に影響を与えない。生成結果はメモリ上のみで保持し、ディスクへは保存しない。
@MainActor
@Observable
final class HypothesisStore {
    enum GenerationState: Equatable {
        case idle
        case generating
        case ready
        case insufficientObservation(String)
        case failed(String)
    }

    private static let logger = Logger(subsystem: "com.tatsukikitagawa.AIHACK", category: "Hypothesis")

    private(set) var generationState: GenerationState = .idle
    private(set) var hypotheses: [Hypothesis] = []

    private let llmService: LLMServiceProtocol
    private let sessionLog: SessionLog
    private let memoryStore: MemoryStore
    private var generationTask: Task<Void, Never>?

    init(llmService: LLMServiceProtocol, sessionLog: SessionLog, memoryStore: MemoryStore) {
        self.llmService = llmService
        self.sessionLog = sessionLog
        self.memoryStore = memoryStore
    }

    var canGenerate: Bool {
        generationState != .generating && !sessionLog.turns.isEmpty
    }

    /// ユーザーが明示的に要求した時のみ呼ばれる。自動生成は行わない。
    func generate() {
        guard canGenerate else { return }

        generationState = .generating
        let prompt = SessionSummaryBuilder.buildPrompt(from: sessionLog, memoryTopics: memoryStore.topics)
        Self.logger.info("仮説生成を開始: model=\(ModelCatalog.hypothesisGeneration, privacy: .public) turnCount=\(self.sessionLog.turns.count, privacy: .public)")

        generationTask = Task { [weak self] in
            await self?.performGeneration(prompt: prompt)
        }
    }

    func setFeedback(_ feedback: HypothesisFeedback, for id: UUID) {
        guard let index = hypotheses.firstIndex(where: { $0.id == id }) else { return }
        hypotheses[index].feedback = (hypotheses[index].feedback == feedback) ? .none : feedback
    }

    private func performGeneration(prompt: String) async {
        do {
            let report = try await llmService.completeStructured(
                for: [ChatMessage(role: .user, content: prompt)],
                model: ModelCatalog.hypothesisGeneration,
                systemPrompt: SystemPrompt.hypothesisGeneration,
                as: HypothesisReport.self
            )

            guard !Task.isCancelled else { return }

            if report.hypotheses.isEmpty {
                let note = report.insufficientObservation ?? "観測が不足しているため、仮説を生成できませんでした。"
                Self.logger.info("観測不足のため仮説なし")
                hypotheses = []
                generationState = .insufficientObservation(note)
            } else {
                Self.logger.info("仮説を\(report.hypotheses.count, privacy: .public)件生成しました")
                hypotheses = report.hypotheses.map { Hypothesis($0) }
                generationState = .ready
            }
        } catch {
            Self.logger.error("仮説生成に失敗しました: \(error.localizedDescription, privacy: .public)")
            let message = (error as? LocalizedError)?.errorDescription ?? "仮説の生成に失敗しました。"
            generationState = .failed(message)
        }
    }
}
