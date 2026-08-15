import SwiftUI
import Charts

/// 結果画面。合計点を大きく表示し、3軸をバーチャートで視覚化する。ランキング登録は任意。
struct PresentationResultView: View {
    let prompt: String
    let result: PresentationScoreResult
    let faceTimeline: [FaceSignalSample]
    let volumeTimeline: [PresentationVolumeSample]
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

                contentFeedbackCard
                    .padding(.horizontal, Spacing.xl)

                recommendedStructureCard
                    .padding(.horizontal, Spacing.xl)

                if !faceTimeline.isEmpty || !volumeTimeline.isEmpty {
                    PresentationTimelineCharts(faceTimeline: faceTimeline, volumeTimeline: volumeTimeline)
                        .padding(.horizontal, Spacing.xl)
                }

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

    private var contentFeedbackCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("内容へのフィードバック", systemImage: "text.bubble.fill")
                .font(Typography.footnote)
                .fontWeight(.bold)
                .foregroundStyle(GamePalette.presentationContentAxisColor)

            Text(result.contentFeedback)
                .font(Typography.footnote)
                .foregroundStyle(.primary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("内容へのフィードバック: \(result.contentFeedback)")
    }

    private var recommendedStructureCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("次に活かせるおすすめの構成", systemImage: "list.number")
                .font(Typography.footnote)
                .fontWeight(.bold)
                .foregroundStyle(GamePalette.presentationGradient)

            ForEach(Array(result.recommendedStructure.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Text("\(index + 1)")
                        .font(Typography.caption)
                        .fontWeight(.heavy)
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(GamePalette.presentationGradient, in: Circle())
                    Text(step)
                        .font(Typography.footnote)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("次に活かせるおすすめの構成: " + result.recommendedStructure.joined(separator: "、"))
    }
}

/// 本番中の「表情の推移」「音量の推移」を折れ線グラフで見せる。連続的に記録できるこの2つに絞り、
/// 発話速度など事後にしか集計できない指標は含めない。
private struct PresentationTimelineCharts: View {
    let faceTimeline: [FaceSignalSample]
    let volumeTimeline: [PresentationVolumeSample]

    private var sharedRange: ClosedRange<Date> {
        var timestamps: [Date] = []
        timestamps += faceTimeline.map(\.timestamp)
        timestamps += volumeTimeline.map(\.timestamp)
        guard let minDate = timestamps.min(), let maxDate = timestamps.max(), minDate < maxDate else {
            let now = Date()
            return now.addingTimeInterval(-1)...now
        }
        return minDate...maxDate
    }

    private func expressiveness(of signals: FaceSignals) -> Float {
        (signals.smile + signals.browRaise + signals.browFurrow + signals.jawOpen) / 4
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            if !faceTimeline.isEmpty {
                timelineCard(
                    title: "表情の推移",
                    icon: "face.smiling.fill",
                    color: GamePalette.presentationExpressionAxisColor
                ) {
                    Chart(faceTimeline) { sample in
                        AreaMark(
                            x: .value("時刻", sample.timestamp),
                            y: .value("表情の動き", expressiveness(of: sample.signals))
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    GamePalette.presentationExpressionAxisColor.opacity(0.3),
                                    GamePalette.presentationExpressionAxisColor.opacity(0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        LineMark(
                            x: .value("時刻", sample.timestamp),
                            y: .value("表情の動き", expressiveness(of: sample.signals))
                        )
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(GamePalette.presentationExpressionAxisColor)
                    }
                    .chartYScale(domain: 0...1)
                    .chartXScale(domain: sharedRange)
                }
            }

            if !volumeTimeline.isEmpty {
                timelineCard(
                    title: "声の音量の推移",
                    icon: "waveform",
                    color: GamePalette.presentationVoiceAxisColor
                ) {
                    Chart(volumeTimeline) { sample in
                        AreaMark(
                            x: .value("時刻", sample.timestamp),
                            y: .value("音量", sample.level)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    GamePalette.presentationVoiceAxisColor.opacity(0.3),
                                    GamePalette.presentationVoiceAxisColor.opacity(0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        LineMark(
                            x: .value("時刻", sample.timestamp),
                            y: .value("音量", sample.level)
                        )
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(GamePalette.presentationVoiceAxisColor)
                    }
                    .chartYScale(domain: 0...1)
                    .chartXScale(domain: sharedRange)
                }
            }
        }
    }

    @ViewBuilder
    private func timelineCard<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder chart: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(title, systemImage: icon)
                .font(Typography.footnote)
                .fontWeight(.bold)
                .foregroundStyle(color)

            chart()
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                        AxisValueLabel(format: .dateTime.second())
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 100)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityHidden(true)
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
    let start = Date().addingTimeInterval(-30)
    let faceTimeline: [FaceSignalSample] = (0..<60).map { i in
        let t = start.addingTimeInterval(Double(i) * 0.5)
        let phase = Double(i) / 8
        return FaceSignalSample(
            timestamp: t,
            signals: FaceSignals(
                isFaceDetected: true,
                smile: Float(0.4 + 0.35 * sin(phase)),
                browRaise: Float(0.2 + 0.15 * sin(phase * 1.4)),
                browFurrow: 0.05,
                eyeOpenness: 0.9,
                gazeHorizontal: 0,
                gazeVertical: 0,
                jawOpen: Float(max(0, 0.2 * sin(phase * 2))),
                headYaw: 0, headPitch: 0, headRoll: 0
            )
        )
    }
    let volumeTimeline: [PresentationVolumeSample] = (0..<60).map { i in
        let t = start.addingTimeInterval(Double(i) * 0.5)
        let phase = Double(i) / 6
        return PresentationVolumeSample(timestamp: t, level: Float(0.35 + 0.25 * sin(phase)))
    }
    return PresentationResultView(
        prompt: "このアプリの魅力を売り込んでください",
        result: PresentationScoreResult(
            content: PresentationAxisScore(score: 82, comment: "具体例を交えて説得力がありました"),
            voice: PresentationAxisScore(score: 74, comment: "間の取り方が自然でした"),
            expression: PresentationAxisScore(score: 65, comment: "表情の変化がもう少しあると良いです"),
            contentFeedback: "アプリの操作感の良さに触れられていたのは良い点です。一方で、他アプリと比べた際の具体的な優位性（差別化ポイント）まで踏み込めるとさらに説得力が増します。",
            recommendedStructure: [
                "最初に結論（一番伝えたい魅力）を一言で述べる",
                "その根拠となる具体的な機能やエピソードを1つ挙げる",
                "他との違いが伝わる比較や数字を添える",
                "最後にもう一度結論を繰り返して締める"
            ]
        ),
        faceTimeline: faceTimeline,
        volumeTimeline: volumeTimeline,
        onPlayAgain: {},
        onRegister: { _ in },
        onShowLeaderboard: {}
    )
}
