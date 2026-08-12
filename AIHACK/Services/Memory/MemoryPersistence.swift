import Foundation
import os

/// 記憶データ（MemoryTopicの配列）をディスクへ永続化する。
/// 表情・声の観測データ（SessionLog、メモリ上のみで一切ディスクへ書かない）とは
/// 物理的に別ファイル・別ディレクトリ（Documents/Memory/）で管理する。
nonisolated enum MemoryPersistence {
    private static let logger = Logger(subsystem: "com.tatsukikitagawa.AIHACK", category: "Memory")

    private static var directoryURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Memory", isDirectory: true)
    }

    private static var fileURL: URL {
        directoryURL.appendingPathComponent("topics.json")
    }

    /// ファイルが存在しない場合（初回起動時など）は空配列を返す。
    static func load() -> [MemoryTopic] {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([MemoryTopic].self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        } catch {
            logger.error("記憶の読み込みに失敗しました: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    static func save(_ topics: [MemoryTopic]) {
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(topics)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("記憶の保存に失敗しました: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// save()の呼び出しを直列化するためのactor。複数のTaskからほぼ同時にpersist()が
/// 呼ばれても、ファイルへの書き込みが競合して更新が失われないようにする。
actor MemoryPersistenceQueue {
    func save(_ topics: [MemoryTopic]) {
        MemoryPersistence.save(topics)
    }
}
