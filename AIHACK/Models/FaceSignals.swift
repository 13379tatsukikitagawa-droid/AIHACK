/// ARFaceAnchorのblendShapesから抽出した、観測事実としての表情特徴量。
/// 感情の推定・分類は一切行わない。あくまで「口角が上がった」「眉が寄った」といった
/// 顔の物理的な変化を、平滑化した数値として表現する。
nonisolated struct FaceSignals: Sendable, Equatable {
    /// 顔が検出されているかどうか
    var isFaceDetected: Bool

    /// 口角の上がり具合 (0=変化なし ... 1=最大)。mouthSmileLeft/Rightの平均。
    var smile: Float
    /// 眉の吊り上がり (0...1)。browInnerUp。
    var browRaise: Float
    /// 眉が寄っている度合い (0...1)。browDownLeft/Rightの平均。
    var browFurrow: Float
    /// 目の開き具合 (0=閉眼 ... 1=全開)。1 - eyeBlinkLeft/Rightの平均。
    var eyeOpenness: Float
    /// 視線の左右方向 (-1=左 ... 0=正面 ... 1=右)
    var gazeHorizontal: Float
    /// 視線の上下方向 (-1=下 ... 0=正面 ... 1=上)
    var gazeVertical: Float
    /// 口の開き (0...1)。jawOpen。
    var jawOpen: Float
    /// 頭の左右回転（ヨー、-1...1に正規化）
    var headYaw: Float
    /// 頭の上下回転（ピッチ、-1...1に正規化）
    var headPitch: Float
    /// 頭の傾き（ロール、-1...1に正規化）
    var headRoll: Float

    static let neutral = FaceSignals(
        isFaceDetected: false,
        smile: 0,
        browRaise: 0,
        browFurrow: 0,
        eyeOpenness: 1,
        gazeHorizontal: 0,
        gazeVertical: 0,
        jawOpen: 0,
        headYaw: 0,
        headPitch: 0,
        headRoll: 0
    )
}
