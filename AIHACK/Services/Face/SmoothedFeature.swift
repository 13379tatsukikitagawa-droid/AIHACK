/// 単一特徴量について、直近数秒間の値をリングバッファで保持し、
/// 指数移動平均による平滑化・平均値・変化量を算出する。
nonisolated struct SmoothedFeature {
    private var buffer: [Float]
    private var writeIndex = 0
    private var filled = false
    private var smoothedValue: Float = 0
    private var previousSmoothedValue: Float = 0
    private let smoothingFactor: Float

    /// capacity: 更新頻度に応じたリングバッファのサンプル数（既定は約3秒相当を想定）
    init(capacity: Int = 90, smoothingFactor: Float = 0.25) {
        self.buffer = Array(repeating: 0, count: max(1, capacity))
        self.smoothingFactor = smoothingFactor
    }

    /// 新しい生の値を取り込み、平滑化後の値を返す
    @discardableResult
    mutating func update(with rawValue: Float) -> Float {
        previousSmoothedValue = smoothedValue
        smoothedValue += smoothingFactor * (rawValue - smoothedValue)

        buffer[writeIndex] = smoothedValue
        writeIndex = (writeIndex + 1) % buffer.count
        if writeIndex == 0 { filled = true }

        return smoothedValue
    }

    /// 直近の平滑化済みの値
    var current: Float { smoothedValue }
    /// 直前の更新からの変化量
    var delta: Float { smoothedValue - previousSmoothedValue }
    /// リングバッファ内の平均値
    var average: Float {
        let validCount = filled ? buffer.count : writeIndex
        guard validCount > 0 else { return 0 }
        let sum = buffer.prefix(validCount).reduce(Float(0), +)
        return sum / Float(validCount)
    }
}
