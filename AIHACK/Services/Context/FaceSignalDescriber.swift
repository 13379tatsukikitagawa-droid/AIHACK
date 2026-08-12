/// FaceSignalsの数値を、LLMに渡すための自然言語の観測記述に変換する。
/// 数値そのものはLLMに渡さない。閾値を下回るわずかな変動は無視し、
/// 有意な変化があった項目のみを、感情の断定を含まない事実として記述する。
nonisolated enum FaceSignalDescriber {
    // 各特徴量の「有意な変化」とみなす閾値。FaceSignals.neutral（安静時の顔）からの乖離量で判定する。
    private static let smileThreshold: Float = 0.3
    private static let strongSmileThreshold: Float = 0.6
    private static let browRaiseThreshold: Float = 0.3
    private static let browFurrowThreshold: Float = 0.3
    private static let eyeNarrowThreshold: Float = 0.3
    private static let jawOpenThreshold: Float = 0.3
    private static let gazeThreshold: Float = 0.3
    private static let headAngleThreshold: Float = 0.25

    /// 有意な変化がひとつもない場合、または顔が検出されていない場合はnilを返す。
    static func describe(_ signals: FaceSignals) -> String? {
        guard signals.isFaceDetected else { return nil }

        var observations: [String] = []

        if signals.smile >= strongSmileThreshold {
            observations.append("口角がはっきり上がっている")
        } else if signals.smile >= smileThreshold {
            observations.append("口角がやや上がっている")
        }

        if signals.browRaise >= browRaiseThreshold {
            observations.append("眉が上がっている")
        }

        if signals.browFurrow >= browFurrowThreshold {
            observations.append("眉が寄っている")
        }

        if (1 - signals.eyeOpenness) >= eyeNarrowThreshold {
            observations.append("目を細めている")
        }

        if signals.jawOpen >= jawOpenThreshold {
            observations.append("口が開いている")
        }

        if abs(signals.gazeHorizontal) >= gazeThreshold {
            observations.append(signals.gazeHorizontal > 0 ? "視線がやや右を向いている" : "視線がやや左を向いている")
        }

        if abs(signals.gazeVertical) >= gazeThreshold {
            observations.append(signals.gazeVertical > 0 ? "視線が上を向いている" : "視線が下を向いている")
        }

        if abs(signals.headYaw) >= headAngleThreshold {
            observations.append(signals.headYaw > 0 ? "顔がやや右を向いている" : "顔がやや左を向いている")
        }

        if abs(signals.headPitch) >= headAngleThreshold {
            observations.append(signals.headPitch > 0 ? "顔がやや上を向いている" : "顔がやや下を向いている")
        }

        if abs(signals.headRoll) >= headAngleThreshold {
            observations.append("首をかしげている")
        }

        guard !observations.isEmpty else { return nil }
        return observations.joined(separator: "、")
    }
}
