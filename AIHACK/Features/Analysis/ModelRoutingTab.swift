import SwiftUI

// MARK: - タブ3: モデルルーティング

struct ModelRoutingTab: View {
    let sessionLog: SessionLog

    var body: some View {
        if sessionLog.turns.isEmpty {
            emptyState
        } else {
            List {
                Section("モデル別呼び出し回数") {
                    ForEach(aggregatedCounts, id: \.model) { entry in
                        HStack {
                            Text(entry.model)
                                .font(Typography.subheadline)
                            Spacer()
                            Text("\(entry.count)回")
                                .font(Typography.subheadline)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
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

    private struct ModelCount {
        let model: String
        let count: Int
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
