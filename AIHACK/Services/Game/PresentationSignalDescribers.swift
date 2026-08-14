import Foundation

/// VoiceSignalsの数値を、プレゼン採点用の自然言語の観測記述に変換する。
/// 感情当てゲーム用のGameVoiceSignalDescriberとは別実装とする。あちらは1語の発声を対象とした
/// 短時間の絶対閾値であるのに対し、こちらは30秒間の継続的な発話を対象とし、間（無音）の
/// 頻度・長さや発話速度の傾向を、より長い時間軸で解釈するための閾値を持つ。
nonisolated enum PresentationVoiceSignalDescriber {
    private static let fastSpeechThreshold: Float = 6.0
    private static let slowSpeechThreshold: Float = 2.5
    private static let highVolumeVariationThreshold: Float = 0.16
    private static let lowVolumeVariationThreshold: Float = 0.05

    /// 会話向けのVoiceSignalDescriberと異なり、観測が乏しくても常に何らかの記述を返す
    /// （採点対象として常に評価材料が必要なため、「有意な変化なし」でnilを返す設計にはしない）。
    static func describe(_ signals: VoiceSignals) -> String {
        var parts: [String] = []

        if signals.speechRateCharactersPerSecond >= fastSpeechThreshold {
            parts.append("全体的に発話が速め")
        } else if signals.speechRateCharactersPerSecond > 0, signals.speechRateCharactersPerSecond <= slowSpeechThreshold {
            parts.append("全体的に発話がゆっくり")
        } else if signals.speechRateCharactersPerSecond > 0 {
            parts.append("発話速度はおおむね標準的")
        }

        if signals.silenceSegmentCount == 0 {
            parts.append("間（沈黙）がほとんどなく、一気に話し続けている")
        } else if signals.silenceSegmentCount <= 3 {
            parts.append("間（沈黙）は\(signals.silenceSegmentCount)回、1回あたり平均\(String(format: "%.1f", signals.averageSilenceDuration))秒程度")
        } else {
            parts.append("間（沈黙）が\(signals.silenceSegmentCount)回と多く、1回あたり平均\(String(format: "%.1f", signals.averageSilenceDuration))秒程度")
        }

        if signals.volumeVariation >= highVolumeVariationThreshold {
            parts.append("声量の変化が大きく、抑揚がある")
        } else if signals.volumeVariation <= lowVolumeVariationThreshold {
            parts.append("声量がほぼ一定で抑揚が少ない")
        }

        guard !parts.isEmpty else { return "有効な音声の観測が得られなかった" }
        return parts.joined(separator: "、")
    }
}

/// FaceSignalsの継続的な変動幅から、表情の豊かさ（一本調子でないか）を追跡する。
/// 感情当てゲームのように「その瞬間の一番大きな表情」を1点だけ拾うのではなく、
/// 30秒間を通じて各特徴量がどれだけ動いたか（最大値-最小値の合計）を追跡する。
nonisolated struct PresentationFaceExpressivenessSummary: Sendable {
    let wasFaceDetected: Bool
    let expressivenessRange: Float
}

nonisolated struct PresentationFaceExpressivenessTracker {
    private var minValues: [Float] = Array(repeating: .greatestFiniteMagnitude, count: 4)
    private var maxValues: [Float] = Array(repeating: -.greatestFiniteMagnitude, count: 4)
    private var hasSample = false

    /// 追跡対象は smile / browRaise / browFurrow / jawOpen の4指標。
    mutating func consider(_ signals: FaceSignals) {
        hasSample = true
        let values: [Float] = [signals.smile, signals.browRaise, signals.browFurrow, signals.jawOpen]
        for i in values.indices {
            minValues[i] = min(minValues[i], values[i])
            maxValues[i] = max(maxValues[i], values[i])
        }
    }

    var summary: PresentationFaceExpressivenessSummary {
        guard hasSample else {
            return PresentationFaceExpressivenessSummary(wasFaceDetected: false, expressivenessRange: 0)
        }
        let range = zip(minValues, maxValues).reduce(Float(0)) { $0 + max(0, $1.1 - $1.0) }
        return PresentationFaceExpressivenessSummary(wasFaceDetected: true, expressivenessRange: range)
    }
}

nonisolated enum PresentationFaceSignalDescriber {
    private static let richThreshold: Float = 1.4
    private static let moderateThreshold: Float = 0.6

    static func describe(_ summary: PresentationFaceExpressivenessSummary) -> String {
        guard summary.wasFaceDetected else {
            return "表情データなし（カメラが無効、または顔が検出されなかった）"
        }
        if summary.expressivenessRange >= richThreshold {
            return "表情の変化がとても豊かで、一本調子ではなかった"
        } else if summary.expressivenessRange >= moderateThreshold {
            return "表情にある程度の変化が見られた"
        } else {
            return "表情の変化が乏しく、一本調子な印象だった"
        }
    }
}
