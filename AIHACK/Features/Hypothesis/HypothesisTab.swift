import SwiftUI

// MARK: - タブ4: 仮説

struct HypothesisTab: View {
    let sessionLog: SessionLog
    let store: HypothesisStore
    let onJumpToTurn: (Int) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                privacyNotice
                generateButton
                content
            }
            .padding(Spacing.lg)
        }
    }

    private var privacyNotice: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "lightbulb")
                .foregroundStyle(.secondary)
            Text("これまでの会話・表情の記録から、反証可能な仮説をAIが生成します。断定ではなく可能性の提示であり、生成結果はこの端末のメモリ上にのみ保持されます。")
                .font(Typography.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
    }

    private var generateButton: some View {
        Button {
            store.generate()
        } label: {
            HStack(spacing: Spacing.sm) {
                if store.generationState == .generating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(buttonLabel)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: Layout.minTapTarget)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!store.canGenerate)
        .accessibilityLabel(buttonLabel)
    }

    private var buttonLabel: String {
        if store.generationState == .generating {
            return "生成中…"
        }
        return store.hypotheses.isEmpty ? "仮説を生成" : "仮説を再生成"
    }

    @ViewBuilder
    private var content: some View {
        switch store.generationState {
        case .idle:
            emptyState
        case .generating:
            if store.hypotheses.isEmpty {
                generatingState
            }
        case .ready:
            hypothesisList
        case .insufficientObservation(let note):
            insufficientObservationView(note)
        case .failed(let message):
            errorView(message)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "まだ仮説がありません",
            systemImage: "lightbulb",
            description: Text(sessionLog.turns.isEmpty
                ? "会話を始めると、仮説を生成できるようになります。"
                : "「仮説を生成」をタップすると、これまでの会話・表情の記録から仮説を生成します。")
        )
    }

    private var generatingState: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
            Text("セッションの記録を分析しています…")
                .font(Typography.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xl)
    }

    private func insufficientObservationView(_ note: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text(note)
                .font(Typography.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
    }

    private func errorView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "xmark.octagon.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(Typography.footnote)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
    }

    private var hypothesisList: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(store.hypotheses) { hypothesis in
                HypothesisCard(
                    hypothesis: hypothesis,
                    onJumpToTurn: onJumpToTurn,
                    onFeedback: { feedback in store.setFeedback(feedback, for: hypothesis.id) }
                )
            }
        }
    }
}

private struct ConfidenceIndicator: View {
    let level: ConfidenceLevel

    var body: some View {
        HStack(spacing: Spacing.xs) {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index < filledCount ? color : Color(.tertiarySystemFill))
                        .frame(width: 20, height: 6)
                }
            }
            Text("確からしさ: \(label)")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("確からしさ: \(label)")
    }

    private var filledCount: Int {
        switch level {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }

    private var label: String {
        switch level {
        case .low: return "低い"
        case .medium: return "中程度"
        case .high: return "高い"
        }
    }

    private var color: Color {
        switch level {
        case .low: return .secondary
        case .medium: return .orange
        case .high: return .accentColor
        }
    }
}

private struct HypothesisCard: View {
    let hypothesis: Hypothesis
    let onJumpToTurn: (Int) -> Void
    let onFeedback: (HypothesisFeedback) -> Void

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(hypothesis.claim)
                .font(Typography.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            ConfidenceIndicator(level: hypothesis.confidence)

            if let suggestedQuestion = hypothesis.suggestedQuestion {
                suggestedQuestionCallout(suggestedQuestion)
            }

            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Text(isExpanded ? "詳細を隠す" : "根拠・論拠・反論を見る")
                }
                .font(Typography.caption)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(minHeight: Layout.minTapTarget, alignment: .leading)
            .accessibilityLabel(isExpanded ? "詳細を隠す" : "根拠・論拠・反論を見る")

            if isExpanded {
                details
            }

