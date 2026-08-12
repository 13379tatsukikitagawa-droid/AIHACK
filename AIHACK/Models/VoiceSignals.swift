/// マイクの音声バッファから抽出した、観測事実としての韻律特徴量。
/// 表情センシングと同じ方針を適用し、感情の推定・分類は一切行わない。あくまで
/// 「発話が速い」「音量の変動が大きい」といった声の物理的な特徴を、数値として表現する。
/// 音声データそのものは一切保持せず、発話1回分の集計値のみをこの構造体に残す。
nonisolated struct VoiceSignals: Sendable, Equatable {
    /// 発話速度（1秒あたりの認識文字数）
    var speechRateCharactersPerSecond: Float
    /// 発話中の音量（RMS、0...1に正規化）の平均
    var averageVolume: Float
    /// 発話中の音量の変動幅（標準偏差）
    var volumeVariation: Float
    /// 発話中に検出された無音区間（一定時間以上の音量低下）の回数
    var silenceSegmentCount: Int
    /// 無音区間1回あたりの平均継続時間（秒）。無音区間がなければ0。
    var averageSilenceDuration: Float
    /// 発話1回分の継続時間（秒）
    var utteranceDuration: Float
    /// 声の高さの推移の近似値。基本周波数そのものではなく、フレームごとのゼロ交差率の
    /// 変動係数（標準偏差/平均）を、声の高さの変化の代理指標として扱う。
    var pitchVariationProxy: Float

    static let empty = VoiceSignals(
        speechRateCharactersPerSecond: 0,
        averageVolume: 0,
        volumeVariation: 0,
        silenceSegmentCount: 0,
        averageSilenceDuration: 0,
        utteranceDuration: 0,
        pitchVariationProxy: 0
    )
}
