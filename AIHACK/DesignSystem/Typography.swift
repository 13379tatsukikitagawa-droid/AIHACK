import SwiftUI

/// Dynamic Typeに対応したテキストスタイルのラッパー。View側は固定ポイント数を指定せず、必ずここを参照する。
enum Typography {
    static let largeTitle: Font = .largeTitle
    static let title: Font = .title
    static let title2: Font = .title2
    static let title3: Font = .title3
    static let headline: Font = .headline
    static let body: Font = .body
    static let callout: Font = .callout
    static let subheadline: Font = .subheadline
    static let footnote: Font = .footnote
    static let caption: Font = .caption
}
