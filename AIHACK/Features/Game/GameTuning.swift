import Foundation

/// ゲームモード専用のタイミング調整値。Features/Chat/HandsFreeTuning.swift とは完全に独立して
/// 管理し、Mirror（会話機能）のチューニングには一切影響を与えない。
enum GameTuning {
    /// カウントダウンの秒数（3, 2, 1）
    static let countdownSeconds = 3
    /// この時間が経過するまでは、無音を検出しても自動終了しない（発声前の間を早期終了と誤判定しないため）
    static let minimumRecordingDuration: TimeInterval = 1.0
    /// 演技の最大録音時間。この時間に達すると強制的に発話終了とみなす
    static let maxRecordingDuration: TimeInterval = 4.0
    /// この音量を下回る場合を無音とみなす
    static let silenceAudioLevelThreshold: Float = 0.08
    /// 発声を検出した後、この時間以上無音が続いたら発話終了とみなす
    static let silenceDurationForAutoStop: TimeInterval = 0.7
    /// 録音処理全体が完全に停止しない場合に備えた、最大録音時間からの猶予（安全網）
    static let recordingHardDeadlineGrace: TimeInterval = 1.5
}
