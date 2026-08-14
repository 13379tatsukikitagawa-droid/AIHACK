import Foundation

/// 「30秒プレゼン」モード専用のタイミング調整値。GameTuning.swift（はぁって言うゲーム用）とは
/// 完全に独立して管理する。
enum PresentationTuning {
    /// 準備時間（秒）
    static let preparationSeconds = 5
    /// 本番のプレゼン時間（秒）
    static let presentationSeconds = 30
}
