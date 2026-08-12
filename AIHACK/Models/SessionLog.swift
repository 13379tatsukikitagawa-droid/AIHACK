import Foundation

/// ユーザー発言がテキスト入力・音声入力のいずれ由来かを表す。
nonisolated enum InputMethod: Sendable {
    case text
    case voice
}

/// LLMに表情の言語化記述を送らなかった理由。
nonisolated enum FaceContextReason: Sendable {
    case cameraDisabled
    case faceNotDetected
    case noSignificantChange
}

/// その発言でLLMに実際に渡した表情情報。数値ではなく、渡した自然言語の記述そのものを保持する。
nonisolated enum FaceContextRecord: Sendable {
    case sent(String)
    case notSent(FaceContextReason)
}

/// LLMに声の言語化記述を送らなかった理由。
nonisolated enum VoiceContextReason: Sendable {
    /// テキスト入力の発話のため、そもそも声の観測が存在しない
    case notVoiceInput
    /// セッション内の基準値（過去の発話の平均）がまだ十分に蓄積されていない
    case insufficientBaseline
    /// 基準値と比較して有意な変化がなかった
    case noSignificantChange
}

/// その発言でLLMに実際に渡した声の観測情報。数値ではなく、渡した自然言語の記述そのものを保持する。
nonisolated enum VoiceContextRecord: Sendable {
    case sent(String)
    case notSent(VoiceContextReason)
}

/// 発話ごとの記録。1回のユーザー発言〜AI応答の完結までを表す。
nonisolated struct TurnLog: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let userUtterance: String
    let inputMethod: InputMethod
    let faceContext: FaceContextRecord
    let voiceContext: VoiceContextRecord
    let responseModel: String
    /// 簡潔な発話（挨拶・相槌）と判定され、論証構造の抽出を行わなかった場合はtrue
    let wasSimpleUtterance: Bool
    let structuringModel: String?
    let assistantResponse: String
    let toulminArgument: ToulminArgument?
    /// 送信から最初のトークン受信までの時間（秒）
    let timeToFirstToken: TimeInterval?
    /// 送信からテキスト応答の受信完了までの時間（秒）
    let timeToCompletion: TimeInterval?
}

/// 表情特徴量の時系列サンプル1点。
nonisolated struct FaceSignalSample: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let signals: FaceSignals
}

/// 声の韻律特徴量のサンプル1点（発話1回につき1点。連続的な時系列ではない）。
nonisolated struct VoiceSignalSample: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let signals: VoiceSignals
}

/// ConversationStateの遷移記録。
nonisolated struct StateTransitionLog: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let state: ConversationState
}

/// セッション中に起きたことをメモリ上にのみ記録する。ディスクへの永続化は一切行わず、
/// アプリを終了する（インスタンスが破棄される）と記録も失われる。
/// 顔の映像そのものは一切保持せず、数値・言語化された記述のみを扱う。
@MainActor
@Observable
final class SessionLog {
    let sessionStartedAt = Date()

    private(set) var turns: [TurnLog] = []
    private(set) var faceSignalSamples: [FaceSignalSample] = []
    /// 声の韻律特徴量。発話1回につき1点のみ記録するため、表情サンプルほど頻繁には増えない。
    private(set) var voiceSignalSamples: [VoiceSignalSample] = []
    private(set) var stateTransitions: [StateTransitionLog] = []
    /// TTS（OrcaRouter音声合成）の実際のAPI呼び出し回数。キャッシュヒットは含まない。
    private(set) var ttsCallCount = 0
    /// TTSへ送信した文字数の合計。キャッシュヒットは含まない。
    private(set) var ttsCharacterCount = 0

    /// 表情サンプルの保持上限。超えた分は古いものから破棄し、メモリの際限ない増加を防ぐ。
    private let maxFaceSignalSamples = 1000
    /// 声のサンプルは発話1回につき1点のみなので、表情ほど厳しい上限は不要だが念のため設ける。
    private let maxVoiceSignalSamples = 1000

    func recordTurn(_ turn: TurnLog) {
        turns.append(turn)
    }

    func recordFaceSignalSample(_ signals: FaceSignals, at timestamp: Date = Date()) {
        faceSignalSamples.append(FaceSignalSample(timestamp: timestamp, signals: signals))
        if faceSignalSamples.count > maxFaceSignalSamples {
            faceSignalSamples.removeFirst(faceSignalSamples.count - maxFaceSignalSamples)
        }
    }

    func recordVoiceSignalSample(_ signals: VoiceSignals, at timestamp: Date = Date()) {
        voiceSignalSamples.append(VoiceSignalSample(timestamp: timestamp, signals: signals))
        if voiceSignalSamples.count > maxVoiceSignalSamples {
            voiceSignalSamples.removeFirst(voiceSignalSamples.count - maxVoiceSignalSamples)
        }
    }

    func recordStateTransition(_ state: ConversationState, at timestamp: Date = Date()) {
        stateTransitions.append(StateTransitionLog(timestamp: timestamp, state: state))
    }

    func recordTTSUsage(characterCount: Int) {
        ttsCallCount += 1
        ttsCharacterCount += characterCount
    }
}
