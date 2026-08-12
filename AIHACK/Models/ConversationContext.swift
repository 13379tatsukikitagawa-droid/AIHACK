/// 1回の送信でLLMに渡す情報をまとめた入力コンテキスト。
nonisolated struct ConversationContext: Sendable {
    /// ユーザーの発言テキスト
    let userUtterance: String
    /// 発言時点の、有意な変化があった場合のみ設定される言語化済み表情観測情報
    let faceDescription: String?
    /// 音声入力かつセッション内の基準値と比較して有意な変化があった場合のみ設定される、
    /// 言語化済みの声の韻律観測情報
    let voiceDescription: String?
    /// 直近の会話履歴（今回の発言・応答を含まない）
    let history: [ChatMessage]
}
