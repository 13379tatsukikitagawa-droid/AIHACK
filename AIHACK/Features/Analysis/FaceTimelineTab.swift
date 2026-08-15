import SwiftUI
import Charts

// MARK: - タブ2: 表情・声の推移

struct FaceTimelineTab: View {
    let sessionLog: SessionLog

    @State private var selectedFaceGroup: FaceFeatureKind.Group = .expression
    @State private var selectedFaceFeatures: Set<FaceFeatureKind> = Set(FaceFeatureKind.Group.expression.features)

    var body: some View {
        if sessionLog.faceSignalSamples.isEmpty && sessionLog.voiceSignalSamples.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    if !sessionLog.faceSignalSamples.isEmpty {
                        faceSection
                    }

                    if !sessionLog.voiceSignalSamples.isEmpty {
                        voiceSection
                    }
                }
                .padding(Spacing.lg)
            }
        }
    }

    // MARK: 表情

    private var faceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("表情")
                .font(Typography.title3)
                .fontWeight(Theme.Weight.emphasis)

            Picker("項目グループ", selection: $selectedFaceGroup) {
                ForEach(FaceFeatureKind.Group.allCases) { group in
                    Text(group.label).tag(group)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedFaceGroup) { _, newGroup in
                selectedFaceFeatures = Set(newGroup.features)
            }

            faceFeatureToggles

            FaceTimelineChart(
                samples: sessionLog.faceSignalSamples,
                turns: sessionLog.turns,
                group: selectedFaceGroup,
                selectedFeatures: selectedFaceFeatures,
                range: sharedTimeRange
            )

            legendNote
            detectionSummary
        }
    }

    private var faceFeatureToggles: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: Spacing.sm)], alignment: .leading, spacing: Spacing.sm) {
            ForEach(selectedFaceGroup.features) { feature in
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
            .background(isSelected ? color.opacity(0.16) : Theme.Palette.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? color : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var legendNote: some View {
        HStack(spacing: Spacing.lg) {
            HStack(spacing: Spacing.xs) {
                Circle().fill(DataVizPalette.blue).frame(width: 8, height: 8)
                Text("テキスト発話")
            }
            HStack(spacing: Spacing.xs) {
                Circle().fill(DataVizPalette.hero).frame(width: 8, height: 8)
                Text("音声発話")
            }
            HStack(spacing: Spacing.xs) {
                RoundedRectangle(cornerRadius: 2).fill(DataVizPalette.mutedBand).frame(width: 14, height: 8)
                Text("顔が未検出")
            }
        }
        .font(Typography.caption)
        .foregroundStyle(Theme.Palette.textSecondary)
    }

    private var detectionSummary: some View {
        let total = sessionLog.faceSignalSamples.count
        let detected = sessionLog.faceSignalSamples.filter { $0.signals.isFaceDetected }.count
        let rate = total > 0 ? Double(detected) / Double(total) * 100 : 0
        return StatTile(
            icon: "face.smiling",
            title: "顔検出率",
            value: "\(String(format: "%.0f", rate))%",
            caption: "サンプル数 \(total)"
        )
    }

    // MARK: 声

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Divider()

            Text("声")
                .font(Typography.title3)
                .fontWeight(Theme.Weight.emphasis)
            Text("音声入力の発話ごとに1点を記録するため、項目ごとに独立したグラフで表示します。")
                .font(Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: Spacing.md)], spacing: Spacing.md) {
                ForEach(VoiceFeatureKind.allCases) { feature in
                    VoiceStatCard(feature: feature, samples: sessionLog.voiceSignalSamples, range: sharedTimeRange)
                }
            }

            voiceSummary
        }
    }

    private var voiceSummary: some View {
        let samples = sessionLog.voiceSignalSamples
        let averageSilenceCount = samples.isEmpty ? 0 : Double(samples.reduce(0) { $0 + $1.signals.silenceSegmentCount }) / Double(samples.count)
        return StatTile(
            icon: "waveform",
            title: "発話あたりの間（沈黙）の平均回数",
            value: String(format: "%.1f回", averageSilenceCount),
            caption: "発話数 \(samples.count)"
        )
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
}

