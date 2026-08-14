import SwiftUI

/// 結果画面。合計点を大きく表示し、3軸をバーチャートで視覚化する。ランキング登録は任意。
struct PresentationResultView: View {
    let prompt: String
    let result: PresentationScoreResult
    let onPlayAgain: () -> Void
    let onRegister: (String) -> Void
    let onShowLeaderboard: () -> Void

    @State private var showingNicknameSheet = false
    @State private var hasRegistered = false
    @State private var didAppearAnimation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                totalScoreView

                Text("お題: 「\(prompt)」")
                    .font(Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)

                ScoreBarsView(result: result)
                    .padding(.horizontal, Spacing.xl)

                actionButtons
            }
            .padding(.vertical, Spacing.xl)
        }
        .onAppear {
            guard !reduceMotion else {
                didAppearAnimation = true
                return
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                didAppearAnimation = true
            }
        }
        .sheet(isPresented: $showingNicknameSheet) {
            NicknameEntrySheet(
                onSubmit: { nickname in
                    onRegister(nickname)
                    hasRegistered = true
                },
                onSkip: {}
            )
        }
    }

    private var totalScoreView: some View {
        VStack(spacing: Spacing.xs) {
            Text("\(result.total)")
                .font(.system(size: 88, weight: .heavy, design: .rounded))
                .foregroundStyle(GamePalette.titleGradient)
                .scaleEffect(didAppearAnimation ? 1 : 0.7)
                .minimumScaleFactor(0.5)
            Text("/ 300点")
                .font(Typography.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("合計\(result.total)点、300点満点")
    }

    private var actionButtons: some View {
        VStack(spacing: Spacing.sm) {
            if hasRegistered {
                Label("ランキングに登録しました", systemImage: "checkmark.circle.fill")
                    .font(Typography.footnote)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)

                Button(action: onShowLeaderboard) {
                    Text("ランキングを見る")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: Layout.minTapTarget)
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    showingNicknameSheet = true
                } label: {
                    Text("ランキングに登録する")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.heavy)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: Layout.minTapTarget)
                        .background(GamePalette.presentationGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Button(action: onPlayAgain) {
                Text("もう一度")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: Layout.minTapTarget)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.sm)
    }
}

/// 3軸（内容・声・表情）をCanvasで描いた横棒グラフ。外部ライブラリは使わない。
private struct ScoreBarsView: View {
    let result: PresentationScoreResult

    private var axes: [(label: String, axis: PresentationAxisScore, color: Color)] {
        [
            ("内容", result.content, GamePalette.presentationContentAxisColor),
            ("声", result.voice, GamePalette.presentationVoiceAxisColor),
            ("表情", result.expression, GamePalette.presentationExpressionAxisColor)
        ]
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            ForEach(axes, id: \.label) { entry in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(entry.label)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                        Spacer()
                        Text("\(entry.axis.score)")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.heavy)
                            .monospacedDigit()
                            .foregroundStyle(entry.color)
                    }

                    Canvas { context, size in
                        let track = RoundedRectangle(cornerRadius: 8, style: .continuous).path(in: CGRect(origin: .zero, size: size))
                        context.fill(track, with: .color(Color.secondary.opacity(0.15)))

                        let fillWidth = size.width * CGFloat(entry.axis.score) / 100
                        guard fillWidth > 0 else { return }
                        let fillRect = CGRect(x: 0, y: 0, width: fillWidth, height: size.height)
                        let fill = RoundedRectangle(cornerRadius: 8, style: .continuous).path(in: fillRect)
                        context.fill(fill, with: .color(entry.color))
                    }
                    .frame(height: 18)
                    .accessibilityHidden(true)

                    Text(entry.axis.comment)
                        .font(Typography.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(entry.label)、\(entry.axis.score)点。\(entry.axis.comment)")
            }
        }
    }
}

private struct NicknameEntrySheet: View {
    let onSubmit: (String) -> Void
    let onSkip: () -> Void

    @State private var nickname = ""
    @Environment(\.dismiss) private var dismiss

    private var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                Spacer(minLength: Spacing.lg)

                VStack(spacing: Spacing.xs) {
                    Text("ニックネームを入力してください")
                        .font(.system(.headline, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text("本名や個人を特定できる情報は入力しないでください。端末内にのみ保存されます。")
                        .font(Typography.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)
                }

                TextField("ニックネーム", text: $nickname)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, Spacing.xl)
                    .submitLabel(.done)

                Button {
                    onSubmit(trimmedNickname)
                    dismiss()
                } label: {
                    Text("登録する")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.heavy)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: Layout.minTapTarget)
                        .background(GamePalette.presentationGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(trimmedNickname.isEmpty)
                .padding(.horizontal, Spacing.xl)

                Button("登録せずに閉じる") {
                    onSkip()
                    dismiss()
                }
                .frame(minHeight: Layout.minTapTarget)

                Spacer()
            }
            .padding(.top, Spacing.lg)
            .navigationTitle("ランキング登録")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    PresentationResultView(
        prompt: "このアプリの魅力を売り込んでください",
        result: PresentationScoreResult(
            content: PresentationAxisScore(score: 82, comment: "具体例を交えて説得力がありました"),
            voice: PresentationAxisScore(score: 74, comment: "間の取り方が自然でした"),
            expression: PresentationAxisScore(score: 65, comment: "表情の変化がもう少しあると良いです")
        ),
        onPlayAgain: {},
        onRegister: { _ in },
        onShowLeaderboard: {}
    )
}
