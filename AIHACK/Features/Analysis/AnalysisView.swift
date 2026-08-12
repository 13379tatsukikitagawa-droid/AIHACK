import SwiftUI

/// 分析画面内のタブ識別子。仮説カードから会話ログの該当発話へジャンプする際にも使う。
enum AnalysisTab: Hashable {
    case conversation
    case faceTimeline
    case modelRouting
    case hypothesis
}

/// 会話中に内部で起きていたこと（表情情報の送信・モデル選択・論証構造・応答時間・仮説）を
/// あとから確認できるセッション分析画面。記録はメモリ上のみで、ディスクへは保存しない。
struct AnalysisView: View {
    let sessionLog: SessionLog
    let hypothesisStore: HypothesisStore
    var initialTab: AnalysisTab = .conversation

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: AnalysisTab
    @State private var highlightedTurnID: UUID?

    init(sessionLog: SessionLog, hypothesisStore: HypothesisStore, initialTab: AnalysisTab = .conversation) {
        self.sessionLog = sessionLog
        self.hypothesisStore = hypothesisStore
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                Tab("会話ログ", systemImage: "list.bullet.rectangle", value: AnalysisTab.conversation) {
                    ConversationLogTab(sessionLog: sessionLog, highlightedTurnID: $highlightedTurnID)
                }
                Tab("表情・声の推移", systemImage: "chart.xyaxis.line", value: AnalysisTab.faceTimeline) {
                    FaceTimelineTab(sessionLog: sessionLog)
                }
                Tab("モデルルーティング", systemImage: "arrow.triangle.branch", value: AnalysisTab.modelRouting) {
                    ModelRoutingTab(sessionLog: sessionLog)
                }
                Tab("仮説", systemImage: "lightbulb", value: AnalysisTab.hypothesis) {
                    HypothesisTab(sessionLog: sessionLog, store: hypothesisStore, onJumpToTurn: jumpToTurn)
                }
            }
            .navigationTitle("セッション分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
                }
            }
        }
    }

    private func jumpToTurn(index: Int) {
        guard sessionLog.turns.indices.contains(index) else { return }
        highlightedTurnID = sessionLog.turns[index].id
        selectedTab = .conversation
    }
}

// MARK: - タブ1: 会話ログ

struct ConversationLogTab: View {
    let sessionLog: SessionLog
    @Binding var highlightedTurnID: UUID?

    var body: some View {
        if sessionLog.turns.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                List {
                    Section {
                        privacyNotice
                    }
                    .listRowSeparator(.hidden)

                    ForEach(sessionLog.turns) { turn in
                        TurnRow(turn: turn, isHighlighted: turn.id == highlightedTurnID)
                            .id(turn.id)
                    }
                }
                .listStyle(.plain)
                .onChange(of: highlightedTurnID) { _, newValue in
                    guard let newValue else { return }
                    withAnimation {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "まだ会話がありません",
            systemImage: "text.bubble",
            description: Text("会話を始めると、やり取りがここに記録されます。")
        )
    }

    private var privacyNotice: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(.green)
            Text("この記録は端末のメモリ上にのみ保持され、保存されません。アプリを終了すると破棄されます。")
                .font(Typography.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
    }
}

private struct TurnRow: View {
    let turn: TurnLog
    var isHighlighted: Bool = false
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                summary
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "詳細を隠す" : "詳細を見る")

