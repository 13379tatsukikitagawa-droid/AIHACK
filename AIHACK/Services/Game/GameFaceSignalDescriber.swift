/// FaceSignalsの数値を、ゲームの判定LLMに渡すための自然言語の観測記述に変換する。
/// 会話用の共有実装（Services/Context/FaceSignalDescriber.swift）とロジックは同じだが、
/// あちらは継続的な会話中の「有意な変化」を保守的に検出する前提の閾値であるのに対し、
/// ゲームは2〜4秒程度の短い演技を1回だけ観測するため、同じ閾値では表情の変化が
/// ほとんど検出されず、判定材料が乏しくなってしまう。そのためゲーム専用に閾値を緩めた
/// 別実装として用意している（GameVoiceSignalDescriberと同じ方針）。
/// 会話用のFaceSignalDescriberには一切手を加えない。
nonisolated enum GameFaceSignalDescriber {
    private static let smileThreshold: Float = 0.18
    private static let strongSmileThreshold: Float = 0.4
    private static let browRaiseThreshold: Float = 0.18
    private static let browFurrowThreshold: Float = 0.18
    private static let eyeNarrowThreshold: Float = 0.18
    private static let jawOpenThreshold: Float = 0.18
    private static let gazeThreshold: Float = 0.2
    private static let headAngleThreshold: Float = 0.15

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
