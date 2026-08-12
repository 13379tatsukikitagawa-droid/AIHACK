import Foundation

nonisolated enum SpeechError: Error {
    case recognizerUnavailable
    case audioEngineFailure(String)
    case recognitionFailed(String)
}

extension SpeechError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "音声認識が利用できません。しばらくしてから再度お試しください。"
        case .audioEngineFailure(let message):
            return "マイクの起動に失敗しました: \(message)"
        case .recognitionFailed(let message):
            return "音声認識に失敗しました: \(message)"
        }
    }
}
