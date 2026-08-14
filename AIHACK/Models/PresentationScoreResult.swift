import Foundation

/// 「30秒プレゼン」1軸分の採点結果。
nonisolated struct PresentationAxisScore: Sendable, Equatable {
    /// 0...100
    let score: Int
    let comment: String
}

/// 「30秒プレゼン」1ラウンド分の採点結果。合計点はアプリ側で3軸の単純合計として算出し、
/// LLMの算術に依存しない。
nonisolated struct PresentationScoreResult: Sendable, Equatable {
    let content: PresentationAxisScore
    let voice: PresentationAxisScore
    let expression: PresentationAxisScore

    var total: Int {
        content.score + voice.score + expression.score
    }
}
