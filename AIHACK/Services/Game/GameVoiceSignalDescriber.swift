/// VoiceSignalsの数値を、ゲームの判定LLMに渡すための自然言語の観測記述に変換する。
/// 感情の推定・分類は一切行わない方針は既存のVoiceSignalDescriberと共通だが、
/// あちらはセッション内での「その人自身の平均」からの相対変化を基準にするのに対し、
/// ゲームは1ラウンド完結（会話履歴を持たず基準値が存在しない）であるため、
/// 絶対的な閾値で判定する別実装として用意している。既存のVoiceSignalDescriberおよび
/// ChatViewModelのデータフローには一切触れない。
nonisolated enum GameVoiceSignalDescriber {
    // ゲームは2〜4秒の短い演技を1回きり観測するだけのため、当初の閾値では有意な観測が
    // ほとんど検出されず、AIの判定材料が乏しくなっていた（正答率低下の一因）。
    // より緩やかな閾値に調整し、観測が拾われやすくしている。
    private static let loudVolumeThreshold: Float = 0.30
    private static let quietVolumeThreshold: Float = 0.18
    private static let highVolumeVariationThreshold: Float = 0.10
    private static let lowVolumeVariationThreshold: Float = 0.08
    private static let highPitchVariationThreshold: Float = 0.30
    private static let lowPitchVariationThreshold: Float = 0.20
    private static let fastSpeechThreshold: Float = 1.8
    private static let slowSpeechThreshold: Float = 1.2
    private static let notableSilenceDuration: Float = 0.4
    /// 自己相関でピッチを推定できた区間の平均基本周波数（Hz）に対するしきい値。
    /// 一般的な成人の発声域（目安）を基準に、高め/低めのみを言語化する
    /// （中間帯は「普通」であり判定材料として弱いため言及しない）。
    private static let highPitchHzThreshold: Float = 180
    private static let lowPitchHzThreshold: Float = 150
    private static let shortUtteranceDuration: Float = 0.7
    private static let longUtteranceDuration: Float = 1.2

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

        // averagePitchHzは自己相関による簡易推定のため、0（推定不可）の場合は言及しない。
        if signals.averagePitchHz >= highPitchHzThreshold {
            observations.append("声が高め")
        } else if signals.averagePitchHz > 0, signals.averagePitchHz <= lowPitchHzThreshold {
            observations.append("声が低め")
        }

        if signals.pitchVariationProxy >= highPitchVariationThreshold {
            observations.append("声の高さの変化が大きい")
        } else if signals.pitchVariationProxy <= lowPitchVariationThreshold {
            observations.append("声の高さの変化が小さく、一本調子")
        }

        if signals.speechRateCharactersPerSecond >= fastSpeechThreshold {
            observations.append("発声が速い")
        } else if signals.speechRateCharactersPerSecond > 0, signals.speechRateCharactersPerSecond <= slowSpeechThreshold {
            observations.append("発声がゆっくり、または間延びしている")
        }

        if signals.utteranceDuration > 0, signals.utteranceDuration <= shortUtteranceDuration {
            observations.append("発声が短く鋭い")
        } else if signals.utteranceDuration >= longUtteranceDuration {
            observations.append("発声が長く伸びている")
        }

        if signals.silenceSegmentCount > 0, signals.averageSilenceDuration >= notableSilenceDuration {
            observations.append("発声の前後に間（沈黙）がある")
        }

        guard !observations.isEmpty else { return nil }
        return observations.joined(separator: "、")
    }
}
