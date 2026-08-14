import Foundation

/// ランキング1件分の記録。保存するのはニックネームとスコアの数値のみで、
/// 発話内容・表情・声の生データは一切含まない。
nonisolated struct LeaderboardEntry: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let nickname: String
    let score: Int
    let recordedAt: Date
}
