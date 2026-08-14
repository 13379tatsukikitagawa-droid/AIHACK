import Foundation

/// 音声モード（ハンズフリー会話）へ入る・出る際に、LLMを呼び出さず即座に再生する固定の一言。
/// 「これから話を聞いてもらえる」という空気を最初の数秒で伝えるための導入演出であり、
/// 傾聴のスタイルや応答内容そのもの（SystemPrompt.conversation）には一切影響しない。
nonisolated enum VoiceModeGreeting {
    private static let baseGreeting = "どうぞ、話したいことを聞かせてください"
    private static let firstTimeReassurance = "ここで話したことはあなただけのものです"
    static let farewell = "また話したくなったら、いつでも"

    /// isFirstTimeがtrueの場合のみ、安心感を伝える一言を付け加える。2回目以降は通常の迎えの言葉のみ。
    static func greeting(isFirstTime: Bool) -> String {
        isFirstTime ? "\(baseGreeting)。\(firstTimeReassurance)" : baseGreeting
    }
}

/// 音声モードを一度でも使ったことがあるかを端末に永続化する。アプリの再起動やセッションを
/// またいで、本当に初回の起動時にのみ安心感を伝える一言を追加するために使う。
nonisolated enum VoiceModeIntroductionState {
    private static let hasEnteredKey = "com.tatsukikitagawa.AIHACK.voiceMode.hasEnteredBefore"

    /// 呼び出し時点で初回だったかどうかを判定し、以後は初回ではなくなったことを記録する。
    static func markEnteredAndReturnWasFirstTime() -> Bool {
        let defaults = UserDefaults.standard
        let wasFirstTime = !defaults.bool(forKey: hasEnteredKey)
        if wasFirstTime {
            defaults.set(true, forKey: hasEnteredKey)
        }
        return wasFirstTime
    }
}
