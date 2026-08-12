import SwiftUI

// MARK: - タブ2: 表情・声の推移

struct FaceTimelineTab: View {
    let sessionLog: SessionLog

    @State private var selectedFaceFeatures: Set<FaceFeatureKind> = [.smile, .browRaise]
    @State private var selectedVoiceFeatures: Set<VoiceFeatureKind> = [.speechRate, .averageVolume]

    var body: some View {
        if sessionLog.faceSignalSamples.isEmpty && sessionLog.voiceSignalSamples.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if !sessionLog.faceSignalSamples.isEmpty {
                        Text("表情")
                            .font(Typography.headline)
                        faceFeatureToggles
                        FaceTimelineChart(
                            samples: sessionLog.faceSignalSamples,
                            turns: sessionLog.turns,
                            selectedFeatures: selectedFaceFeatures,
                            range: sharedTimeRange
                        )
                        legendNote
                        detectionSummary
                    }

                    if !sessionLog.voiceSignalSamples.isEmpty {
                        Divider()
                        Text("声")
                            .font(Typography.headline)
                        Text("音声入力の発話ごとに1点を記録するため、表情ほど連続的ではありません。")
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                        voiceFeatureToggles
                        VoiceTimelineChart(
                            samples: sessionLog.voiceSignalSamples,
                            turns: sessionLog.turns,
                            selectedFeatures: selectedVoiceFeatures,
                            range: sharedTimeRange
                        )
                        voiceSummary
                    }

                    timeAxisFooter
                }
                .padding(Spacing.lg)
            }
        }
    }

    /// 表情・声の両方のグラフで同じ時間軸を使うことで、同じ時刻の変化を見比べられるようにする。
    private var sharedTimeRange: ClosedRange<Date> {
        var timestamps: [Date] = []
        timestamps += sessionLog.faceSignalSamples.map(\.timestamp)
        timestamps += sessionLog.voiceSignalSamples.map(\.timestamp)
        timestamps += sessionLog.turns.map(\.timestamp)
        guard let minDate = timestamps.min(), let maxDate = timestamps.max(), minDate < maxDate else {
            let now = Date()
            return now.addingTimeInterval(-1)...now
        }
        return minDate...maxDate
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "まだ記録がありません",
            systemImage: "chart.xyaxis.line",
            description: Text("カメラを有効にする、または音声で会話すると、表情・声の推移がここに表示されます。")
        )
    }

    private var faceFeatureToggles: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("表示する項目")
                .font(Typography.subheadline)
                .fontWeight(.semibold)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: Spacing.sm)], alignment: .leading, spacing: Spacing.sm) {
                ForEach(FaceFeatureKind.allCases) { feature in
                    featureToggleChip(
                        label: feature.label,
                        color: feature.color,
                        isSelected: selectedFaceFeatures.contains(feature)
                    ) {
                        if selectedFaceFeatures.contains(feature) {
                            selectedFaceFeatures.remove(feature)
                        } else {
                            selectedFaceFeatures.insert(feature)
                        }
                    }
                }
            }
        }
    }

    private var voiceFeatureToggles: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("表示する項目")
                .font(Typography.subheadline)
                .fontWeight(.semibold)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: Spacing.sm)], alignment: .leading, spacing: Spacing.sm) {
                ForEach(VoiceFeatureKind.allCases) { feature in
                    featureToggleChip(
                        label: feature.label,
                        color: feature.color,
                        isSelected: selectedVoiceFeatures.contains(feature)
                    ) {
                        if selectedVoiceFeatures.contains(feature) {
                            selectedVoiceFeatures.remove(feature)
                        } else {
                            selectedVoiceFeatures.insert(feature)
                        }
                    }
                }
            }
        }
    }

    private func featureToggleChip(label: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(Typography.caption)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, Spacing.sm)
            .frame(minHeight: Layout.minTapTarget)
            .background(isSelected ? color.opacity(0.2) : Color(.secondarySystemBackground), in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? color : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var timeAxisFooter: some View {
        Group {
            let range = sharedTimeRange
            HStack {
                Text(range.lowerBound, style: .time)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(range.upperBound, style: .time)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var legendNote: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Circle().fill(Color.blue).frame(width: 8, height: 8)
                Text("テキスト入力の発話")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: Spacing.xs) {
                Circle().fill(Color.red).frame(width: 8, height: 8)
                Text("音声入力の発話")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: Spacing.xs) {
                RoundedRectangle(cornerRadius: 2).fill(Color(.tertiarySystemFill)).frame(width: 14, height: 8)
                Text("顔が検出されていなかった区間")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var detectionSummary: some View {
        let total = sessionLog.faceSignalSamples.count
        let detected = sessionLog.faceSignalSamples.filter { $0.signals.isFaceDetected }.count
        let rate = total > 0 ? Double(detected) / Double(total) * 100 : 0
        return HStack(spacing: Spacing.sm) {
            Image(systemName: "face.smiling")
                .foregroundStyle(.secondary)
            Text("セッション中の顔検出率: \(String(format: "%.0f", rate))%（サンプル数: \(total)）")
                .font(Typography.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var voiceSummary: some View {
        let samples = sessionLog.voiceSignalSamples
        let averageSilenceCount = samples.isEmpty ? 0 : Double(samples.reduce(0) { $0 + $1.signals.silenceSegmentCount }) / Double(samples.count)
        return HStack(spacing: Spacing.sm) {
            Image(systemName: "waveform")
                .foregroundStyle(.secondary)
            Text("発話あたりの間（沈黙）の平均回数: \(String(format: "%.1f", averageSilenceCount))回（発話数: \(samples.count)）")
                .font(Typography.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// Canvasによる複数系列の折れ線グラフ。TimelineViewは使わず、データ変化時のみ再描画するため
/// 常時MainActorを占有しない。
private struct FaceTimelineChart: View {
    let samples: [FaceSignalSample]
    let turns: [TurnLog]
    let selectedFeatures: Set<FaceFeatureKind>
    let range: ClosedRange<Date>

    var body: some View {
        Canvas { context, size in
            draw(context: context, size: size)
        }
        .frame(height: 220)
        .padding(Spacing.sm)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
        .accessibilityLabel("表情推移グラフ")
        .accessibilityHint("選択中の項目: \(selectedFeatures.map(\.label).joined(separator: "、"))")
    }

    private func xPosition(for date: Date, width: CGFloat) -> CGFloat {
        let total = range.upperBound.timeIntervalSince(range.lowerBound)
        guard total > 0 else { return 0 }
        let progress = date.timeIntervalSince(range.lowerBound) / total
        return CGFloat(progress) * width
    }

    private func yPosition(for value: Float, range: ClosedRange<Float>, height: CGFloat) -> CGFloat {
        let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return height - CGFloat(normalized) * height
    }

    private func draw(context: GraphicsContext, size: CGSize) {
        drawUndetectedRanges(context: context, size: size)
        for feature in FaceFeatureKind.allCases where selectedFeatures.contains(feature) {
            drawLine(for: feature, context: context, size: size)
        }
        drawTurnMarkers(context: context, size: size)
    }

    private func drawUndetectedRanges(context: GraphicsContext, size: CGSize) {
        guard !samples.isEmpty else { return }
        var rangeStart: Date?
        for sample in samples {
            if !sample.signals.isFaceDetected {
                if rangeStart == nil { rangeStart = sample.timestamp }
            } else if let start = rangeStart {
                drawUndetectedBand(from: start, to: sample.timestamp, context: context, size: size)
                rangeStart = nil
            }
        }
        if let start = rangeStart, let last = samples.last?.timestamp {
            drawUndetectedBand(from: start, to: last, context: context, size: size)
        }
    }

    private func drawUndetectedBand(from start: Date, to end: Date, context: GraphicsContext, size: CGSize) {
        let x0 = xPosition(for: start, width: size.width)
        let x1 = xPosition(for: end, width: size.width)
        let rect = CGRect(x: x0, y: 0, width: max(1, x1 - x0), height: size.height)
        context.fill(Path(rect), with: .color(Color(.tertiarySystemFill)))
    }

    private func drawLine(for feature: FaceFeatureKind, context: GraphicsContext, size: CGSize) {
        var path = Path()
        var started = false
        for sample in samples {
            guard sample.signals.isFaceDetected else {
                started = false
                continue
            }
            let x = xPosition(for: sample.timestamp, width: size.width)
            let y = yPosition(for: feature.value(from: sample.signals), range: feature.range, height: size.height)
            if started {
                path.addLine(to: CGPoint(x: x, y: y))
            } else {
                path.move(to: CGPoint(x: x, y: y))
                started = true
            }
        }
        context.stroke(path, with: .color(feature.color), lineWidth: 2)
    }

    private func drawTurnMarkers(context: GraphicsContext, size: CGSize) {
        for turn in turns {
            let x = xPosition(for: turn.timestamp, width: size.width)

            var marker = Path()
            marker.move(to: CGPoint(x: x, y: 0))
            marker.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(marker, with: .color(Color.primary.opacity(0.2)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

            let dotColor: Color = turn.inputMethod == .voice ? .red : .blue
            let dotRect = CGRect(x: x - 3, y: 3, width: 6, height: 6)
            context.fill(Path(ellipseIn: dotRect), with: .color(dotColor))
        }
    }
}

/// 声の推移グラフ。発話1回につき1点しかないため、点と点をつなぐ折れ線になる（連続的な波形ではない）。
/// x軸はFaceTimelineChartと完全に同じrangeを受け取ることで、時間軸を揃える。
private struct VoiceTimelineChart: View {
    let samples: [VoiceSignalSample]
    let turns: [TurnLog]
    let selectedFeatures: Set<VoiceFeatureKind>
    let range: ClosedRange<Date>

    var body: some View {
        Canvas { context, size in
            draw(context: context, size: size)
        }
        .frame(height: 180)
        .padding(Spacing.sm)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
        .accessibilityLabel("声の推移グラフ")
        .accessibilityHint("選択中の項目: \(selectedFeatures.map(\.label).joined(separator: "、"))")
    }

    private func xPosition(for date: Date, width: CGFloat) -> CGFloat {
        let total = range.upperBound.timeIntervalSince(range.lowerBound)
        guard total > 0 else { return 0 }
        let progress = date.timeIntervalSince(range.lowerBound) / total
        return CGFloat(progress) * width
    }

    private func yPosition(for value: Float, range: ClosedRange<Float>, height: CGFloat) -> CGFloat {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let normalized = (clamped - range.lowerBound) / (range.upperBound - range.lowerBound)
        return height - CGFloat(normalized) * height
    }

    private func draw(context: GraphicsContext, size: CGSize) {
        for feature in VoiceFeatureKind.allCases where selectedFeatures.contains(feature) {
            drawLine(for: feature, context: context, size: size)
        }
        drawTurnMarkers(context: context, size: size)
    }

    private func drawLine(for feature: VoiceFeatureKind, context: GraphicsContext, size: CGSize) {
        guard samples.count > 1 else {
            drawSinglePoint(for: feature, context: context, size: size)
            return
        }
        var path = Path()
        var started = false
        for sample in samples {
            let x = xPosition(for: sample.timestamp, width: size.width)
            let y = yPosition(for: feature.value(from: sample.signals), range: feature.range, height: size.height)
            if started {
                path.addLine(to: CGPoint(x: x, y: y))
            } else {
                path.move(to: CGPoint(x: x, y: y))
                started = true
            }
            context.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)), with: .color(feature.color))
        }
        context.stroke(path, with: .color(feature.color), lineWidth: 2)
    }

    private func drawSinglePoint(for feature: VoiceFeatureKind, context: GraphicsContext, size: CGSize) {
        guard let sample = samples.first else { return }
        let x = xPosition(for: sample.timestamp, width: size.width)
        let y = yPosition(for: feature.value(from: sample.signals), range: feature.range, height: size.height)
        context.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)), with: .color(feature.color))
    }

    private func drawTurnMarkers(context: GraphicsContext, size: CGSize) {
        for turn in turns {
            let x = xPosition(for: turn.timestamp, width: size.width)
            var marker = Path()
            marker.move(to: CGPoint(x: x, y: 0))
            marker.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(marker, with: .color(Color.primary.opacity(0.15)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
    }
}

#Preview {
    FaceTimelineTab(sessionLog: SessionLog())
}

#Preview("サンプルデータあり") {
    let log = SessionLog()
    let start = Date().addingTimeInterval(-120)
    for i in 0..<80 {
        let t = start.addingTimeInterval(Double(i) * 1.5)
        let detected = !(30...40).contains(i)
        let phase = Double(i) / 10
        let signals = FaceSignals(
            isFaceDetected: detected,
            smile: detected ? Float(0.5 + 0.4 * sin(phase)) : 0,
            browRaise: detected ? Float(0.3 + 0.2 * sin(phase * 1.3)) : 0,
            browFurrow: 0,
            eyeOpenness: 1,
            gazeHorizontal: detected ? Float(0.3 * sin(phase * 0.7)) : 0,
            gazeVertical: 0,
            jawOpen: detected ? Float(max(0, 0.3 * sin(phase * 2))) : 0,
            headYaw: 0, headPitch: 0, headRoll: 0
        )
        log.recordFaceSignalSample(signals, at: t)
    }
    log.recordVoiceSignalSample(
        VoiceSignals(
            speechRateCharactersPerSecond: 4.5,
            averageVolume: 0.4,
            volumeVariation: 0.12,
            silenceSegmentCount: 1,
            averageSilenceDuration: 0.4,
            utteranceDuration: 3.2,
            pitchVariationProxy: 0.3
        ),
        at: start.addingTimeInterval(18)
    )
    log.recordVoiceSignalSample(
        VoiceSignals(
            speechRateCharactersPerSecond: 7.8,
            averageVolume: 0.6,
            volumeVariation: 0.22,
            silenceSegmentCount: 3,
            averageSilenceDuration: 0.8,
            utteranceDuration: 4.1,
            pitchVariationProxy: 0.55
        ),
        at: start.addingTimeInterval(68)
    )
    log.recordTurn(TurnLog(
        timestamp: start.addingTimeInterval(20),
        userUtterance: "こんにちは",
        inputMethod: .voice,
        faceContext: .sent("口角がやや上がっている"),
        voiceContext: .notSent(.insufficientBaseline),
        responseModel: "orcarouter/auto",
        wasSimpleUtterance: true,
        structuringModel: nil,
        assistantResponse: "こんにちは！",
        toulminArgument: nil,
        timeToFirstToken: 0.4,
        timeToCompletion: 1.2
    ))
    log.recordTurn(TurnLog(
        timestamp: start.addingTimeInterval(70),
        userUtterance: "明日の天気は？",
        inputMethod: .text,
        faceContext: .notSent(.faceNotDetected),
        voiceContext: .notSent(.notVoiceInput),
        responseModel: "orcarouter/auto",
        wasSimpleUtterance: false,
        structuringModel: "orcarouter/auto",
        assistantResponse: "明日は晴れの予報です。",
        toulminArgument: nil,
        timeToFirstToken: 0.5,
        timeToCompletion: 1.8
    ))
    return FaceTimelineTab(sessionLog: log)
}
