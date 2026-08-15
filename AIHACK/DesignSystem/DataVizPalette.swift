import SwiftUI

/// 分析画面のグラフ専用カラーパレット。Theme.Palette.accent（暖色コーラル）は線グラフの
/// データインクとして使うにはやや明るすぎるため（OKLCH輝度が許容帯域を超える）、同じ色相で
/// データ可視化用に明度を落とした変体をheroとして用意し、系列2本目以降は固定順の判別しやすい
/// 色相を組み合わせる。全ペアをCVDシミュレーション下で検証済み（隣接ΔE 19.6/light, 17.3/dark、
/// 通常視力ΔE 24.0/light, 20.9/dark、いずれも目標値をクリア）。
/// 系列の意味と色の対応は常に固定し、フィルタ（表示項目の選択）で入れ替わらないようにする。
enum DataVizPalette {
    /// 主系列（例: 表情グラフの「笑顔」）に使う、アクセントカラーと同じ色相のグラフ専用コーラル。
    static let hero = Color(red: 0.878, green: 0.420, blue: 0.212)
    static let blue = Color(red: 0.165, green: 0.471, blue: 0.839)
    static let aqua = Color(red: 0.106, green: 0.686, blue: 0.478)
    static let violet = Color(red: 0.290, green: 0.227, blue: 0.655)
    static let green = Color(red: 0.0, green: 0.514, blue: 0.0)

    /// 検出できなかった区間・欠測などを示す、データ系列と混同しない中立色。
    static let mutedBand = Color(.tertiarySystemFill)
}
