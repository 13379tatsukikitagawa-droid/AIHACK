nonisolated protocol FaceTrackingServiceProtocol: Sendable {
    /// この端末がARFaceTrackingConfigurationに対応しているか
    var isSupported: Bool { get }
    /// 顔トラッキングを開始し、特徴量を逐次流すストリームを返す
    func startTracking() -> AsyncStream<FaceSignals>
    /// 顔トラッキングを停止し、ARSessionとカメラを解放する
    func stopTracking()
}
