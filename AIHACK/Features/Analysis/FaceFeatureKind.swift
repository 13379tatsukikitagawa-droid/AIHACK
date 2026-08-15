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

    /// DataVizPaletteの固定色相から割り当てる、特徴量ごとに常に変わらない色。
    /// 同じグループ内で同時に選ばれる項目同士が隣接色にならないよう順序を決めている。
    var color: Color {
        switch self {
        case .smile: return DataVizPalette.hero
        case .browRaise: return DataVizPalette.blue
        case .browFurrow: return DataVizPalette.aqua
        case .eyeOpenness: return DataVizPalette.green
        case .jawOpen: return DataVizPalette.violet
        case .gazeHorizontal: return DataVizPalette.blue
        case .gazeVertical: return DataVizPalette.aqua
        case .headYaw: return DataVizPalette.blue
        case .headPitch: return DataVizPalette.aqua
        case .headRoll: return DataVizPalette.violet
        }
    }

    /// 意味の近い特徴量をまとめたグループ。同じグループ内は必ず同じ値域（range）を共有するため、
    /// 1つのグラフに複数系列を重ねても縦軸の意味がぶれない（表情=0...1、視線・頭の動き=-1...1）。
    enum Group: String, CaseIterable, Identifiable {
        case expression, gaze, head

        var id: String { rawValue }

        var label: String {
            switch self {
            case .expression: return "表情"
            case .gaze: return "視線"
            case .head: return "頭の動き"
            }
        }

        var features: [FaceFeatureKind] {
            switch self {
            case .expression: return [.smile, .browRaise, .browFurrow, .jawOpen, .eyeOpenness]
            case .gaze: return [.gazeHorizontal, .gazeVertical]
            case .head: return [.headYaw, .headPitch, .headRoll]
            }
        }

        /// このグループが共有する値域。グラフのY軸はこの範囲で固定する。
        var sharedRange: ClosedRange<Float> {
            switch self {
            case .expression: return 0...1
            case .gaze, .head: return -1...1
            }
        }
    }
}
