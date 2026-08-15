import SwiftUI
import Charts

// MARK: - タブ3: モデルルーティング

struct ModelRoutingTab: View {
    let sessionLog: SessionLog

    var body: some View {
        if sessionLog.turns.isEmpty {
            emptyState
        } else {
            List {
                Section("モデル別呼び出し回数") {
                    ModelCallCountChart(entries: aggregatedCounts)
                        .listRowInsets(EdgeInsets(top: Spacing.sm, leading: Spacing.md, bottom: Spacing.sm, trailing: Spacing.md))
                }

                if sessionLog.ttsCallCount > 0 {
                    Section("音声合成（TTS）") {
                        HStack {
                            Text("呼び出し回数")
                                .font(Typography.subheadline)
                            Spacer()
                            Text("\(sessionLog.ttsCallCount)回")
                                .font(Typography.subheadline)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        HStack {
                            Text("送信文字数の合計")
                                .font(Typography.subheadline)
                            Spacer()
                            Text("\(sessionLog.ttsCharacterCount)文字")
                                .font(Typography.subheadline)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                Section("発話ごとの選択理由") {
                    ForEach(sessionLog.turns) { turn in
                        RoutingRow(turn: turn)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "まだ記録がありません",
            systemImage: "arrow.triangle.branch",
            description: Text("会話を始めると、モデルの選択状況がここに表示されます。")
        )
    }

    fileprivate struct ModelCount: Identifiable {
        let model: String
        let count: Int
        var id: String { model }
    }

    private var aggregatedCounts: [ModelCount] {
        var counts: [String: Int] = [:]
        for turn in sessionLog.turns {
            counts[turn.responseModel, default: 0] += 1
            if let structuringModel = turn.structuringModel {
                counts[structuringModel, default: 0] += 1
            }
        }
        return counts.map { ModelCount(model: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
}

/// モデル別の呼び出し回数を、多い順の水平バーチャートで表示する。単一系列（回数）の
/// カテゴリ比較のため、色はブランドのグラフ用コーラル1色のみを使う。
private struct ModelCallCountChart: View {
    let entries: [ModelRoutingTab.ModelCount]

    private var chartHeight: CGFloat {
        CGFloat(entries.count) * 36 + Spacing.sm
    }

    var body: some View {
        Chart(entries) { entry in
            BarMark(
                x: .value("回数", entry.count),
                y: .value("モデル", entry.model)
            )
            .foregroundStyle(DataVizPalette.hero)
            .cornerRadius(4)
            .annotation(position: .trailing, alignment: .leading) {
                Text("\(entry.count)回")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .monospacedDigit()
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
        }
        .frame(height: chartHeight)
        .padding(.vertical, Spacing.xs)
        .accessibilityLabel("モデル別呼び出し回数のグラフ")
    }
}

private struct RoutingRow: View {
    let turn: TurnLog

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(turn.userUtterance)
                .font(Typography.subheadline)
                .lineLimit(2)

            HStack(spacing: Spacing.xs) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(.secondary)
                Text("応答モデル: \(turn.responseModel)")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Text(routingReason)
                .font(Typography.caption)
                .foregroundStyle(.secondary)

            if let structuringModel = turn.structuringModel {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "list.bullet.indent")
                        .foregroundStyle(.secondary)
                    Text("構造化モデル: \(structuringModel)")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private var routingReason: String {
        turn.wasSimpleUtterance
            ? "簡潔な発話（挨拶・相槌）と判定されました"
            : "論証構造が必要な応答と判定されました"
    }
}

#Preview {
    ModelRoutingTab(sessionLog: SessionLog())
}
