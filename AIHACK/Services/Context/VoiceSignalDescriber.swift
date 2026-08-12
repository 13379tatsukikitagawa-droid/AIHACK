/// VoiceSignalsの数値を、LLMに渡すための自然言語の観測記述に変換する。
/// FaceSignalDescriberと同じ方針を適用する: 数値そのものはLLMに渡さず、閾値を下回るわずかな
/// 変動は無視し、有意な変化があった項目のみを、感情の断定を含まない事実として記述する。
///
/// 表情と異なり、声には万人共通の「安静時の基準」が存在しないため、基準値は固定値ではなく
/// セッション内でのこれまでの発話の平均とする。つまり「その人自身の中での相対的な変化」として
/// 扱う（例: 普段より発話が速い、ではなく客観的に「速い/遅い」という判定はしない）。
nonisolated enum VoiceSignalDescriber {
    // 基準値（セッション平均）からの相対変化を「有意」とみなす割合。
    private static let speechRateRelativeThreshold: Float = 0.3
    private static let volumeRelativeThreshold: Float = 0.25
    private static let volumeVariationRelativeThreshold: Float = 0.35
    private static let silenceCountRelativeThreshold: Float = 0.5
    private static let silenceDurationRelativeThreshold: Float = 0.4
    private static let pitchVariationRelativeThreshold: Float = 0.35

    /// 相対変化の計算がゼロ除算・過敏反応にならないようにする下限値
    private static let epsilon: Float = 0.01

    /// 基準値が安定するまでに必要な最低サンプル数（これ未満は「観測が不足している」として記述しない）
    static let minimumBaselineSamples = 2

    /// 有意な変化がひとつもない場合、または基準値がまだ安定していない場合はnilを返す。
    static func describe(current: VoiceSignals, baseline: VoiceSignals, baselineSampleCount: Int) -> String? {
        guard baselineSampleCount >= minimumBaselineSamples else { return nil }

        var observations: [String] = []

        if let speechRateObservation = relativeObservation(
            current: current.speechRateCharactersPerSecond,
            baseline: baseline.speechRateCharactersPerSecond,
            threshold: speechRateRelativeThreshold,
            faster: "発話速度が普段より速い",
            slower: "発話速度が普段より遅い"
        ) {
            observations.append(speechRateObservation)
        }

        if let volumeObservation = relativeObservation(
            current: current.averageVolume,
            baseline: baseline.averageVolume,
            threshold: volumeRelativeThreshold,
            faster: "声が普段より大きい",
            slower: "声が普段より小さい"
        ) {
            observations.append(volumeObservation)
        }

        if let volumeVariationObservation = relativeObservation(
            current: current.volumeVariation,
            baseline: baseline.volumeVariation,
            threshold: volumeVariationRelativeThreshold,
            faster: "音量の変動が普段より大きい",
            slower: "音量の変動が普段より小さい（一定した声量）"
        ) {
            observations.append(volumeVariationObservation)
        }

        if let silenceCountObservation = relativeObservation(
            current: Float(current.silenceSegmentCount),
            baseline: Float(baseline.silenceSegmentCount),
            threshold: silenceCountRelativeThreshold,
            faster: "発話中の間（沈黙）が普段より多い",
            slower: "発話中の間（沈黙）が普段より少ない"
        ) {
            observations.append(silenceCountObservation)
        }

        if let silenceDurationObservation = relativeObservation(
            current: current.averageSilenceDuration,
            baseline: baseline.averageSilenceDuration,
            threshold: silenceDurationRelativeThreshold,
            faster: "間（沈黙）1回あたりの長さが普段より長い",
            slower: "間（沈黙）1回あたりの長さが普段より短い"
        ) {
            observations.append(silenceDurationObservation)
        }

        if let pitchVariationObservation = relativeObservation(
            current: current.pitchVariationProxy,
            baseline: baseline.pitchVariationProxy,
            threshold: pitchVariationRelativeThreshold,
            faster: "声の高さの変化が普段より大きい",
            slower: "声の高さの変化が普段より小さい（一定した声の高さ）"
        ) {
            observations.append(pitchVariationObservation)
        }

        guard !observations.isEmpty else { return nil }
        return observations.joined(separator: "、")
    }

    /// baseline（現在の発話を含まないセッション平均）を、これまでのVoiceSignalSampleから計算する。
    /// サンプルがひとつもない場合はnilを返す。
    static func averageBaseline(from samples: [VoiceSignalSample]) -> VoiceSignals? {
        guard !samples.isEmpty else { return nil }

        var speechRateSum: Float = 0
        var volumeSum: Float = 0
        var volumeVariationSum: Float = 0
        var silenceCountSum = 0
        var silenceDurationSum: Float = 0
        var utteranceDurationSum: Float = 0
        var pitchVariationSum: Float = 0

        for sample in samples {
            let signals = sample.signals
            speechRateSum += signals.speechRateCharactersPerSecond
            volumeSum += signals.averageVolume
            volumeVariationSum += signals.volumeVariation
            silenceCountSum += signals.silenceSegmentCount
            silenceDurationSum += signals.averageSilenceDuration
            utteranceDurationSum += signals.utteranceDuration
            pitchVariationSum += signals.pitchVariationProxy
        }

        let count = Float(samples.count)
        return VoiceSignals(
            speechRateCharactersPerSecond: speechRateSum / count,
            averageVolume: volumeSum / count,
            volumeVariation: volumeVariationSum / count,
            silenceSegmentCount: Int((Float(silenceCountSum) / count).rounded()),
            averageSilenceDuration: silenceDurationSum / count,
            utteranceDuration: utteranceDurationSum / count,
            pitchVariationProxy: pitchVariationSum / count
        )
    }

    private static func relativeObservation(
        current: Float,
        baseline: Float,
        threshold: Float,
        faster: String,
        slower: String
    ) -> String? {
        let relativeChange = (current - baseline) / max(abs(baseline), epsilon)
        if relativeChange >= threshold {
            return faster
        } else if relativeChange <= -threshold {
            return slower
        }
        return nil
    }
}
