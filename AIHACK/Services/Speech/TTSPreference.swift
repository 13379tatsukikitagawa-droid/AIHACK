import Foundation

/// 読み上げに使うエンジンの種類。
nonisolated enum TTSEngineKind: String, Sendable {
    case device
    case orcaRouter
}

/// TTSエンジン・OrcaRouter音声・速度のユーザー設定。UserDefaultsへ永続化する。
/// 呼び出しのたびに読み込むため、会話中に設定を変更しても次の発話から即座に反映される。
nonisolated enum TTSPreference {
    private static let engineKey = "AIHACK.ttsEngine"
    private static let voiceKey = "AIHACK.ttsVoice"
    private static let speedKey = "AIHACK.ttsSpeed"

    /// デフォルトはOrcaRouter TTS（高品質な自然音声を優先し、失敗時のみ端末内音声にフォールバックする）
    static var engine: TTSEngineKind {
        get {
            guard let raw = UserDefaults.standard.string(forKey: engineKey),
                  let kind = TTSEngineKind(rawValue: raw) else { return .orcaRouter }
            return kind
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: engineKey) }
    }

    static var voice: TTSVoice {
        get {
            guard let raw = UserDefaults.standard.string(forKey: voiceKey),
                  let voice = TTSVoice(rawValue: raw) else { return .alloy }
            return voice
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: voiceKey) }
    }

    /// 読み上げ速度（0.5〜2.0）。未設定時は等倍。
    static var speed: Double {
        get {
            guard UserDefaults.standard.object(forKey: speedKey) != nil else { return 1.0 }
            return UserDefaults.standard.double(forKey: speedKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: speedKey) }
    }
}
