import SwiftUI

/// 結果画面。AIの推測と実際に選んだカードを並べて表示し、正解・不正解をアニメーションで表現する。
struct GameResultView: View {
    let prompt: String
    let selectedCard: EmotionCard
    let result: EmotionGuessResult
    let streak: Int
    let onPlayAgain: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didAppearAnimation = false

    private var isCorrect: Bool { selectedCard.id == result.guessedCard.id }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                resultBadge

                Text("お題: 「\(prompt)」")
                    .font(Typography.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: Spacing.lg) {
                    cardColumn(title: "演じた感情", card: selectedCard)

                    Image(systemName: isCorrect ? "equal.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(isCorrect ? .green : .red)

                    cardColumn(title: "AIの推測", card: result.guessedCard)
                }

                reasoningCard

                Button(action: onPlayAgain) {
                    Text("もう一度")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: Layout.minTapTarget)
                        .background(GamePalette.actionGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.sm)
            }
            .padding(Spacing.xl)
        }
        .onAppear {
            guard !reduceMotion else {
                didAppearAnimation = true
                return
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                didAppearAnimation = true
            }
        }
    }

    private var resultBadge: some View {
        VStack(spacing: Spacing.xs) {
            Text(isCorrect ? "🎉 大正解！" : "😵 残念！")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(isCorrect ? .green : .secondary)
                .scaleEffect(didAppearAnimation ? 1.0 : 0.6)
                .rotationEffect(.degrees(!isCorrect && didAppearAnimation && !reduceMotion ? -3 : 0))

            Text("連続正解 \(streak)")
                .font(Typography.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isCorrect ? "大正解。連続正解\(streak)回" : "残念、不正解でした")
    }

    private func cardColumn(title: String, card: EmotionCard) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(title)
                .font(Typography.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: Spacing.xs) {
                Image(systemName: card.systemImage)
                    .font(.system(size: 30))
                Text(card.label)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
            }
            .foregroundStyle(.white)
            .frame(width: 110, height: 110)
            .background(GamePalette.color(forCardID: card.id), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(card.label)")
    }

    private var reasoningCard: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
            Text(result.reasoning)
                .font(Typography.footnote)
                .foregroundStyle(.primary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AIの根拠: \(result.reasoning)")
    }
}

#Preview {
    GameResultView(
        prompt: "え",
        selectedCard: EmotionCard.all[3],
        result: EmotionGuessResult(guessedCard: EmotionCard.all[3], reasoning: "声のトーンが急激に上がったため"),
        streak: 2,
        onPlayAgain: {}
    )
}
