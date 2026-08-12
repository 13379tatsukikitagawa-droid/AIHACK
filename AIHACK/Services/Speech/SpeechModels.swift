import Foundation

nonisolated enum SpeechRecognitionEvent: Sendable {
    case partialTranscript(String)
    case finalTranscript(String)
    /// 0...1に正規化した音量レベル
    case audioLevel(Float)
    /// 発話確定と同時に送出される、その発話1回分の韻律特徴量。finalTranscriptの直前に届く。
    case voiceSignals(VoiceSignals)
}

nonisolated enum SpeechSynthesisEvent: Sendable {
    case speechDidBegin
    /// 読み上げ中の単語（文字範囲）が進行した。アバターの発話同期に利用する。
    case wordBoundary
    /// キューに投入した発話がすべて終了（完了・中断を問わず）した
    case queueDidDrain
    /// TTSの実際のAPI呼び出しが発生した（キャッシュヒット時は発生しない）。分析画面の統計記録にのみ使う。
    case ttsUsage(characterCount: Int)
}

nonisolated enum SpeechPermissionStatus: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
}
