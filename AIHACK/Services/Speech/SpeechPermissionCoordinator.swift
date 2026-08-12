import AVFoundation
import Speech

/// マイク・音声認識の権限確認と要求を担う。UIには権限の可否のみを返し、要求タイミングの制御は呼び出し側に委ねる。
nonisolated enum SpeechPermissionCoordinator {
    static func currentStatus() -> SpeechPermissionStatus {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus = AVAudioApplication.shared.recordPermission

        if speechStatus == .denied || speechStatus == .restricted || micStatus == .denied {
            return .denied
        }
        if speechStatus == .authorized && micStatus == .granted {
            return .authorized
        }
        return .notDetermined
    }

    static func requestAccess() async -> SpeechPermissionStatus {
        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            return .denied
        }

        let micGranted = await AVAudioApplication.requestRecordPermission()
        return micGranted ? .authorized : .denied
    }
}
