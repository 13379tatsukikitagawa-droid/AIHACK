import Foundation
import Observation

/// 「30秒プレゼン」のランキングを端末内（UserDefaults）にのみ保存する。外部送信・クラウド保存は
/// 一切行わない。保存するのはニックネームとスコアの数値のみで、発話内容・表情・声の生データは
/// 保持しない。ブースでの1日の使用を想定し、上位一定件数のみを保持する。
@MainActor
@Observable
final class Leaderboard {
    private static let storageKey = "com.tatsukikitagawa.AIHACK.game.leaderboard"
    /// 保持する上位件数。ブースでの1日の使用を想定した目安。
    private static let maxEntries = 20

    /// スコア降順で並んだ一覧。
    private(set) var entries: [LeaderboardEntry] = []
    /// 直近このセッションで登録したエントリのID。ランキング画面での強調表示に使う。
    private(set) var lastRegisteredEntryID: UUID?

    init() {
        load()
    }

    @discardableResult
    func register(nickname: String, score: Int) -> LeaderboardEntry {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmed.isEmpty ? "名無しさん" : String(trimmed.prefix(20))
        let entry = LeaderboardEntry(id: UUID(), nickname: displayName, score: score, recordedAt: Date())

        entries.append(entry)
        entries.sort { $0.score > $1.score }
        if entries.count > Self.maxEntries {
            entries.removeLast(entries.count - Self.maxEntries)
        }
        lastRegisteredEntryID = entry.id
        save()
        return entry
    }

    /// ブース終了後・翌日のための全件リセット。
    func resetAll() {
        entries.removeAll()
        lastRegisteredEntryID = nil
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }
        entries = (try? JSONDecoder().decode([LeaderboardEntry].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
