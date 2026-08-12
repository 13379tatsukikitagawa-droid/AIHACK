import Foundation

/// 設定（TTSPreference.engine）に応じて、端末内音声とOrcaRouter TTSを切り替えるルーター。
/// SpeechSynthesisServiceProtocolを満たすことで、ChatViewModel側は切り替えを一切意識しない。
/// enqueue()のたびに設定を読み直すため、会話中にエンジンを変更しても次の文から即座に反映される。
/// 切り替え時は前のエンジンのキュー・再生を停止し、2つのエンジンが同時に発話しないようにする。
nonisolated final class SpeechSynthesisRouter: SpeechSynthesisServiceProtocol, @unchecked Sendable {
    private let deviceEngine: SpeechSynthesisServiceProtocol
    private let orcaRouterEngine: SpeechSynthesisServiceProtocol
    private let lock = NSLock()
    private var activeEngine: TTSEngineKind?

    init(
        deviceEngine: SpeechSynthesisServiceProtocol,
        orcaRouterEngine: SpeechSynthesisServiceProtocol
    ) {
        self.deviceEngine = deviceEngine
        self.orcaRouterEngine = orcaRouterEngine
    }

    func events() -> AsyncStream<SpeechSynthesisEvent> {
        AsyncStream { continuation in
            let deviceTask = Task {
                for await event in self.deviceEngine.events() {
                    continuation.yield(event)
                }
            }
            let orcaTask = Task {
                for await event in self.orcaRouterEngine.events() {
                    continuation.yield(event)
                }
            }
            continuation.onTermination = { _ in
                deviceTask.cancel()
                orcaTask.cancel()
            }
        }
    }

    func enqueue(_ text: String) {
        let engine = TTSPreference.engine

        lock.lock()
        let previous = activeEngine
        activeEngine = engine
        lock.unlock()

        if let previous, previous != engine {
            service(for: previous).stop()
        }
        service(for: engine).enqueue(text)
    }

    func stop() {
        deviceEngine.stop()
        orcaRouterEngine.stop()
    }

    private func service(for engine: TTSEngineKind) -> SpeechSynthesisServiceProtocol {
        engine == .device ? deviceEngine : orcaRouterEngine
    }
}
