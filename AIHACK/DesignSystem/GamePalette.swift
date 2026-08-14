import SwiftUI

/// 感情当てゲームモード専用の配色。既存のセマンティックカラー方針（AvatarPalette）とは独立しており、
/// このモードに限り彩度の高い固定色を用いてポップさを表現する。いずれも白文字を乗せた際に
/// ダークモード・ライトモードの両方で十分なコントラストを保てる明度・彩度のみを採用している。
enum GamePalette {
    static func color(forCardID id: String) -> Color {
        switch id {
        case "joy": return Color(red: 1.00, green: 0.72, blue: 0.05)
        case "anger": return Color(red: 0.93, green: 0.24, blue: 0.24)
        case "sadness": return Color(red: 0.20, green: 0.52, blue: 0.94)
        case "surprise": return Color(red: 0.62, green: 0.32, blue: 0.94)
        case "embarrassment": return Color(red: 0.98, green: 0.42, blue: 0.62)
        case "doubt": return Color(red: 0.12, green: 0.68, blue: 0.68)
        case "despair": return Color(red: 0.38, green: 0.30, blue: 0.58)
        case "excitement": return Color(red: 0.98, green: 0.50, blue: 0.10)
        default: return .accentColor
        }
    }

    /// タイトル文字・カウントダウンなどに使う、彩度の高いグラデーション。
    static let titleGradient = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.42, blue: 0.62),
            Color(red: 0.62, green: 0.32, blue: 0.94),
            Color(red: 0.20, green: 0.58, blue: 0.94)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// 「あそぶ」「もう一度」などの主要ボタンに使うグラデーション（はぁって言うゲーム用）。
    static let actionGradient = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.50, blue: 0.10),
            Color(red: 0.98, green: 0.24, blue: 0.42)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 「30秒プレゼン」モードの主要ボタンに使うグラデーション。actionGradientとは色相を変え、
    /// ホーム画面で2つのモードを一目で区別できるようにする。
    static let presentationGradient = LinearGradient(
        colors: [
            Color(red: 0.20, green: 0.58, blue: 0.94),
            Color(red: 0.62, green: 0.32, blue: 0.94)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 「30秒プレゼン」結果画面の3軸（内容・声・表情）バーチャートに使う配色。
    static let presentationContentAxisColor = Color(red: 0.20, green: 0.58, blue: 0.94)
    static let presentationVoiceAxisColor = Color(red: 0.62, green: 0.32, blue: 0.94)
    static let presentationExpressionAxisColor = Color(red: 0.98, green: 0.50, blue: 0.10)
}
