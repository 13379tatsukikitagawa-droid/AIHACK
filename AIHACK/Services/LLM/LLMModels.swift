import Foundation

nonisolated struct ChatCompletionRequest: Encodable, Sendable {
    let model: String
    let models: [String]
    let route: String
    let messages: [ChatCompletionRequestMessage]
    let stream: Bool
}

nonisolated struct ChatCompletionRequestMessage: Encodable, Sendable {
    let role: String
    let content: String
}

nonisolated struct ChatCompletionChunk: Decodable, Sendable {
    struct Choice: Decodable, Sendable {
        struct Delta: Decodable, Sendable {
            let role: String?
            let content: String?
        }

        let delta: Delta
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }

    let choices: [Choice]
}

nonisolated struct ChatCompletionResponse: Decodable, Sendable {
    struct Choice: Decodable, Sendable {
        struct Message: Decodable, Sendable {
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}

nonisolated struct APIErrorResponse: Decodable, Sendable {
    struct APIErrorDetail: Decodable, Sendable {
        let message: String
        let type: String?
        let code: String?
    }

    let error: APIErrorDetail
}