            feedbackControls
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous)
                .strokeBorder(Color(.separator), lineWidth: 0.5)
        )
    }

    private func suggestedQuestionCallout(_ question: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "questionmark.bubble.fill")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("聞いてみるなら")
                    .font(Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(question)
                    .font(Typography.footnote)
                    .foregroundStyle(.primary)
            }
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var details: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            detailSection(label: "根拠", value: hypothesis.grounds)
            if !hypothesis.referencedTurnIndexes.isEmpty {
                jumpButtons
            }
            detailSection(label: "論拠", value: hypothesis.warrant)
            detailSection(label: "確からしさの根拠", value: hypothesis.qualifier)
            detailSection(label: "この仮説が成り立たない場合", value: hypothesis.rebuttal)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
    }

    private func detailSection(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Typography.footnote)
        }
    }

    private var jumpButtons: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(hypothesis.referencedTurnIndexes, id: \.self) { index in
                Button {
                    onJumpToTurn(index)
                } label: {
                    Label("発話\(index)を見る", systemImage: "arrow.up.right.square")
                        .font(Typography.caption)
                }
                .buttonStyle(.bordered)
                .frame(minHeight: Layout.minTapTarget)
            }
        }
    }

    private var feedbackControls: some View {
        HStack(spacing: Spacing.sm) {
            feedbackButton(.confirmed, label: "当たっている", icon: "checkmark.circle", tint: .green)
            feedbackButton(.rejected, label: "外れている", icon: "xmark.circle", tint: .red)
            Spacer()
        }
    }

    private func feedbackButton(_ feedback: HypothesisFeedback, label: String, icon: String, tint: Color) -> some View {
        let isSelected = hypothesis.feedback == feedback
        return Button {
            onFeedback(feedback)
        } label: {
            Label(label, systemImage: isSelected ? "\(icon).fill" : icon)
                .font(Typography.caption)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? tint : .secondary)
        .frame(minHeight: Layout.minTapTarget)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    let log = SessionLog()
    return HypothesisTab(
        sessionLog: log,
        store: HypothesisStore(llmService: OrcaRouterService(), sessionLog: log, memoryStore: MemoryStore(llmService: OrcaRouterService())),
        onJumpToTurn: { _ in }
    )
}

#Preview("仮説カード（実出力例）") {
    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HypothesisCard(
                hypothesis: Hypothesis(HypothesisContent(
                    claim: "プレゼン資料の未完了による緊張や焦りが、AIとの対話を通じて軽減された可能性がある。",
                    grounds: "発話0で「資料まだ終わってなくて」と発話した際は眉が寄っていたが、発話2で「ありがとう、ちょっと落ち着いた」と発話した際は口角がはっきり上がっている。",
                    warrant: "眉が寄る状態から口角が上がる状態へ表情が遷移しており、発話内容でも「落ち着いた」と述べているため、対話の過程で何らかの心理的変化が起きたと考えられる。",
                    qualifier: "表情の変化や発話内容が、AIの応答によるものか、単に時間の経過やタスクの整理による自己解決の結果であるかは区別できない。",
                    rebuttal: "発話1の時点で既にスライドの進捗を把握して見通しが立ち、その時点で緊張が緩和されていた可能性がある。",
                    confidence: .medium,
                    referencedTurnIndexes: [0, 1, 2],
                    suggestedQuestion: nil
                )),
                onJumpToTurn: { _ in },
                onFeedback: { _ in }
            )
            HypothesisCard(
                hypothesis: Hypothesis(HypothesisContent(
                    claim: "ユーザーは明日のプレゼンに向けたコンディション調整のために、適切な睡眠時間を求めている可能性がある。",
                    grounds: "発話3で「今日は何時に寝ればいいと思う？」と質問している。",
                    warrant: "明日がプレゼンという重要なイベントであり、資料作成が遅れている状況から、当日のパフォーマンスを維持するための体調管理に関心を持っていると考えられる。",
                    qualifier: "単に就寝時間の目安がわからず質問しているだけである可能性や、逆に睡眠時間を削ってでも資料を終わらせるべきか迷っている可能性も排除できない。",
                    rebuttal: "資料作成を優先するためにあえて遅い時間を尋ねている、あるいは単なる雑談としての質問である可能性がある。",
                    confidence: .low,
                    referencedTurnIndexes: [3],
                    suggestedQuestion: "決めつけているわけではありませんが、最近体調管理を意識されていたりしますか？"
                )),
                onJumpToTurn: { _ in },
                onFeedback: { _ in }
            )
        }
        .padding(Spacing.lg)
    }
}
