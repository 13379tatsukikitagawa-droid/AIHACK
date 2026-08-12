import AVFoundation

/// 選択中の端末内音声を解決する。設定されていなければシステム標準の日本語音声を使う。
/// SpeechSynthesisService（通常時の端末内読み上げ）とOrcaRouterTTSService（TTS失敗時のフォールバック）の
/// 両方から共有され、どちらの経路でも同じ音声が使われることを保証する。
nonisolated enum DeviceVoiceResolver {
    static func resolve() -> AVSpeechSynthesisVoice? {
        if let identifier = VoicePreference.load(),
           let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice
        }
        return AVSpeechSynthesisVoice(language: "ja-JP")
    }
}
