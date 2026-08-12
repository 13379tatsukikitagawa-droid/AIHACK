import AVFoundation
import os

/// OrcaRouter（/v1/audio/speech）経由でTTS音声を取得するSpeechSynthesisServiceProtocol実装。
///
/// レイテンシ対策として、enqueue()で渡された文（ChatViewModel側が文単位に分割済み）ごとに
/// 即座に合成リクエストを送る「先読み合成」を行い、再生順序はキューで管理する。
/// 合成が失敗・タイムアウト（3秒）した場合は、その文だけ即座に端末内AVSpeechSynthesizerへ
/// フォールバックし、会話が止まらないことを最優先する。
///
/// AVAudioPlayerDelegate/AVSpeechSynthesizerDelegateはメインアクター外から呼ばれるため、
/// この型自体をnonisolatedとし、共有可変状態はNSLockで手動保護する（SpeechSynthesisServiceと同じ方針）。
nonisolated final class OrcaRouterTTSService: NSObject, SpeechSynthesisServiceProtocol, @unchecked Sendable {
    private static let endpoint = URL(string: "https://api.orcarouter.ai/v1/audio/speech")!
    private static let logger = Logger(subsystem: "com.tatsukikitagawa.AIHACK", category: "TTSNetwork")
    private static let synthesisTimeout: Duration = .seconds(3)
    private static let previewText = "これはOrcaRouter音声のサンプルです。"

    private enum TTSError: Error {
        case timeout
        case missingAPIKey
        case network(String)
        case apiError(statusCode: Int, message: String)
    }

    private struct QueueItem {
        let id: Int
        let text: String
    }

    private let session: URLSession
    private let lock = NSLock()

    // MARK: - ロックで保護する共有可変状態

    private var continuation: AsyncStream<SpeechSynthesisEvent>.Continuation?
    private var pendingQueue: [QueueItem] = []
    private var synthesisResults: [Int: Result<Data, Error>] = [:]
    private var synthesisTasks: [Int: Task<Void, Never>] = [:]
    private var pendingResultContinuations: [Int: CheckedContinuation<Void, Never>] = [:]
    private var nextID = 0
    private var isPumpRunning = false
    /// stop()のたびに増やす世代番号。古い世代の合成結果・再生完了を無視するために使う。
    private var generation = 0
    /// セッション内のみの音声キャッシュ（"音声|速度|テキスト" -> MP3データ）。ディスクへは保存しない。
    private var cache: [String: Data] = [:]
    private var audioPlayer: AVAudioPlayer?
    private var fallbackSynthesizer: AVSpeechSynthesizer?
    private var playbackResumeContinuation: CheckedContinuation<Void, Never>?
    private var pulseTask: Task<Void, Never>?

    init(session: URLSession = .shared) {
        self.session = session
        super.init()
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

        lock.lock()
        let id = nextID
        nextID += 1
        let currentGeneration = generation
        pendingQueue.append(QueueItem(id: id, text: trimmed))
        let shouldStartPump = !isPumpRunning
        isPumpRunning = true
        lock.unlock()

        // 先読み合成: 再生順序を待たず、キューに入れた瞬間にリクエストを送る
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performSynthesis(id: id, text: trimmed, generation: currentGeneration)
        }
        lock.lock()
        synthesisTasks[id] = task
        lock.unlock()

        if shouldStartPump {
            Task { [weak self] in await self?.pump() }
        }
    }

    func stop() {
        lock.lock()
        generation += 1
        let tasksToCancel = Array(synthesisTasks.values)
        synthesisTasks.removeAll()
        pendingQueue.removeAll()
        synthesisResults.removeAll()
        let waiters = pendingResultContinuations
        pendingResultContinuations.removeAll()
        let player = audioPlayer
        let synth = fallbackSynthesizer
        let resumeContinuation = playbackResumeContinuation
        playbackResumeContinuation = nil
        let pulse = pulseTask
        pulseTask = nil
        lock.unlock()

        tasksToCancel.forEach { $0.cancel() }
        waiters.values.forEach { $0.resume() }
        pulse?.cancel()
        player?.stop()
        synth?.stopSpeaking(at: .immediate)
        resumeContinuation?.resume()
    }

    // MARK: - 再生キューのポンプ

    /// キューにある文を順番に取り出し、合成結果を待って再生する。
    /// 合成自体はenqueue()側で既に並行して進んでいるため、ここでは「待つ」だけで先読みの恩恵を受けられる。
    private func pump() async {
        while true {
            let popped: (item: QueueItem, generation: Int)? = lock.withLock {
                guard !pendingQueue.isEmpty else {
                    isPumpRunning = false
                    return nil
                }
                return (pendingQueue.removeFirst(), generation)
            }
            guard let (item, currentGeneration) = popped else { break }

            await waitForResult(id: item.id, generation: currentGeneration)

            let (isStale, result): (Bool, Result<Data, Error>?) = lock.withLock {
                guard currentGeneration == generation else { return (true, nil) }
                return (false, synthesisResults.removeValue(forKey: item.id))
            }
            if isStale { continue }
            guard let result else { continue }

            yield(.speechDidBegin)

            switch result {
            case .success(let data):
                let played = await playAudio(data: data, generation: currentGeneration)
                if !played {
                    await playFallback(text: item.text, generation: currentGeneration)
                }
            case .failure(let error):
                Self.logger.error("TTS合成に失敗、端末内音声へフォールバックします: \(error.localizedDescription, privacy: .public)")
                await playFallback(text: item.text, generation: currentGeneration)
            }
        }

        yield(.queueDidDrain)
    }

    private func waitForResult(id: Int, generation: Int) async {
        let alreadyDone = lock.withLock {
            generation != self.generation || synthesisResults[id] != nil
        }
        if alreadyDone { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let shouldWait = lock.withLock { () -> Bool in
                if generation != self.generation || synthesisResults[id] != nil {
                    return false
                }
                pendingResultContinuations[id] = continuation
                return true
            }
            if !shouldWait {
                continuation.resume()
            }
        }
    }

    // MARK: - 合成（先読み）

    private func performSynthesis(id: Int, text: String, generation: Int) async {
        let voice = TTSPreference.voice
        let speed = TTSPreference.speed
        let cacheKey = "\(voice.rawValue)|\(speed)|\(text)"

        let cached = lock.withLock { cache[cacheKey] }

        if let cached {
            storeResult(.success(cached), for: id, generation: generation)
            return
        }

        // キャッシュヒットしなかった＝実際にAPI呼び出しが発生する。分析画面の統計用に記録する。
        yield(.ttsUsage(characterCount: text.count))

        do {
            let data = try await synthesizeWithTimeout(text: text, voice: voice, speed: speed)
            lock.withLock { cache[cacheKey] = data }
            storeResult(.success(data), for: id, generation: generation)
        } catch {
            Self.logger.error("TTS合成エラー: \(error.localizedDescription, privacy: .public) length=\(text.count, privacy: .public)")
            storeResult(.failure(error), for: id, generation: generation)
        }
    }

    private func storeResult(_ result: Result<Data, Error>, for id: Int, generation: Int) {
        lock.lock()
        guard generation == self.generation else {
            synthesisTasks[id] = nil
            lock.unlock()
            return
        }
        synthesisResults[id] = result
        synthesisTasks[id] = nil
        let waiter = pendingResultContinuations.removeValue(forKey: id)
        lock.unlock()
        waiter?.resume()
    }

    private func synthesizeWithTimeout(text: String, voice: TTSVoice, speed: Double) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await Self.performRequest(text: text, voice: voice, speed: speed, session: self.session)
            }
            group.addTask {
                try await Task.sleep(for: Self.synthesisTimeout)
                throw TTSError.timeout
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else {
                throw TTSError.timeout
            }
            return first
        }
    }

    // MARK: - 再生

    /// 成功時はtrue、AVAudioPlayerの初期化に失敗した場合はfalseを返す（呼び出し側でフォールバックへ切り替える）
    private func playAudio(data: Data, generation: Int) async -> Bool {
        guard let player = try? AVAudioPlayer(data: data) else {
            Self.logger.error("AVAudioPlayerの初期化に失敗しました")
            return false
        }
        player.delegate = self

        let isCurrent = lock.withLock { () -> Bool in
            guard generation == self.generation else { return false }
            audioPlayer = player
            return true
        }
        guard isCurrent else { return true }

        startPulseLoop()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let shouldPlay = lock.withLock { () -> Bool in
                guard generation == self.generation else { return false }
                playbackResumeContinuation = continuation
                return true
            }
            if shouldPlay {
                player.play()
            } else {
                continuation.resume()
            }
        }
        stopPulseLoop()
        return true
    }

    private func playFallback(text: String, generation: Int) async {
        Self.logger.info("フォールバック発話開始（端末内音声）: length=\(text.count, privacy: .public)")

        let synthesizer: AVSpeechSynthesizer = lock.withLock {
            if let existing = fallbackSynthesizer {
                return existing
            }
            let created = AVSpeechSynthesizer()
            fallbackSynthesizer = created
            return created
        }
        synthesizer.delegate = self

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = DeviceVoiceResolver.resolve()

        startPulseLoop()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let shouldSpeak = lock.withLock { () -> Bool in
                guard generation == self.generation else { return false }
                playbackResumeContinuation = continuation
                return true
            }
            if shouldSpeak {
                synthesizer.speak(utterance)
            } else {
                continuation.resume()
            }
        }
        stopPulseLoop()
    }

    private func resumePlaybackWaiter() {
        lock.lock()
        let continuation = playbackResumeContinuation
        playbackResumeContinuation = nil
        lock.unlock()
        continuation?.resume()
    }

    // MARK: - アバター同期用パルス

    /// AVAudioPlayerにはAVSpeechSynthesizerのwillSpeakRangeOfSpeechStringに相当する単語境界イベントがないため、
    /// 一定間隔でwordBoundaryを送出し、再生位置に応じたアバターのパルス同期を近似する。
    private func startPulseLoop() {
        let task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
                self?.yield(.wordBoundary)
            }
        }
        lock.lock()
        pulseTask = task
        lock.unlock()
    }

    private func stopPulseLoop() {
        lock.lock()
        let task = pulseTask
        pulseTask = nil
        lock.unlock()
        task?.cancel()
    }

    private func yield(_ event: SpeechSynthesisEvent) {
        lock.lock()
        let current = continuation
        lock.unlock()
        current?.yield(event)
    }

    // MARK: - ネットワーク

    nonisolated private static func performRequest(
        text: String,
        voice: TTSVoice,
        speed: Double,
        session: URLSession
    ) async throws -> Data {
        guard !Secrets.orcaRouterAPIKey.isEmpty else {
            Self.logger.error("APIキーが未設定のためTTSリクエストを中止しました")
            throw TTSError.missingAPIKey
        }

        let requestBody = TTSSpeechRequestBody(
            model: ModelCatalog.ttsPrimary,
            input: text,
            voice: voice.rawValue,
            speed: speed
        )

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Secrets.orcaRouterAPIKey)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            Self.logger.error("TTSリクエストのエンコードに失敗: \(error.localizedDescription, privacy: .public)")
            throw TTSError.network(error.localizedDescription)
        }

        Self.logger.info("TTS合成リクエスト送信: model=\(ModelCatalog.ttsPrimary, privacy: .public) voice=\(voice.rawValue, privacy: .public) length=\(text.count, privacy: .public)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            Self.logger.error("TTSネットワークエラー: \(error.localizedDescription, privacy: .public)")
            throw TTSError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.network("不正なレスポンスです。")
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let bodyPreview = String(data: data, encoding: .utf8) ?? "(本文なし)"
            Self.logger.error("TTS APIエラー: status=\(httpResponse.statusCode, privacy: .public) body=\(bodyPreview, privacy: .public)")
            throw TTSError.apiError(statusCode: httpResponse.statusCode, message: bodyPreview)
        }

        Self.logger.info("TTS合成成功: bytes=\(data.count, privacy: .public)")
        return data
    }

    /// 設定画面の試聴専用。会話中のキュー・キャッシュとは独立した単発リクエスト。
    static func fetchPreview(voice: TTSVoice, speed: Double, session: URLSession = .shared) async throws -> Data {
        try await performRequest(text: previewText, voice: voice, speed: speed, session: session)
    }
}

nonisolated extension OrcaRouterTTSService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        resumePlaybackWaiter()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        resumePlaybackWaiter()
    }
}

nonisolated extension OrcaRouterTTSService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        resumePlaybackWaiter()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        resumePlaybackWaiter()
    }
}
