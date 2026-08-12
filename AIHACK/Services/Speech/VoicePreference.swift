import Foundation

/// ユーザーが選択した読み上げ音声のidentifierをUserDefaultsへ永続化する。
/// 音声そのもの（バイナリ等）は一切保存せず、システムが提供するidentifier文字列のみを保持する。
nonisolated enum VoicePreference {
    private static let key = "AIHACK.selectedVoiceIdentifier"

    static func load() -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    static func save(_ identifier: String?) {
        if let identifier {
            UserDefaults.standard.set(identifier, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