/// セクション末尾の要約に使う、数値を大きく見せるための小さな統計カード。
private struct StatTile: View {
    let icon: String
    let title: String
    let value: String
    let caption: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(Typography.title3)
                .foregroundStyle(DataVizPalette.hero)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text(value)
                    .font(Typography.title2)
                    .fontWeight(Theme.Weight.strong)
                    .monospacedDigit()
            }

            Spacer()

            Text(caption)
                .font(Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(Spacing.md)
        .background(Theme.Palette.surface, in: Theme.Radius.shape(Theme.Radius.medium))
    }
}

/// Swift Chartsによる表情推移グラフ。ドラッグでその時刻の各系列の値を確認できる。
private struct FaceTimelineChart: View {
    let samples: [FaceSignalSample]
    let turns: [TurnLog]
    let group: FaceFeatureKind.Group
    let selectedFeatures: Set<FaceFeatureKind>
    let range: ClosedRange<Date>

    @State private var scrubDate: Date?

    private var undetectedBands: [(start: Date, end: Date)] {
        var bands: [(Date, Date)] = []
        var rangeStart: Date?
        for sample in samples {
            if !sample.signals.isFaceDetected {
                if rangeStart == nil { rangeStart = sample.timestamp }
            } else if let start = rangeStart {
                bands.append((start, sample.timestamp))
                rangeStart = nil
            }
        }
        if let start = rangeStart, let last = samples.last?.timestamp {
            bands.append((start, last))
        }
        return bands
    }

    private var orderedSelectedFeatures: [FaceFeatureKind] {
        group.features.filter { selectedFeatures.contains($0) }
    }

    private var nearestSample: FaceSignalSample? {
        guard let scrubDate else { return nil }
        return samples.min { abs($0.timestamp.timeIntervalSince(scrubDate)) < abs($1.timestamp.timeIntervalSince(scrubDate)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let nearestSample {
                scrubReadout(for: nearestSample)
            }

            Chart {
                ForEach(Array(undetectedBands.enumerated()), id: \.offset) { _, band in
                    RectangleMark(
                        xStart: .value("開始", band.start),
                        xEnd: .value("終了", band.end)
                    )
                    .foregroundStyle(DataVizPalette.mutedBand)
                }

                ForEach(orderedSelectedFeatures) { feature in
                    ForEach(detectedSamples, id: \.id) { sample in
                        LineMark(
                            x: .value("時刻", sample.timestamp),
                            y: .value(feature.label, feature.value(from: sample.signals))
                        )
                        .foregroundStyle(by: .value("項目", feature.label))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }

                    if orderedSelectedFeatures.count == 1 {
                        ForEach(detectedSamples, id: \.id) { sample in
                            AreaMark(
                                x: .value("時刻", sample.timestamp),
                                y: .value(feature.label, feature.value(from: sample.signals))
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [feature.color.opacity(0.22), feature.color.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }
                }

                ForEach(turns) { turn in
                    RuleMark(x: .value("発話", turn.timestamp))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(Theme.Palette.textSecondary.opacity(0.35))
                        .annotation(position: .top, spacing: 0) {
                            Circle()
                                .fill(turn.inputMethod == .voice ? DataVizPalette.hero : DataVizPalette.blue)
                                .frame(width: 6, height: 6)
                        }
                }

                if let nearestSample {
                    RuleMark(x: .value("選択中", nearestSample.timestamp))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.5))
                }
            }
            .chartForegroundStyleScale(domain: group.features.map(\.label), range: group.features.map(\.color))
            .chartLegend(selectedFeatures.count > 1 ? .visible : .hidden)
            .chartLegend(position: .bottom, alignment: .leading, spacing: Spacing.sm)
            .chartYScale(domain: group.sharedRange)
            .chartXScale(domain: range)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Theme.Palette.divider)
                    AxisValueLabel()
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Theme.Palette.divider)
                    AxisValueLabel(format: .dateTime.minute().second())
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .frame(height: 220)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    updateScrub(at: value.location, proxy: proxy, geometry: geometry)
                                }
                                .onEnded { _ in scrubDate = nil }
                        )
                }
            }
        }
        .padding(Spacing.md)
        .background(Theme.Palette.surface, in: Theme.Radius.shape(Theme.Radius.medium))
        .accessibilityLabel("表情推移グラフ")
        .accessibilityHint("選択中の項目: \(orderedSelectedFeatures.map(\.label).joined(separator: "、"))")
    }

    private var detectedSamples: [FaceSignalSample] {
        samples.filter { $0.signals.isFaceDetected }
    }

    private func updateScrub(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        let plotFrame = geometry[proxy.plotAreaFrame]
        let originX = location.x - plotFrame.origin.x
        guard let date: Date = proxy.value(atX: originX) else { return }
        scrubDate = date
    }

    private func scrubReadout(for sample: FaceSignalSample) -> some View {
        HStack(spacing: Spacing.md) {
            Text(sample.timestamp, style: .time)
                .font(Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
            ForEach(orderedSelectedFeatures) { feature in
                HStack(spacing: 4) {
                    Circle().fill(feature.color).frame(width: 6, height: 6)
                    Text(formatted(feature.value(from: sample.signals), for: feature))
                        .font(Typography.caption)
                        .fontWeight(Theme.Weight.emphasis)
                        .monospacedDigit()
                }
            }
        }
        .transition(.opacity)
    }

    private func formatted(_ value: Float, for feature: FaceFeatureKind) -> String {
        feature.range == 0...1 ? String(format: "%.0f%%", value * 100) : String(format: "%+.2f", value)
    }
}

