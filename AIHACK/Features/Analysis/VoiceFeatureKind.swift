import SwiftUI

/// 声の推移グラフで選択・描画できる特徴量の種類。表示名・値の取り出し・色を一箇所にまとめる。
/// FaceFeatureKindと同じ構造だが、値の性質上レンジが特徴量ごとに大きく異なる。
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

    var color: Color {
        switch self {
        case .speechRate: return .cyan
        case .averageVolume: return .blue
        case .volumeVariation: return .purple
        case .pitchVariation: return .pink
        }
    }
}
