/// VoiceSignalsの数値を、ゲームの判定LLMに渡すための自然言語の観測記述に変換する。
/// 感情の推定・分類は一切行わない方針は既存のVoiceSignalDescriberと共通だが、
/// あちらはセッション内での「その人自身の平均」からの相対変化を基準にするのに対し、
/// ゲームは1ラウンド完結（会話履歴を持たず基準値が存在しない）であるため、
/// 絶対的な閾値で判定する別実装として用意している。既存のVoiceSignalDescriberおよび
/// ChatViewModelのデータフローには一切触れない。
nonisolated enum GameVoiceSignalDescriber {
    private static let loudVolumeThreshold: Float = 0.42
    private static let quietVolumeThreshold: Float = 0.12
    private static let highVolumeVariationThreshold: Float = 0.16
    private static let lowVolumeVariationThreshold: Float = 0.05
    private static let highPitchVariationThreshold: Float = 0.45
    private static let fastSpeechThreshold: Float = 2.5
    private static let slowSpeechThreshold: Float = 0.8
    private static let notableSilenceDuration: Float = 0.6

    /// 有意な観測がひとつもない場合はnilを返す。
    static func describe(_ signals: VoiceSignals) -> String? {
        var observations: [String] = []

        if signals.averageVolume >= loudVolumeThreshold {
            observations.append("声が大きい")
        } else if signals.averageVolume <= quietVolumeThreshold {
            observations.append("声が小さい")
        }

        if signals.volumeVariation >= highVolumeVariationThreshold {
            observations.append("声量の変化が急激")
        } else if signals.volumeVariation <= lowVolumeVariationThreshold {
            observations.append("声量が一定で抑揚が少ない")
        }

        if signals.pitchVariationProxy >= highPitchVariationThreshold {
            observations.append("声の高さの変化が大きい")
        }

        if signals.speechRateCharactersPerSecond >= fastSpeechThreshold {
            observations.append("発声が速い")
        } else if signals.speechRateCharactersPerSecond > 0, signals.speechRateCharactersPerSecond <= slowSpeechThreshold {
            observations.append("発声がゆっくり、または間延びしている")
        }

        if signals.silenceSegmentCount > 0, signals.averageSilenceDuration >= notableSilenceDuration {
            observations.append("発声の前後に間（沈黙）がある")
        }

        guard !observations.isEmpty else { return nil }
        return observations.joined(separator: "、")
    }
}
