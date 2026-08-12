nonisolated enum ConversationState: Equatable, Sendable {
    case idle
    case listening
    case thinking
    case speaking
    case error

    var displayLabel: String {
        switch self {
        case .idle: "待機中"
        case .listening: "聞いています"
        case .thinking: "考えています"
        case .speaking: "話しています"
        case .error: "エラー"
        }
    }
}