/// 声の特徴量1つぶんの、統計値＋小さな折れ線（スパークライン）を持つカード。
private struct VoiceStatCard: View {
    let feature: VoiceFeatureKind
    let samples: [VoiceSignalSample]
    let range: ClosedRange<Date>

    private var average: Float {
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0) { $0 + feature.value(from: $1.signals) } / Float(samples.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: feature.icon)
                    .font(Typography.caption)
                    .foregroundStyle(DataVizPalette.hero)
                Text(feature.label)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            Text(feature.formattedValue(average))
                .font(Typography.headline)
                .fontWeight(Theme.Weight.strong)
                .monospacedDigit()

            sparkline
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surfaceElevated, in: Theme.Radius.shape(Theme.Radius.small))
    }

    @ViewBuilder
    private var sparkline: some View {
        if samples.count > 1 {
            Chart(samples, id: \.id) { sample in
                LineMark(
                    x: .value("時刻", sample.timestamp),
                    y: .value(feature.label, min(max(feature.value(from: sample.signals), feature.range.lowerBound), feature.range.upperBound))
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(DataVizPalette.hero)

                PointMark(
                    x: .value("時刻", sample.timestamp),
                    y: .value(feature.label, min(max(feature.value(from: sample.signals), feature.range.lowerBound), feature.range.upperBound))
                )
                .symbolSize(14)
                .foregroundStyle(DataVizPalette.hero)
            }
            .chartYScale(domain: feature.range)
            .chartXScale(domain: range)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 44)
            .accessibilityLabel("\(feature.label)の推移")
        } else if let sample = samples.first {
            HStack {
                Circle().fill(DataVizPalette.hero).frame(width: 8, height: 8)
                Text("発話1回分のみ")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
            }
            .frame(height: 44)
            .accessibilityHidden(true)
            .id(sample.id)
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
            pitchVariationProxy: 0.3,
            averagePitchHz: 165
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
            pitchVariationProxy: 0.55,
            averagePitchHz: 210
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
