import Foundation

nonisolated struct ChatMessage: Identifiable, Equatable, Sendable {
    enum Role: Equatable, Sendable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    var content: String
    var isStreaming: Bool
    /// ユーザー発言送信時に付与された、言語化済みの表情観測情報（有意な変化があった場合のみ）
    var faceDescription: String?
    /// ユーザー発言送信時に付与された、言語化済みの声の韻律観測情報（音声入力かつ有意な変化があった場合のみ）
    var voiceDescription: String?
    /// アシスタント応答の裏側にある論証構造（構造化に成功した場合のみ）
    var toulminArgument: ToulminArgument?

    init(
        id: UUID = UUID(),
        role: Role,
        content: String = "",
        isStreaming: Bool = false,
        faceDescription: String? = nil,
        voiceDescription: String? = nil,
        toulminArgument: ToulminArgument? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.isStreaming = isStreaming
        self.faceDescription = faceDescription
        self.voiceDescription = voiceDescription
        self.toulminArgument = toulminArgument
    }
}
