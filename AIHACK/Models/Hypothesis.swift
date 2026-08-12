import Foundation

/// 仮説の確からしさ。LLMには安易に高い確度を選ばせない前提でシステムプロンプト側を設計する。
nonisolated enum ConfidenceLevel: String, Codable, Sendable, CaseIterable {
    case low
    case medium
    case high
}

/// ユーザーがこの仮説に対して残せる、セッション内限りのフィードバック。
nonisolated enum HypothesisFeedback: Sendable, Equatable {
    case none
    case confirmed
    case rejected
}

/// LLMからそのままデコードする、仮説1件分のJSON構造。
nonisolated struct HypothesisContent: Codable, Sendable {
    let claim: String
    let grounds: String
    let warrant: String
    let qualifier: String
    let rebuttal: String
    let confidence: ConfidenceLevel
    /// 根拠として参照した発話のインデックス（SessionLog.turnsの0始まりの番号）
    let referencedTurnIndexes: [Int]?
    /// この仮説についてユーザーに自然に尋ねられる問いかけ（適切なものがなければnull）
    let suggestedQuestion: String?
}

/// 仮説生成1回分のLLM出力全体。観測不足の場合はhypothesesが空になる。
nonisolated struct HypothesisReport: Codable, Sendable {
    let hypotheses: [HypothesisContent]
    let insufficientObservation: String?
}

/// 画面表示・フィードバック記録用に、LLM出力をラップしたもの。
nonisolated struct Hypothesis: Sendable, Identifiable, Equatable {
    let id = UUID()
    let claim: String
    let grounds: String
    let warrant: String
    let qualifier: String
    let rebuttal: String
    let confidence: ConfidenceLevel
    let referencedTurnIndexes: [Int]
    let suggestedQuestion: String?
    var feedback: HypothesisFeedback = .none

    init(_ content: HypothesisContent) {
        claim = content.claim
        grounds = content.grounds
        warrant = content.warrant
        qualifier = content.qualifier
        rebuttal = content.rebuttal
        confidence = content.confidence
        referencedTurnIndexes = content.referencedTurnIndexes ?? []
        suggestedQuestion = content.suggestedQuestion
    }
}
