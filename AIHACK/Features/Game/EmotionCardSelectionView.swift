import SwiftUI

/// 感情カード選択画面。選んだカードはAI側には一切送信しない（ネタバレ防止）。
/// このViewはタップされたカードをクロージャで通知するだけで、判定ロジックには一切関与しない。
struct EmotionCardSelectionView: View {
    let cards: [EmotionCard]
    let onSelect: (EmotionCard) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.md),
        GridItem(.flexible(), spacing: Spacing.md)
    ]

    var body: some View {
        VStack(spacing: Spacing.md) {
            VStack(spacing: Spacing.xs) {
                Text("演じる感情を選ぼう")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.heavy)

                Text("選んだ感情はAIには伝えません。演技だけで伝えよう。")
                    .font(Typography.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }
            .padding(.top, Spacing.md)

            ScrollView {
                LazyVGrid(columns: columns, spacing: Spacing.md) {
                    ForEach(cards) { card in
                        EmotionCardButton(card: card) {
                            onSelect(card)
                        }
                    }
                }
                .padding(Spacing.lg)
            }
        }
    }
}

private struct EmotionCardButton: View {
    let card: EmotionCard
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                Image(systemName: card.systemImage)
                    .font(.system(size: 34))
                Text(card.label)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(GamePalette.color(forCardID: card.id), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(minHeight: Layout.minTapTarget)
        .accessibilityLabel(card.label)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    EmotionCardSelectionView(cards: EmotionCard.all, onSelect: { _ in })
}
