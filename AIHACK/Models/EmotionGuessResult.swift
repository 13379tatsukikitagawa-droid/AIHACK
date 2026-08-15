import Foundation

/// 感情当てゲーム1ラウンド分の判定結果。LLMが選んだカードと、その根拠に加えて、
/// 判定の透明性を高めるための詳細（決め手になった観測・カードごとの確信度）を保持する。
nonisolated struct EmotionGuessResult: Sendable, Equatable {
    let guessedCard: EmotionCard
    let reasoning: String
    /// 判断の決め手になった観測の短い箇条書き（2〜3個程度）。空の場合もある。
    let keyObservations: [String]
    /// 選択肢カードごとの確信度（0〜100）。選ばれなかったカードの値も含む。
    /// cardIDをキーに持つため、EmotionCard.allCasesと突き合わせてグラフ表示に使う。
    let cardScores: [String: Int]

    /// 選ばれたカードの確信度（0〜100）。取得できない場合は0。
    var confidence: Int { cardScores[guessedCard.id] ?? 0 }
}
