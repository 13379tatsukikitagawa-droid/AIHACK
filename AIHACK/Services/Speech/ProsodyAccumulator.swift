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

    /// 自己相関法でピッチ（基本周波数）を推定する対象範囲。ヒトの発声の実用域をカバーする。
    private static let minPitchHz: Double = 75
    private static let maxPitchHz: Double = 400
    /// このRMSを下回るバッファは無声/無音とみなし、ピッチ推定の対象から除外する。
    private static let voicedRMSThreshold: Float = 0.05
    /// 自己相関のピークが十分に明瞭な場合のみ採用する（ノイズを基本周波数と誤検出しないため）。
    /// 短い発声でも推定値を得やすいよう、やや緩めに設定している。
    private static let minimumAutocorrelationConfidence: Double = 0.18

    private let lock = NSLock()
    private let startedAt = Date()

    private var volumeSum: Double = 0
    private var volumeSumSquares: Double = 0
    private var sampleCount: Int = 0
    private var zeroCrossingRateSum: Double = 0
    private var zeroCrossingRateSumSquares: Double = 0
    private var pitchHzSum: Double = 0
    private var voicedPitchSampleCount: Int = 0

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

        // ロック外の重い演算（自己相関）はロック保持時間を延ばさないよう先に計算しておく。
        let pitchEstimate: Double? = rms >= Self.voicedRMSThreshold
            ? Self.estimatePitchHz(samples: samples, frameLength: frameLength, sampleRate: buffer.format.sampleRate)
            : nil

        lock.lock()
        volumeSum += Double(rms)
        volumeSumSquares += Double(rms) * Double(rms)
        sampleCount += 1
        zeroCrossingRateSum += zeroCrossingRate
        zeroCrossingRateSumSquares += zeroCrossingRate * zeroCrossingRate
        if let pitchEstimate {
            pitchHzSum += pitchEstimate
            voicedPitchSampleCount += 1
        }
        updateSilenceTracking(level: rms, at: Date())
        lock.unlock()

        return rms
    }

    /// 時間領域の自己相関法による、簡易的な基本周波数推定。1バッファ分のみを見る軽量な推定であり、
    /// 音響分析・医療用途の精度は想定しない（あくまでゲームの判定材料としての目安）。
    nonisolated private static func estimatePitchHz(
        samples: UnsafeMutablePointer<Float>,
        frameLength: Int,
        sampleRate: Double
    ) -> Double? {
        guard sampleRate > 0 else { return nil }
        let minLag = Int(sampleRate / maxPitchHz)
        let maxLag = Int(sampleRate / minPitchHz)
        let searchLimit = frameLength - maxLag
        guard minLag >= 1, maxLag > minLag, searchLimit > minLag else { return nil }

        var mean: Float = 0
        for i in 0..<frameLength { mean += samples[i] }
        mean /= Float(frameLength)

        var zeroLagEnergy: Double = 0
        for i in 0..<frameLength {
            let centered = Double(samples[i] - mean)
            zeroLagEnergy += centered * centered
        }
        guard zeroLagEnergy > 0 else { return nil }

        var bestLag = -1
        var bestCorrelation: Double = 0
        for lag in minLag...maxLag {
            var sum: Double = 0
            for i in 0..<searchLimit {
                sum += Double(samples[i] - mean) * Double(samples[i + lag] - mean)
            }
            if sum > bestCorrelation {
                bestCorrelation = sum
                bestLag = lag
            }
        }
        guard bestLag > 0, bestCorrelation / zeroLagEnergy >= minimumAutocorrelationConfidence else { return nil }
        return sampleRate / Double(bestLag)
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
        let averagePitchHz = voicedPitchSampleCount > 0 ? Float(pitchHzSum / Double(voicedPitchSampleCount)) : 0

        return VoiceSignals(
            speechRateCharactersPerSecond: Float(Double(recognizedCharacterCount) / duration),
            averageVolume: Float(volumeMean),
            volumeVariation: Float(volumeStdDev),
            silenceSegmentCount: silenceSegmentCount,
            averageSilenceDuration: silenceSegmentCount > 0 ? Float(silenceDurationSum / Double(silenceSegmentCount)) : 0,
            utteranceDuration: Float(duration),
            pitchVariationProxy: pitchVariationProxy,
            averagePitchHz: averagePitchHz
        )
    }
}
