import AVFoundation

/// 発話1回分（マイクが開いてから確定するまで）の音声バッファから、韻律的な特徴量を集計する。
/// 感情の推定・分類は一切行わず、観測値の集計のみを行う。
///
/// append(_:)はAVAudioEngineのリアルタイムオーディオスレッドから直接呼ばれる想定のため、
/// 既存のaudioLevel計算と同程度の軽量なO(n)演算のみを行い、MainActorや音声認識の応答性に
/// 影響を与えない。この型自体をnonisolatedとし、共有可変状態はNSLockで保護する
/// （SpeechRecognitionServiceの RecognitionRequestBox と同じ方針）。
nonisolated final class ProsodyAccumulator: @unchecked Sendable {
    private static let silenceLevelThreshold: Float = 0.06
    private static let minimumSilenceSegmentDuration: TimeInterval = 0.25

    private let lock = NSLock()
    private let startedAt = Date()

    private var volumeSum: Double = 0
    private var volumeSumSquares: Double = 0
    private var sampleCount: Int = 0
    private var zeroCrossingRateSum: Double = 0
    private var zeroCrossingRateSumSquares: Double = 0

    private var isCurrentlySilent = false
    private var currentSilenceStartedAt: Date?
    private var silenceSegmentCount = 0
    private var silenceDurationSum: TimeInterval = 0

    /// 1バッファ分を集計し、そのバッファの音量レベル（0...1）を返す。
    /// 既存のaudioLevelイベントと同じ値を、二重計算せずにそのまま再利用できるようにするため。
    func append(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        let samples = channelData[0]
        var sumSquares: Float = 0
        var crossings = 0
        var previous = samples[0]
        for i in 0..<frameLength {
            let sample = samples[i]
            sumSquares += sample * sample
            if i > 0, (sample >= 0) != (previous >= 0) {
                crossings += 1
            }
            previous = sample
        }
        let rms = min(max(sqrt(sumSquares / Float(frameLength)) * 12, 0), 1)
        let zeroCrossingRate = Double(crossings) / Double(frameLength)

        lock.lock()
        volumeSum += Double(rms)
        volumeSumSquares += Double(rms) * Double(rms)
        sampleCount += 1
        zeroCrossingRateSum += zeroCrossingRate
        zeroCrossingRateSumSquares += zeroCrossingRate * zeroCrossingRate
        updateSilenceTracking(level: rms, at: Date())
        lock.unlock()

        return rms
    }

    /// lock保持中に呼ぶ前提の内部処理。
    private func updateSilenceTracking(level: Float, at now: Date) {
        if level < Self.silenceLevelThreshold {
            if !isCurrentlySilent {
                isCurrentlySilent = true
                currentSilenceStartedAt = now
            }
        } else {
            if isCurrentlySilent, let silenceStart = currentSilenceStartedAt {
                let duration = now.timeIntervalSince(silenceStart)
                if duration >= Self.minimumSilenceSegmentDuration {
                    silenceSegmentCount += 1
                    silenceDurationSum += duration
                }
            }
            isCurrentlySilent = false
            currentSilenceStartedAt = nil
        }
    }

    /// 発話確定時に呼び、認識テキストの文字数と合わせてVoiceSignalsを確定させる。
    /// 集計は事前に行われた合計値からのO(1)計算のみのため、確定時に重い処理は発生しない。
    func finalize(recognizedCharacterCount: Int) -> VoiceSignals {
        lock.lock()
        defer { lock.unlock() }

        let duration = Date().timeIntervalSince(startedAt)
        guard sampleCount > 0, duration > 0 else { return .empty }

        let volumeMean = volumeSum / Double(sampleCount)
        let volumeVariance = max(0, volumeSumSquares / Double(sampleCount) - volumeMean * volumeMean)
        let volumeStdDev = sqrt(volumeVariance)

        let zcrMean = zeroCrossingRateSum / Double(sampleCount)
        let zcrVariance = max(0, zeroCrossingRateSumSquares / Double(sampleCount) - zcrMean * zcrMean)
        let zcrStdDev = sqrt(zcrVariance)
        let pitchVariationProxy = zcrMean > 0 ? Float(zcrStdDev / zcrMean) : 0

        return VoiceSignals(
            speechRateCharactersPerSecond: Float(Double(recognizedCharacterCount) / duration),
            averageVolume: Float(volumeMean),
            volumeVariation: Float(volumeStdDev),
            silenceSegmentCount: silenceSegmentCount,
            averageSilenceDuration: silenceSegmentCount > 0 ? Float(silenceDurationSum / Double(silenceSegmentCount)) : 0,
            utteranceDuration: Float(duration),
            pitchVariationProxy: pitchVariationProxy
        )
    }
}
