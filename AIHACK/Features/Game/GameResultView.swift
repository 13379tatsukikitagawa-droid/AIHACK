import SwiftUI
import Charts

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

                if !result.keyObservations.isEmpty {
                    keyObservationsCard
                }

                if !result.cardScores.isEmpty {
                    confidenceChartCard
                }

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

    private var keyObservationsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("決め手になった観測", systemImage: "eye.fill")
                .font(Typography.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(result.keyObservations, id: \.self) { observation in
                HStack(alignment: .top, spacing: Spacing.xs) {
                    Circle()
                        .fill(GamePalette.color(forCardID: result.guessedCard.id))
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    Text(observation)
                        .font(Typography.footnote)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("決め手になった観測: \(result.keyObservations.joined(separator: "、"))")
    }

    private var confidenceChartCard: some View {
        let entries = EmotionCard.all
            .map { card in ConfidenceEntry(card: card, score: result.cardScores[card.id] ?? 0) }
            .sorted { $0.score > $1.score }

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("AIの確信度", systemImage: "chart.bar.fill")
                .font(Typography.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Chart(entries) { entry in
                BarMark(
                    x: .value("確信度", entry.score),
                    y: .value("感情", entry.card.label)
                )
                .foregroundStyle(GamePalette.color(forCardID: entry.card.id))
                .cornerRadius(4)
                .annotation(position: .trailing, alignment: .leading) {
                    HStack(spacing: 2) {
                        if entry.card.id == selectedCard.id {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 11))
                        }
                        Text("\(entry.score)")
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .chartXScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(Typography.caption)
                                .fontWeight(entries.first(where: { $0.card.label == label })?.card.id == selectedCard.id ? .bold : .regular)
                        }
                    }
                }
            }
            .frame(height: CGFloat(entries.count) * 30 + 8)

            if selectedCard.id != result.guessedCard.id {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 11))
                    Text("が実際に演じた感情")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityLabel(
            "AIの確信度: " + entries.map { "\($0.card.label) \($0.score)点" }.joined(separator: "、")
        )
    }

    private struct ConfidenceEntry: Identifiable {
        let card: EmotionCard
        let score: Int
        var id: String { card.id }
    }
}

#Preview {
    GameResultView(
        prompt: "え",
        selectedCard: EmotionCard.all[3],
        result: EmotionGuessResult(
            guessedCard: EmotionCard.all[3],
            reasoning: "声のトーンが急激に上がり、発声も短く鋭かったため",
            keyObservations: ["眉が上がっている", "声が高め", "発声が短く鋭い"],
            cardScores: [
                "joy": 20, "anger": 10, "sadness": 2, "surprise": 78,
                "embarrassment": 5, "doubt": 8, "despair": 1, "excitement": 45
            ]
        ),
        streak: 2,
        onPlayAgain: {}
    )
}
