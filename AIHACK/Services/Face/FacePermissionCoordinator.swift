import AVFoundation

/// カメラ権限の確認・要求を担う。ステップ2のSpeechPermissionCoordinatorと同じ方針。
nonisolated enum FacePermissionCoordinator {
    static func currentStatus() -> CameraPermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
    }

    static func requestAccess() async -> CameraPermissionStatus {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .authorized : .denied
    }
}