            if isExpanded {
                details
            }
        }
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.sm)
        .background(
            isHighlighted ? Color.accentColor.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous)
        )
        .onAppear {
            if isHighlighted { isExpanded = true }
        }
        .onChange(of: isHighlighted) { _, newValue in
            if newValue { isExpanded = true }
        }
    }

    private var summary: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: turn.inputMethod == .voice ? "mic.fill" : "keyboard")
                        .foregroundStyle(.secondary)
                    Text(turn.timestamp, style: .time)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Text(turn.userUtterance)
                    .font(Typography.subheadline)
                    .lineLimit(isExpanded ? nil : 2)
                Text(turn.assistantResponse.isEmpty ? "（応答なし）" : turn.assistantResponse)
                    .font(Typography.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(isExpanded ? nil : 2)
            }
            Spacer(minLength: Spacing.sm)
            Image(systemName: "chevron.right")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
        }
    }

    @ViewBuilder
    private var details: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            detailRow(label: "LLMに送られた表情情報", value: faceContextDescription)
            detailRow(label: "LLMに送られた声の情報", value: voiceContextDescription)
            detailRow(label: "応答モデル", value: turn.responseModel)
            if let structuringModel = turn.structuringModel {
                detailRow(label: "構造化モデル", value: structuringModel)
            } else {
                detailRow(label: "論証構造の抽出", value: "簡潔な発話のため未実施")
            }
            if let ttft = turn.timeToFirstToken {
                detailRow(label: "初動時間（最初のトークンまで）", value: String(format: "%.2f秒", ttft))
            }
            if let ttc = turn.timeToCompletion {
                detailRow(label: "完了までの時間（テキスト受信完了）", value: String(format: "%.2f秒", ttc))
            }
            if let argument = turn.toulminArgument {
                argumentDetail(argument)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
    }

    private var faceContextDescription: String {
        switch turn.faceContext {
        case .sent(let description):
            return description
        case .notSent(.cameraDisabled):
            return "送られていません（カメラが無効でした）"
        case .notSent(.faceNotDetected):
            return "送られていません（顔が検出されていませんでした）"
        case .notSent(.noSignificantChange):
            return "送られていません（有意な表情変化がありませんでした）"
        }
    }

    private var voiceContextDescription: String {
        switch turn.voiceContext {
        case .sent(let description):
            return description
        case .notSent(.notVoiceInput):
            return "送られていません（テキスト入力でした）"
        case .notSent(.insufficientBaseline):
            return "送られていません（このセッションでの基準値がまだ十分ではありませんでした）"
        case .notSent(.noSignificantChange):
            return "送られていません（普段の話し方との有意な違いがありませんでした）"
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Typography.footnote)
        }
    }

    @ViewBuilder
    private func argumentDetail(_ argument: ToulminArgument) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("論証構造")
                .font(Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            detailRow(label: "主張", value: argument.claim)
            if let grounds = argument.grounds { detailRow(label: "根拠", value: grounds) }
            if let warrant = argument.warrant { detailRow(label: "論拠", value: warrant) }
            if let backing = argument.backing { detailRow(label: "裏付け", value: backing) }
            if let qualifier = argument.qualifier { detailRow(label: "確からしさ", value: qualifier) }
            if let rebuttal = argument.rebuttal { detailRow(label: "例外", value: rebuttal) }
        }
    }
}

#Preview {
    let log = SessionLog()
    return AnalysisView(sessionLog: log, hypothesisStore: HypothesisStore(llmService: OrcaRouterService(), sessionLog: log, memoryStore: MemoryStore(llmService: OrcaRouterService())))
}

#Preview("サンプルデータあり") {
    let log = SessionLog()
    log.recordTurn(TurnLog(
        timestamp: Date().addingTimeInterval(-60),
        userUtterance: "明日は傘を持っていくべきかな？",
        inputMethod: .voice,
        faceContext: .sent("口角がやや上がっている、視線がやや下を向いている"),
        voiceContext: .notSent(.insufficientBaseline),
        responseModel: "orcarouter/auto",
        wasSimpleUtterance: false,
        structuringModel: "orcarouter/auto",
        assistantResponse: "明日の午後は降水確率が70%と高めなので、折りたたみ傘を持っていくのがおすすめです。",
        toulminArgument: ToulminArgument(
            claim: "折りたたみ傘を持っていくのがおすすめです。",
            grounds: "明日の午後の降水確率が70%と高めであること。",
            warrant: "降水確率が高い場合は雨に備えて傘を持参すべきという判断基準。",
            backing: "天気予報の降水確率データ。",
            qualifier: "おすすめ（確実ではない）",
            rebuttal: nil
        ),
        timeToFirstToken: 0.62,
        timeToCompletion: 2.1
    ))
    log.recordTurn(TurnLog(
        timestamp: Date().addingTimeInterval(-20),
        userUtterance: "ありがとう",
        inputMethod: .text,
        faceContext: .notSent(.cameraDisabled),
        voiceContext: .notSent(.notVoiceInput),
        responseModel: "orcarouter/auto",
        wasSimpleUtterance: true,
        structuringModel: nil,
        assistantResponse: "どういたしまして！",
        toulminArgument: nil,
        timeToFirstToken: 0.31,
        timeToCompletion: 0.58
    ))
    return AnalysisView(sessionLog: log, hypothesisStore: HypothesisStore(llmService: OrcaRouterService(), sessionLog: log, memoryStore: MemoryStore(llmService: OrcaRouterService())))
}
