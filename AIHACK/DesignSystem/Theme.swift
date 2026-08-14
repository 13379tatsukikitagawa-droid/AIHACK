import SwiftUI

/// Mirror（会話・設定・履歴・メモ・仮説など、アプリ本体の全機能）の世界観を一箇所で定義する。
/// このファイルが定義する範囲は「Mirror本体」のみ。ゲームモード（Features/Game,
/// DesignSystem/GamePalette）は意図的にこのテーマの対象外とし、既存のポップな配色のまま
/// 対比を保つ（GamePalette.swiftは変更しない）。
///
/// コンセプト: 「静かな観察者」。
/// 派手な主張をせず、余白と間で語る。断定しないAIの人格を、UIそのものが体現する。
///
/// 原則:
/// - 情報は常に必要最小限しか画面に出さない。多くを語らず、深く聞くという人格をUIで表現する。
/// - 色は基本的にモノトーン＋アクセント1色（Theme.Palette.accent = 既存のaccentColor）のみを
///   軸とする。装飾目的の複数色使用は行わない（ゲームモードを除く）。
/// - 角は自然な曲率（continuous）で統一し、鋭い直角を極力避ける（Theme.Radius.shape(_:)を使う）。
/// - コントラストは強すぎず、階層は色ではなく余白（Spacing）とタイポグラフィのウェイト
///   （Theme.Weight）で作る。
/// - 枠線・影はできる限り使わず、背景色の差（Theme.Palette.surface / surfaceElevated）だけで
///   領域を認識できるようにする。どうしても罫線が必要な場合のみTheme.Palette.dividerを使う。
enum Theme {
    /// このテーマを一言で表す識別子。UI文言としては使わず、設計意図の参照用。
    static let concept = "静かな観察者"

    /// 画面の基調となる配色。すべてセマンティックカラーの上に成り立っており、
    /// ダークモード・ライトモードの双方に自動追従する。新しい色相をここに追加しないこと。
    enum Palette {
        /// 画面の基調背景。
        static let background = Color(.systemBackground)
        /// カード・入力欄・リスト行など、背景から一段区別したい領域。
        /// 枠線ではなく、この背景差だけで領域を示す。
        static let surface = Color(.secondarySystemBackground)
        /// surfaceのさらに内側（ネストした情報、展開表示の中身など）に使う、もう一段の区別。
        static let surfaceElevated = Color(.tertiarySystemBackground)
        /// 本文・見出しの文字色。
        static let textPrimary = Color.primary
        /// 補足・キャプション・非アクティブ状態の文字色。
        static let textSecondary = Color.secondary
        /// どうしても罫線が必要な場合にのみ使う、ごく控えめな区切り線色。
        /// 多用せず、まずは余白とsurfaceの背景差で階層を作ることを優先する。
        static let divider = Color.primary.opacity(0.08)
        /// アプリ全体で唯一のアクセント。既存のaccentColorをそのまま参照する。
        /// 新しい色相を追加しないこと（ゲームモードを除く）。
        static let accent = Color.accentColor
    }

    /// 自然な曲率（continuous）に統一した角丸のスケール。個々の画面でRoundedRectangleの
    /// cornerRadius/styleを直接指定せず、Theme.Radius.shape(_:)を経由することで、
    /// styleの指定漏れ（鋭い角の混入）を構造的に防ぐ。
    enum Radius {
        /// タグ・バッジ・小さな操作領域。
        static let small: CGFloat = 12
        /// ボタン・入力欄・バナーなど、主要な操作要素。
        static let medium: CGFloat = 18
        /// カード・シート・展開表示など、大きめのコンテナ。
        static let large: CGFloat = 24

        static func shape(_ radius: CGFloat) -> RoundedRectangle {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
        }
    }

    /// タイポグラフィのウェイト方針。既存のTypography（フォントサイズ）と組み合わせて使う。
    /// 全体として控えめな太さに統一し、bold/heavyの多用を避ける。
    enum Weight {
        /// 本文・キャプションなど、大部分のテキストに使う基準ウェイト。
        static let body: Font.Weight = .regular
        /// 見出し・強調に使う、太字を避けた控えめな強調ウェイト。
        static let emphasis: Font.Weight = .medium
        /// エラー表示や強い警告など、本当に必要な場面に限定して使う太字。多用しないこと。
        static let strong: Font.Weight = .semibold
    }

    /// 行間・字間の基準値。詰まった印象を避け、余白で階層を作るために使う。
    enum Text {
        /// 本文・キャプションに使う、ゆとりのある行間。
        static let lineSpacing: CGFloat = 4
        /// 見出しなど、字間にわずかな余裕を持たせたい場面で使うtracking。
        static let headingTracking: CGFloat = 0.2
    }

    /// 画面遷移・要素の出現アニメーションの共通カーブ。アバターの呼吸
    /// （sin波によるなめらかな緩急）と同じ「急がず、なめらかに減速する」性質に統一する。
    /// バラバラなdurationやイージングを画面ごとに指定せず、必ずここを経由する。
    enum Motion {
        /// 通常の出現・状態変化に使う基準カーブ。
        static let gentle: Animation = .easeOut(duration: 0.45)
        /// 画面トーンの変化など、より緩やかに移り変える場面用。
        static let settle: Animation = .easeInOut(duration: 0.6)
        /// カード・要素の出現に使う、跳ねのない控えめなスプリング。
        static let entrance: Animation = .spring(response: 0.5, dampingFraction: 0.86)

        /// 要素の出現・消失に使う共通トランジション。派手なスライド・回転は用いず、
        /// わずかな拡大縮小とフェードのみで「静かに現れ、静かに消える」印象を統一する。
        static let transition: AnyTransition = .opacity.combined(with: .scale(scale: 0.97))

        /// Reduce Motion有効時はnilを返す。`.animation(reduceMotion ? nil : ..., value:)`という
        /// 分岐の書き方が画面ごとにバラつくことを防ぐための共通ヘルパー。
        static func animation(_ base: Animation, reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : base
        }
    }
}
