import Foundation

/// 「30秒プレゼン」中の音量（audioLevel）の時系列サンプル1点。声のトーンの推移グラフに使う。
nonisolated struct PresentationVolumeSample: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let level: Float
}
