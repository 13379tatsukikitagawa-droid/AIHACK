/// Toulminモデルの6要素。claim以外はオプショナル。
/// すべての発話が完全な論証構造を持つわけではない（挨拶や相槌など）ため、
/// 該当する内容がない要素はnilのまま扱い、UI側では存在する要素のみを表示する。
nonisolated struct ToulminArgument: Codable, Sendable, Equatable {
    /// 主張: 何を言おうとしているか
    let claim: String
    /// 根拠: 主張を支える事実・データ
    let grounds: String?
    /// 論拠: 根拠と主張をつなぐ理由づけ
    let warrant: String?
    /// 裏付け: 論拠を支える背景知識
    let backing: String?
    /// 限定: どの程度確かなのか（確からしさ）
    let qualifier: String?
    /// 反論・例外: 成り立たない場合
    let rebuttal: String?
}
