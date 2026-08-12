import AVFoundation
import os

/// 録音・再生を両立させるためのAVAudioSession設定を一箇所に集約する。
nonisolated enum AudioSessionCoordinator {
    private static let logger = Logger(subsystem: "com.tatsukikitagawa.AIHACK", category: "AudioSession")

    static func configureForVoiceChat() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        logger.info("""
        AVAudioSession設定完了: category=\(session.category.rawValue, privacy: .public) \
        mode=\(session.mode.rawValue, privacy: .public) \
        otherAudioPlaying=\(session.isOtherAudioPlaying, privacy: .public)
        """)
    }

    static func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        logger.info("AVAudioSessionを非アクティブ化しました")
    }
}
