import Foundation

/// ユーザーの入力テキスト（タイピング・音声認識結果のいずれも）をLLMへ送信する前に、
/// 自傷行為・希死念慮などの強い危機的表現が含まれていないかを検知する。
///
/// 判定は完全に端末内のキーワード照合のみで行い、ネットワーク通信・LLMへの問い合わせは
/// 一切発生しない（危機的な内容をそのままAPIへ送ってしまうこと自体を避ける設計）。
/// 「疲れた」「消えたい気分」のような多義的で弱い表現は誤検知が多いため意図的に含めず、
/// 深刻度が明確に高い語のみを対象とすることで、過検知によるユーザー体験の毀損を避ける。
/// 一方でこの単純な照合は表記ゆれ・婉曲表現・多言語の変化形を網羅できないため、
/// あくまで「最低限の安全網」であり、これに依存し過ぎないこと（実運用ではLLM側の
/// システムプロンプトによる指針や、より高度な検知手法との併用を検討すること）。
enum CrisisSafetyFilter {
    struct Match: Equatable {
        let matchedKeyword: String
    }

    private static let keywords: [String] = [
        // 日本語
        "死にたい", "自殺したい", "自殺しよう", "死のうと思", "死ぬ方法", "死に方",
        "リストカット", "リスカ", "首を吊", "首をつ", "飛び降り自殺",
        "自傷行為", "オーバードーズ", "薬を大量に飲", "もう生きていたくない",
        "消えてしまいたい", "生きる意味がない", "生きていても仕方が",
        // 英語
        "kill myself", "want to die", "end my life", "suicidal",
        "self harm", "self-harm", "hurt myself",
    ]

    static func evaluate(_ text: String) -> Match? {
        let normalized = text.lowercased()
        for keyword in keywords where normalized.contains(keyword.lowercased()) {
            return Match(matchedKeyword: keyword)
        }
        return nil
    }
}
