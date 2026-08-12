import Foundation

/// SessionLogに蓄積された会話履歴・表情の時系列・状態遷移を、仮説生成LLMへ渡すための
/// テキスト要約に変換する。表情の生の数値は渡さず、言語化された記述のみを扱う。
/// SessionLogがMainActor隔離のため、この型もMainActor上でのみ呼び出す前提とする。
@MainActor
enum SessionSummaryBuilder {
    static func buildPrompt(from sessionLog: SessionLog, memoryTopics: [MemoryTopic] = []) -> String {
        var sections: [String] = []

        sections.append("# 会話履歴（\(sessionLog.turns.count)件、番号は0始まり）")
        if sessionLog.turns.isEmpty {
            sections.append("（記録なし）")
        } else {
            for (index, turn) in sessionLog.turns.enumerated() {
                sections.append(turnDescription(index: index, turn: turn, sessionStart: sessionLog.sessionStartedAt))
            }
        }

        sections.append("\n# 表情の時系列記録（サンプル数: \(sessionLog.faceSignalSamples.count)、変化があった時点のみ抜粋）")
        sections.append(faceTimelineSummary(sessionLog.faceSignalSamples, sessionStart: sessionLog.sessionStartedAt))

        sections.append("\n# 記憶されたトピック（複数回の会話セッションにまたがる蓄積データ、\(memoryTopics.count)件）")
        sections.append(memoryTopicsSummary(memoryTopics))

        sections.append("\n# 状態遷移の概要")
        sections.append(stateTransitionSummary(sessionLog.stateTransitions))

        return sections.joined(separator: "\n")
    }

    private static func elapsed(_ date: Date, since start: Date) -> String {
        let totalSeconds = max(0, Int(date.timeIntervalSince(start)))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private static func turnDescription(index: Int, turn: TurnLog, sessionStart: Date) -> String {
        let time = elapsed(turn.timestamp, since: sessionStart)
        let method = turn.inputMethod == .voice ? "音声" : "テキスト"

        let face: String
        switch turn.faceContext {
        case .sent(let description):
            face = "表情観測: \(description)"
        case .notSent(.cameraDisabled):
            face = "表情観測: なし（カメラ無効）"
        case .notSent(.faceNotDetected):
            face = "表情観測: なし（顔未検出）"
        case .notSent(.noSignificantChange):
            face = "表情観測: 有意な変化なし"
        }

        let voice: String?
        switch turn.voiceContext {
        case .sent(let description):
            voice = "声の観測（このセッション内の平均との相対比較）: \(description)"
        case .notSent(.notVoiceInput):
            voice = nil
        case .notSent(.insufficientBaseline):
            voice = "声の観測: なし（基準値が蓄積中）"
        case .notSent(.noSignificantChange):
            voice = "声の観測: 有意な変化なし"
        }

        let lines = [
            "発話\(index)（\(time), \(method)入力）: 「\(turn.userUtterance)」",
            "  \(face)"
        ] + (voice.map { ["  \($0)"] } ?? []) + [
            "  応答: 「\(turn.assistantResponse)」"
        ]
        return lines.joined(separator: "\n")
    }

    private static func faceTimelineSummary(_ samples: [FaceSignalSample], sessionStart: Date) -> String {
        guard !samples.isEmpty else { return "（記録なし）" }

        var lastDescription: String?
        var lines: [String] = []
        for sample in samples {
            let description = sample.signals.isFaceDetected
                ? (FaceSignalDescriber.describe(sample.signals) ?? "目立った変化なし")
                : "顔未検出"
            if description != lastDescription {
                lines.append("\(elapsed(sample.timestamp, since: sessionStart)): \(description)")
                lastDescription = description
            }
        }

        // 長大化を避けるため、多い場合は前後のみ残す
        if lines.count > 40 {
            let head = lines.prefix(20)
            let tail = lines.suffix(20)
            lines = Array(head) + ["…（中略）…"] + Array(tail)
        }

        return lines.joined(separator: "\n")
    }

    private static func memoryTopicsSummary(_ topics: [MemoryTopic]) -> String {
        guard !topics.isEmpty else { return "（記録なし）" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"

        return topics
            .sorted { $0.mentionCount > $1.mentionCount }
            .map { topic in
                "「\(topic.topic)」: 言及\(topic.mentionCount)回、初回\(formatter.string(from: topic.firstMentionedAt))、" +
                "直近\(formatter.string(from: topic.lastMentionedAt))"
            }
            .joined(separator: "\n")
    }

    private static func stateTransitionSummary(_ transitions: [StateTransitionLog]) -> String {
        guard !transitions.isEmpty else { return "（記録なし）" }

        var counts: [String: Int] = [:]
        for transition in transitions {
            counts[transition.state.displayLabel, default: 0] += 1
        }
        return counts
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)回" }
            .joined(separator: "、")
    }
}
