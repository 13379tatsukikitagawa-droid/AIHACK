import Foundation

/// 「はぁって言うゲーム」風モードで出題する一言のお題。
/// 意味そのものが特定の感情に固定される単語（「好き」「ありがとう」等）は含めない。
/// 驚き・怒り・喜び・疑い・呆れなど、どの感情カードを当てはめても不自然に聞こえない
/// 短い言葉のみを対象とする。ブース当日の来場者の反応を見て調整しやすいよう、
/// リストをこの1ファイルに一元管理する。
nonisolated enum GamePrompt {
    static let all: [String] = [
        "はぁ", "え", "うそ", "まじで", "へえ", "あー", "はい", "なに", "ふーん", "おお",
        "うわ", "ちょっと", "そう", "えっ", "あっそ", "まさか", "おい", "お前", "なんで", "よし"
    ]

    /// ランダムに1つ選ぶ。previousが指定されている場合、直前と同じお題が連続しないようにする。
    static func random(excluding previous: String?) -> String {
        guard all.count > 1, let previous else {
            return all.randomElement() ?? "はぁ"
        }
        var candidate = all.randomElement() ?? "はぁ"
        while candidate == previous {
            candidate = all.randomElement() ?? "はぁ"
        }
        return candidate
    }
}
