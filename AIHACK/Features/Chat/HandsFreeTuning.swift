import Foundation

/// ハンズフリー音声会話の調整用定数。ここを変更するだけで挙動を調整できる。
nonisolated enum HandsFreeTuning {
    /// 無音がこの秒数続いたら発話が終わったとみなし、自動的に認識を確定・送信する
    static let silenceDurationForAutoSend: TimeInterval = 1.2
    /// この値を下回る音量（0...1に正規化済み）は無音とみなす
    static let silenceAudioLevelThreshold: Float = 0.06
    /// この文字数未満の認識結果は、無音や短い相槌の誤検出とみなし送信しない
    static let minimumTranscriptLength = 2
    /// thinking/speaking状態でこの秒数以上まったく進行がない場合、強制的に復帰する
    static let stuckStateTimeout: TimeInterval = 30
    /// 強制復帰の判定間隔
    static let stuckStateCheckInterval: TimeInterval = 5
    /// マイクを開く直前に置く、急かされている印象を避けるための短い間（呼吸1回分程度）
    static let listeningEntryPause: TimeInterval = 0.45
    /// ハンズフリー会話中、この秒数以上まったく発話がない場合はセッションを終える
    static let conversationInactivityTimeout: TimeInterval = 45
}
