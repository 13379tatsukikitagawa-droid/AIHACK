import SwiftUI

/// 会話状態に応じたアクセントカラーを一元管理する。
/// StatusIndicatorViewとAvatarViewの双方から参照し、両者の見た目に一貫性を持たせる。
/// いずれもDynamic Type/ダークモードに自動追従するセマンティックカラーのみを用いる。
enum AvatarPalette {
    static func color(for state: ConversationState) -> Color {
        switch state {
        case .idle: return .secondary
        case .listening: return .red
        case .thinking: return .orange
        case .speaking: return .accentColor
        case .error: return .red
        }
    }
}
