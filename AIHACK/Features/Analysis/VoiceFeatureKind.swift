import SwiftUI

/// 声の推移グラフで選択・描画できる特徴量の種類。表示名・値の取り出し・単位を一箇所にまとめる。
/// FaceFeatureKindと同じ構造だが、値の性質上レンジが特徴量ごとに大きく異なるため、
/// 1つのグラフに重ねず、特徴量ごとに独立した小さなグラフ（スモールマルチプル）として表示する。
nonisolated enum VoiceFeatureKind: String, CaseIterable, Identifiable, Sendable {
    case speechRate, averageVolume, volumeVariation, pitchVariation

    var id: String { rawValue }

    var label: String {
        switch self {
        case .speechRate: return "発話速度"
        case .averageVolume: return "音量"
        case .volumeVariation: return "音量の変動"
        case .pitchVariation: return "声の高さの変化"
        }
    }

    var icon: String {
        switch self {
        case .speechRate: return "gauge.with.dots.needle.50percent"
        case .averageVolume: return "speaker.wave.2.fill"
        case .volumeVariation: return "waveform.path"
        case .pitchVariation: return "waveform"
        }
    }

    /// 表示上の目安レンジ（実測値が上回ることもあるため、描画時は必要に応じてクランプする）
    var range: ClosedRange<Float> {
        switch self {
        case .speechRate: return 0...12
        case .averageVolume: return 0...1
        case .volumeVariation: return 0...0.5
        case .pitchVariation: return 0...1.5
        }
    }

    func value(from signals: VoiceSignals) -> Float {
        switch self {
        case .speechRate: return signals.speechRateCharactersPerSecond
        case .averageVolume: return signals.averageVolume
        case .volumeVariation: return signals.volumeVariation
        case .pitchVariation: return signals.pitchVariationProxy
        }
    }

    /// 平均値の表示に使う書式（値 + 単位）。
    func formattedValue(_ value: Float) -> String {
        switch self {
        case .speechRate: return String(format: "%.1f 文字/秒", value)
        case .averageVolume: return String(format: "%.0f%%", value * 100)
        case .volumeVariation: return String(format: "%.2f", value)
        case .pitchVariation: return String(format: "%.2f", value)
        }
    }

    /// 単独カードで使うため、系列間の判別色ではなく共通のブランドカラーを使う。
    var color: Color { DataVizPalette.hero }
}
