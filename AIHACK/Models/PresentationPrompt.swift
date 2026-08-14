import Foundation

/// 「30秒プレゼン」モードで出題する、即興プレゼンのお題。
/// 正解のない自由度の高い題材のみを対象とし、知識量ではなく話し方・内容の組み立て方を
/// 試せるものに限定する。ブース当日の反応を見て調整しやすいよう、この1ファイルに一元管理する。
nonisolated enum PresentationPrompt {
    static let all: [String] = [
        "あなたが今持っているものを1つ選んで魅力を語ってください",
        "猫と犬、どちらが優れているか主張してください",
        "今日という日をキャッチコピーにしてください",
        "このアプリの魅力を売り込んでください",
        "もし1日だけ透明人間になれたら何をするか話してください",
        "人生で一番好きな食べ物について力説してください",
        "今日誰かに感謝したいことを話してください",
        "10年後の自分に向けて一言メッセージを送ってください",
        "このイベント（ブース）の魅力をプレゼンしてください",
        "あなたの一番の特技を自慢してください",
        "世界を一つだけ変えられるとしたら何を変えるか話してください",
        "今すぐ旅行するならどこに行きたいか、理由とともに話してください"
    ]

    /// ランダムに1つ選ぶ。previousが指定されている場合、直前と同じお題が連続しないようにする。
    static func random(excluding previous: String?) -> String {
        guard all.count > 1, let previous else {
            return all.randomElement() ?? all[0]
        }
        var candidate = all.randomElement() ?? all[0]
        while candidate == previous {
            candidate = all.randomElement() ?? all[0]
        }
        return candidate
    }
}
