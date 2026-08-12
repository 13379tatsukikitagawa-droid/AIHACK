import SwiftUI

/// 表情推移グラフで選択・描画できる特徴量の種類。表示名・値の取り出し・色を一箇所にまとめる。
nonisolated enum FaceFeatureKind: String, CaseIterable, Identifiable, Sendable {
    case smile, browRaise, browFurrow, eyeOpenness
    case gazeHorizontal, gazeVertical, jawOpen
    case headYaw, headPitch, headRoll

    var id: String { rawValue }

    var label: String {
        switch self {
        case .smile: return "笑顔"
        case .browRaise: return "眉の上がり"
        case .browFurrow: return "眉のより"
        case .eyeOpenness: return "目の開き"
        case .gazeHorizontal: return "視線(左右)"
        case .gazeVertical: return "視線(上下)"
        case .jawOpen: return "口の開き"
        case .headYaw: return "頭の向き(左右)"
        case .headPitch: return "頭の向き(上下)"
        case .headRoll: return "頭の傾き"
        }
    }

    var range: ClosedRange<Float> {
        switch self {
        case .smile, .browRaise, .browFurrow, .eyeOpenness, .jawOpen:
            return 0...1
        case .gazeHorizontal, .gazeVertical, .headYaw, .headPitch, .headRoll:
            return -1...1
        }
    }

    func value(from signals: FaceSignals) -> Float {
        switch self {
        case .smile: return signals.smile
        case .browRaise: return signals.browRaise
        case .browFurrow: return signals.browFurrow
        case .eyeOpenness: return signals.eyeOpenness
        case .gazeHorizontal: return signals.gazeHorizontal
        case .gazeVertical: return signals.gazeVertical
        case .jawOpen: return signals.jawOpen
        case .headYaw: return signals.headYaw
        case .headPitch: return signals.headPitch
        case .headRoll: return signals.headRoll
        }
    }

    var color: Color {
        switch self {
        case .smile: return .yellow
        case .browRaise: return .orange
        case .browFurrow: return .red
        case .eyeOpenness: return .blue
        case .gazeHorizontal: return .purple
        case .gazeVertical: return .indigo
        case .jawOpen: return .pink
        case .headYaw: return .green
        case .headPitch: return .mint
        case .headRoll: return .teal
        }
    }
}
