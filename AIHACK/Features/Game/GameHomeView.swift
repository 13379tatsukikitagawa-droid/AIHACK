import SwiftUI

/// ゲーム開始画面。アプリのメイン画面（Mirror）とは視覚的に区別し、ポップで遊び心のある
/// デザインにする。2つの遊び方（はぁって言うゲーム／30秒プレゼン）とランキングへの入口を持つ。
struct GameHomeView: View {
    let onPlayEmotionGuess: () -> Void
    let onPlayPresentation: () -> Void
    let onShowLeaderboard: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.sm) {
                Text("ゲームコーナー")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(GamePalette.titleGradient)

                Text("好きなモードを選んでね")
                    .font(Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            VStack(spacing: Spacing.lg) {
                modeCard(
                    title: "はぁって言うゲーム",
                    subtitle: "感情を演じて、AIに当ててもらおう",
                    systemImage: "theatermasks.fill",
                    gradient: GamePalette.actionGradient,
                    action: onPlayEmotionGuess
                )
                modeCard(
                    title: "30秒プレゼン",
                    subtitle: "即興プレゼンをAIが採点",
                    systemImage: "mic.fill",
                    gradient: GamePalette.presentationGradient,
                    action: onPlayPresentation
                )
            }
            .padding(.horizontal, Spacing.xl)

            Button(action: onShowLeaderboard) {
                Label("ランキングを見る", systemImage: "list.number")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
            }
            .frame(minHeight: Layout.minTapTarget)
            .padding(.top, Spacing.xs)

            Spacer()
        }
        .padding(Spacing.xl)
    }

    private func modeCard(
        title: String,
        subtitle: String,
        systemImage: String,
        gradient: LinearGradient,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 30))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.heavy)
                    Text(subtitle)
                        .font(Typography.footnote)
                        .foregroundStyle(Color.white.opacity(0.85))
                }

                Spacer()

                Image(systemName: "chevron.right")
            }
            .foregroundStyle(.white)
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(gradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(minHeight: Layout.minTapTarget)
        .accessibilityLabel("\(title)。\(subtitle)")
    }
}

#Preview {
    GameHomeView(onPlayEmotionGuess: {}, onPlayPresentation: {}, onShowLeaderboard: {})
}
