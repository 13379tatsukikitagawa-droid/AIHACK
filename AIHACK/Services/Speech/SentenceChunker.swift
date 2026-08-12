import Foundation

/// LLMのストリーミング差分テキストを文単位に区切り、読み上げキューへ逐次投入できるようにする。
nonisolated struct SentenceChunker {
    private var buffer = ""
    private let terminators: Set<Character> = ["。", "！", "？", "!", "?", "\n"]

    mutating func append(_ text: String) -> [String] {
        buffer += text
        var sentences: [String] = []
        var current = ""

        for character in buffer {
            current.append(character)
            if terminators.contains(character) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
                current = ""
            }
        }

        buffer = current
        return sentences
    }

    /// ストリーム終了時に残っている未確定分を取り出す
    mutating func flushRemainder() -> String? {
        let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        buffer = ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
