import AVFoundation

/// AVSpeechSynthesisVoiceQualityを、UI表示用の3段階に単純化したもの。
nonisolated enum VoiceQualityTier: Int, Sendable, Comparable, CaseIterable {
    case standard = 0
    case enhanced = 1
    case premium = 2

    init(_ quality: AVSpeechSynthesisVoiceQuality) {
        switch quality {
        case .premium: self = .premium
        case .enhanced: self = .enhanced
        default: self = .standard
        }
    }

    var label: String {
        switch self {
        case .standard: return "標準"
        case .enhanced: return "高品質"
        case .premium: return "プレミアム"
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// 設定画面で選択・試聴できる音声1件分の情報。
nonisolated struct VoiceOption: Identifiable, Sendable, Equatable {
    let identifier: String
    let name: String
    let languageCode: String
    let qualityTier: VoiceQualityTier

    var id: String { identifier }
}

/// 端末に実際に存在する日本語音声を取得する。存在しない選択肢は一切生成しない。
nonisolated enum VoiceCatalog {
    static func japaneseVoices() -> [VoiceOption] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("ja") }
            .map { voice in
                VoiceOption(
                    identifier: voice.identifier,
                    name: voice.name,
                    languageCode: voice.language,
                    qualityTier: VoiceQualityTier(voice.quality)
                )
            }
            .sorted { lhs, rhs in
                lhs.qualityTier == rhs.qualityTier ? lhs.name < rhs.name : lhs.qualityTier > rhs.qualityTier
            }
    }

    /// 現在選択中でない場合にSpeechSynthesisServiceが使うのと同じデフォルト音声
    static func systemDefaultVoice() -> VoiceOption? {
        guard let voice = AVSpeechSynthesisVoice(language: "ja-JP") else { return nil }
        return VoiceOption(
            identifier: voice.identifier,
            name: voice.name,
            languageCode: voice.language,
            qualityTier: VoiceQualityTier(voice.quality)
        )
    }
}
