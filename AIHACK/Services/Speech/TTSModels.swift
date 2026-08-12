import Foundation

/// OrcaRouter /v1/audio/speech が受け付ける音声の種類。実リクエストのバリデーションエラーで列挙を確認済み。
nonisolated enum TTSVoice: String, CaseIterable, Identifiable, Sendable {
    case alloy
    case ash
    case coral
    case echo
    case fable
    case nova
    case onyx
    case sage
    case shimmer

    var id: String { rawValue }

    var label: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

/// POST /v1/audio/speech のリクエストボディ（OpenAI互換）。
nonisolated struct TTSSpeechRequestBody: Encodable, Sendable {
    let model: String
    let input: String
    let voice: String
    let speed: Double
}
