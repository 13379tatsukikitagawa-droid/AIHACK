import AVFoundation

/// AVSpeechSynthesizerのラッパー。読み上げキューの残数をロックで保護し、キュー完全消化のタイミングをイベントとして通知する。
/// AVSpeechSynthesizerDelegateはメインアクター外から呼ばれるため、この型自体をnonisolatedとし、
/// 共有可変状態(pendingCount / continuation)はNSLockで手動保護する。
nonisolated final class SpeechSynthesisService: NSObject, SpeechSynthesisServiceProtocol, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    private let lock = NSLock()
    private var continuation: AsyncStream<SpeechSynthesisEvent>.Continuation?
    private var pendingCount = 0

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func events() -> AsyncStream<SpeechSynthesisEvent> {
        AsyncStream { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()
        }
    }

    func enqueue(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = DeviceVoiceResolver.resolve()

        lock.lock()
        pendingCount += 1
        lock.unlock()

        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func yield(_ event: SpeechSynthesisEvent) {
        lock.lock()
        let current = continuation
        lock.unlock()
        current?.yield(event)
    }

    private func utteranceCompleted() {
        lock.lock()
        pendingCount = max(0, pendingCount - 1)
        let drained = pendingCount == 0
        lock.unlock()

        if drained {
            yield(.queueDidDrain)
        }
    }
}

extension SpeechSynthesisService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        yield(.speechDidBegin)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        utteranceCompleted()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        utteranceCompleted()
    }

    /// 読み上げ位置の進行をアバターの発話同期に利用する
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        yield(.wordBoundary)
    }
}
