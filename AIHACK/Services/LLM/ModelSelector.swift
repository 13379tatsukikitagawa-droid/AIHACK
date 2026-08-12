import Foundation
import os

/// 発話の内容に応じて、応答生成・論証構造抽出に使うモデルを切り替える。
/// OrcaRouterの適応的ルーティングを活かし、短い相槌・挨拶には軽量なモデルを、
/// 論証構造を要する応答には別のモデルを割り当てられるようにする。
nonisolated enum ModelSelector {
    private static let logger = Logger(subsystem: "com.tatsukikitagawa.AIHACK", category: "ModelRouting")

    /// 会話応答（spokenResponse）生成に使うモデルを選び、選択結果をログに記録する。
    static func responseModel(for utterance: String) -> String {
        let simple = isSimpleUtterance(utterance)
        let model = simple ? ModelCatalog.lightweight : ModelCatalog.conversational
        logger.info("応答モデルを選択: \(model, privacy: .public)（簡潔な発話: \(simple, privacy: .public)）")
        return model
    }

    /// 論証構造の抽出に使うモデル
    static var structuringModel: String {
        let model = ModelCatalog.reasoning
        logger.info("構造化モデルを選択: \(model, privacy: .public)")
        return model
    }

    /// この発話に対して論証構造の抽出を行うべきか（挨拶や相槌では行わない）
    static func shouldStructure(utterance: String) -> Bool {
        !isSimpleUtterance(utterance)
    }

    private static func isSimpleUtterance(_ utterance: String) -> Bool {
        let trimmed = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 8 else { return false }
        return simpleUtterancePatterns.contains { trimmed.contains($0) }
    }

    private static let simpleUtterancePatterns: Set<String> = [
        "こんにちは", "おはよう", "こんばんは", "おやすみ",
        "はい", "うん", "そうだね", "そう", "ありがとう", "了解",
        "オーケー", "OK", "ok", "バイバイ", "さようなら", "うーん", "なるほど", "うん、"
    ]
}
