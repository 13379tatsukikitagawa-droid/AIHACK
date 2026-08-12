import CoreGraphics

enum Layout {
    /// チャットバブルの角丸半径
    static let bubbleCornerRadius: CGFloat = 18
    /// チャットバブルの最大幅（画面幅に対する比率）
    static let bubbleMaxWidthRatio: CGFloat = 0.78
    /// HIGで定められた最小タップ領域
    static let minTapTarget: CGFloat = 44
    /// 入力欄の角丸半径
    static let inputBarCornerRadius: CGFloat = 20
    /// 生成中インジケーターのドットサイズ
    static let typingDotSize: CGFloat = 6
    /// 生成中インジケーターのドット間隔
    static let typingDotSpacing: CGFloat = 4
    /// マイクボタンの直径
    static let micButtonSize: CGFloat = 56
    /// マイクボタン周囲の音量リングの最大拡張幅
    static let micLevelRingMaxExpansion: CGFloat = 20
    /// 表情ゲージのバー高さ
    static let gaugeBarHeight: CGFloat = 8
    /// アバター表示エリアの最大高さ
    static let avatarMaxHeight: CGFloat = 320
}
