import ARKit
import os

/// ARFaceTrackingConfigurationによる顔トラッキング。3D描画は一切行わず、blendShapesと
/// transformから導出した特徴量のみを扱う。映像そのものは保存も送信もしない。
///
/// ARSessionDelegateのコールバックは高頻度・非MainActorから呼ばれるため、この型自体を
/// nonisolatedとし、専用のシリアルキューをARSessionのdelegateQueueに指定することで
/// メインスレッドを一切ブロックしない設計にしている。共有可変状態(continuation)のみ
/// NSLockで保護する（SmoothedFeature群は専用シリアルキュー上でのみ操作するためロック不要）。
nonisolated final class FaceTrackingService: NSObject, FaceTrackingServiceProtocol, @unchecked Sendable {
    nonisolated private static let logger = Logger(subsystem: "com.tatsukikitagawa.AIHACK", category: "FaceTracking")

    var isSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }

    private let session = ARSession()
    private let trackingQueue = DispatchQueue(label: "com.aihack.facetracking", qos: .userInitiated)

    private let lock = NSLock()
    private var continuation: AsyncStream<FaceSignals>.Continuation?
    /// 直近ログした検出状態（毎フレームのログ出力を避けるため、変化時のみ記録する）
    private var lastLoggedDetectionState: Bool?

    private var smile = SmoothedFeature()
    private var browRaise = SmoothedFeature()
    private var browFurrow = SmoothedFeature()
    private var eyeOpenness = SmoothedFeature()
    private var gazeHorizontal = SmoothedFeature()
    private var gazeVertical = SmoothedFeature()
    private var jawOpen = SmoothedFeature()
    private var headYaw = SmoothedFeature()
    private var headPitch = SmoothedFeature()
    private var headRoll = SmoothedFeature()

    private var lastEmitTime: TimeInterval = 0
    /// 下流への更新頻度の上限（毎フレームではなく間引いて通知する）
    private let minEmitInterval: TimeInterval = 1.0 / 12.0

    override init() {
        super.init()
        session.delegate = self
        session.delegateQueue = trackingQueue
    }

    func startTracking() -> AsyncStream<FaceSignals> {
        AsyncStream { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()

            guard isSupported else {
                Self.logger.warning("この端末はARFaceTrackingConfigurationに対応していません")
                continuation.yield(.neutral)
                continuation.finish()
                return
            }

            let configuration = ARFaceTrackingConfiguration()
            configuration.isLightEstimationEnabled = false
            session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            Self.logger.info("ARSessionを開始しました（顔トラッキング）")

            continuation.onTermination = { [session] _ in
                Self.logger.info("ARSessionを停止しました（ストリーム終了）")
                session.pause()
            }
        }
    }

    func stopTracking() {
        Self.logger.info("ARSessionを停止しました（明示的な停止呼び出し）")
        session.pause()
        lock.lock()
        continuation?.finish()
        continuation = nil
        lock.unlock()
    }

    private func process(faceAnchor: ARFaceAnchor) {
        if lastLoggedDetectionState != true {
            lastLoggedDetectionState = true
            Self.logger.info("顔を検出しました")
        }

        let blendShapes = faceAnchor.blendShapes

        func value(_ key: ARFaceAnchor.BlendShapeLocation) -> Float {
            blendShapes[key]?.floatValue ?? 0
        }

        let smileRaw = (value(.mouthSmileLeft) + value(.mouthSmileRight)) / 2
        let browRaiseRaw = value(.browInnerUp)
        let browFurrowRaw = (value(.browDownLeft) + value(.browDownRight)) / 2
        let eyeOpennessRaw = 1 - (value(.eyeBlinkLeft) + value(.eyeBlinkRight)) / 2
        let jawOpenRaw = value(.jawOpen)

        let gazeHorizontalRaw = Self.clamp(
            ((value(.eyeLookInLeft) + value(.eyeLookOutRight)) - (value(.eyeLookOutLeft) + value(.eyeLookInRight))) / 2,
            -1, 1
        )
        let gazeVerticalRaw = Self.clamp(
            ((value(.eyeLookUpLeft) + value(.eyeLookUpRight)) - (value(.eyeLookDownLeft) + value(.eyeLookDownRight))) / 2,
            -1, 1
        )

        let euler = Self.eulerAngles(from: faceAnchor.transform)
        let maxAngle: Float = .pi / 2

        let signals = FaceSignals(
            isFaceDetected: true,
            smile: smile.update(with: smileRaw),
            browRaise: browRaise.update(with: browRaiseRaw),
            browFurrow: browFurrow.update(with: browFurrowRaw),
            eyeOpenness: eyeOpenness.update(with: eyeOpennessRaw),
            gazeHorizontal: gazeHorizontal.update(with: gazeHorizontalRaw),
            gazeVertical: gazeVertical.update(with: gazeVerticalRaw),
            jawOpen: jawOpen.update(with: jawOpenRaw),
            headYaw: headYaw.update(with: Self.clamp(euler.yaw / maxAngle, -1, 1)),
            headPitch: headPitch.update(with: Self.clamp(euler.pitch / maxAngle, -1, 1)),
            headRoll: headRoll.update(with: Self.clamp(euler.roll / maxAngle, -1, 1))
        )

        emit(signals)
    }

    private func emitNotDetected() {
        if lastLoggedDetectionState != false {
            lastLoggedDetectionState = false
            Self.logger.info("顔が検出されなくなりました")
        }

        let signals = FaceSignals(
            isFaceDetected: false,
            smile: smile.current,
            browRaise: browRaise.current,
            browFurrow: browFurrow.current,
            eyeOpenness: eyeOpenness.current,
            gazeHorizontal: gazeHorizontal.current,
            gazeVertical: gazeVertical.current,
            jawOpen: jawOpen.current,
            headYaw: headYaw.current,
            headPitch: headPitch.current,
            headRoll: headRoll.current
        )
        emit(signals, throttled: false)
    }

    private func emit(_ signals: FaceSignals, throttled: Bool = true) {
        if throttled {
            let now = Date().timeIntervalSinceReferenceDate
            guard now - lastEmitTime >= minEmitInterval else { return }
            lastEmitTime = now
        }

        lock.lock()
        let current = continuation
        lock.unlock()
        current?.yield(signals)
    }

    nonisolated private static func clamp(_ value: Float, _ lower: Float, _ upper: Float) -> Float {
        min(max(value, lower), upper)
    }

    nonisolated private static func eulerAngles(from transform: simd_float4x4) -> (pitch: Float, yaw: Float, roll: Float) {
        let pitch = asin(-transform.columns.2.y)
        let yaw = atan2(transform.columns.2.x, transform.columns.2.z)
        let roll = atan2(transform.columns.0.y, transform.columns.1.y)
        return (pitch, yaw, roll)
    }
}

nonisolated extension FaceTrackingService: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }
        process(faceAnchor: faceAnchor)
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard anchors.contains(where: { $0 is ARFaceAnchor }) else { return }
        emitNotDetected()
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        Self.logger.error("ARSessionが失敗しました: \(error.localizedDescription, privacy: .public)")
        lock.lock()
        let current = continuation
        continuation = nil
        lock.unlock()
        current?.finish()
    }
}
