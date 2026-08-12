import AVFoundation
import Speech
import os

/// SFSpeechRecognizer + AVAudioEngineによるリアルタイム音声認識。
/// マイクのリアルタイムタップ・認識結果コールバックはSFSpeechRecognizer/AVAudioEngineが管理する
/// バックグラウンドスレッドから呼ばれるため、それらのクロージャは`self`のアクター隔離状態には触れず、
/// ローカルにキャプチャした値（requestBox, continuation）のみを操作する設計にしている。
actor SpeechRecognitionService: SpeechRecognitionServiceProtocol {
    nonisolated private static let logger = Logger(subsystem: "com.tatsukikitagawa.AIHACK", category: "SpeechRecognition")

    /// オンデバイス認識がこの時間内に最初のコールバックを返さない場合、サーバー経由へ透過的に再試行する
    nonisolated private static let onDeviceRecognitionTimeout: Duration = .seconds(3)

    private let recognizer: SFSpeechRecognizer?

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var hasRetriedWithServerRecognition = false

    init(locale: Locale = Locale(identifier: "ja-JP")) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
    }

    nonisolated func startRecognition() -> AsyncThrowingStream<SpeechRecognitionEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                await self.beginSession(continuation: continuation)
            }
            continuation.onTermination = { _ in
                task.cancel()
                Task { await self.teardown() }
            }
        }
    }

    func finishRecognition() {
        if recognitionRequest == nil {
            Self.logger.error("finishRecognition()が呼ばれましたが、recognitionRequestが未作成です（開始処理と競合した可能性があります）")
        } else {
            Self.logger.info("recognitionRequest.endAudio()を呼び出します")
        }
        recognitionRequest?.endAudio()
    }

    private func beginSession(continuation: AsyncThrowingStream<SpeechRecognitionEvent, Error>.Continuation) async {
        let speechAuthStatus = SFSpeechRecognizer.authorizationStatus()
        let micPermission = AVAudioApplication.shared.recordPermission
        Self.logger.info("""
        認識開始要求: speechAuth=\(String(describing: speechAuthStatus), privacy: .public) \
        micPermission=\(String(describing: micPermission), privacy: .public)
        """)

        guard let recognizer else {
            Self.logger.error("SFSpeechRecognizerの生成に失敗しました（ロケール非対応の可能性）")
            continuation.finish(throwing: SpeechError.recognizerUnavailable)
            return
        }

        Self.logger.info("SFSpeechRecognizer.isAvailable=\(recognizer.isAvailable, privacy: .public) supportsOnDeviceRecognition=\(recognizer.supportsOnDeviceRecognition, privacy: .public)")

        guard recognizer.isAvailable else {
            Self.logger.error("SFSpeechRecognizerが利用不可のため認識を開始できません")
            continuation.finish(throwing: SpeechError.recognizerUnavailable)
            return
        }

        let engine = AVAudioEngine()
        audioEngine = engine

        // 修正2: inputNodeのフォーマットを取得する前に、AVAudioSessionが録音可能な状態
        // （.playAndRecordかつアクティブ）になっていることを保証する。
        do {
            try AudioSessionCoordinator.configureForVoiceChat()
        } catch {
            Self.logger.error("AVAudioSessionの設定に失敗しました: \(error.localizedDescription, privacy: .public)")
            continuation.finish(throwing: SpeechError.audioEngineFailure("マイクの準備に失敗しました。"))
            return
        }

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        Self.logger.info("""
        入力フォーマット: sampleRate=\(recordingFormat.sampleRate, privacy: .public) \
        channels=\(recordingFormat.channelCount, privacy: .public)
        """)

        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            Self.logger.error("入力フォーマットが不正です（sampleRate/channelsが0）。AVAudioSessionが録音可能な状態になっていません")
            continuation.finish(throwing: SpeechError.audioEngineFailure("マイクの入力フォーマットを取得できませんでした。時間をおいて再度お試しください。"))
            return
        }

        // 音声バッファの送り先は差し替え可能なBoxを介す。オンデバイス認識がタイムアウト・失敗した際に
        // 同じマイクタップ・エンジンを維持したまま、サーバー経由のリクエストへ透過的に切り替えるため。
        let requestBox = RecognitionRequestBox()
        // この発話1回分の韻律特徴量をリアルタイムスレッド上で軽量に集計する（音声データ自体は保持しない）。
        let prosodyAccumulator = ProsodyAccumulator()

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            requestBox.append(buffer)
            let level = prosodyAccumulator.append(buffer)
            continuation.yield(.audioLevel(level))
        }

        engine.prepare()
        do {
            try engine.start()
            Self.logger.info("AVAudioEngineを開始しました（isRunning=\(engine.isRunning, privacy: .public)）")
        } catch {
            Self.logger.error("AVAudioEngineの開始に失敗しました: \(error.localizedDescription, privacy: .public)")
            continuation.finish(throwing: SpeechError.audioEngineFailure(error.localizedDescription))
            return
        }

        runRecognitionAttempt(
            recognizer: recognizer,
            preferOnDevice: recognizer.supportsOnDeviceRecognition,
            requestBox: requestBox,
            prosodyAccumulator: prosodyAccumulator,
            continuation: continuation,
            isRetry: false
        )
    }

    /// 認識試行を1回分開始する。オンデバイス試行が失敗・無応答の場合、サーバー経由で自らを再度呼び出す。
    private func runRecognitionAttempt(
        recognizer: SFSpeechRecognizer,
        preferOnDevice: Bool,
        requestBox: RecognitionRequestBox,
        prosodyAccumulator: ProsodyAccumulator,
        continuation: AsyncThrowingStream<SpeechRecognitionEvent, Error>.Continuation,
        isRetry: Bool
    ) {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = preferOnDevice
        recognitionRequest = request
        requestBox.replace(with: request)

        Self.logger.info("認識試行を開始: requiresOnDeviceRecognition=\(preferOnDevice, privacy: .public) isRetry=\(isRetry, privacy: .public)")

        let didReceiveFirstCallback = OSAllocatedUnfairLock(initialState: false)

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let isFirstCallback = didReceiveFirstCallback.withLock { received in
                defer { received = true }
                return !received
            }

            if let result {
                let text = result.bestTranscription.formattedString
                Self.logger.info("認識コールバック到達: isFinal=\(result.isFinal, privacy: .public) length=\(text.count, privacy: .public)")
                if result.isFinal {
                    let voiceSignals = prosodyAccumulator.finalize(recognizedCharacterCount: text.count)
                    continuation.yield(.voiceSignals(voiceSignals))
                    continuation.yield(.finalTranscript(text))
                    continuation.finish()
                } else {
                    continuation.yield(.partialTranscript(text))
                }
            }

            if let error {
                let nsError = error as NSError
                Self.logger.error("""
                認識エラー: domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public) \
                message=\(error.localizedDescription, privacy: .public) isRetry=\(isRetry, privacy: .public)
                """)

                if isFirstCallback, preferOnDevice, !isRetry {
                    // オンデバイス指定が原因の可能性がある失敗。サーバー経由で透過的に再試行する。
                    Task { [weak self] in
                        await self?.retryWithServerRecognition(
                            recognizer: recognizer,
                            requestBox: requestBox,
                            prosodyAccumulator: prosodyAccumulator,
                            continuation: continuation
                        )
                    }
                } else {
                    continuation.finish(throwing: SpeechError.recognitionFailed(error.localizedDescription))
                }
            }
        }

        // 修正1: オンデバイス認識が一定時間内に最初のコールバックを返さない場合、
        // ユーザー操作を挟まずサーバー経由へ切り替える。
        if preferOnDevice, !isRetry {
            Task { [weak self] in
                try? await Task.sleep(for: Self.onDeviceRecognitionTimeout)
                guard let self else { return }
                let alreadyResponded = didReceiveFirstCallback.withLock { $0 }
                guard !alreadyResponded else { return }
                Self.logger.info("オンデバイス認識が\(Self.onDeviceRecognitionTimeout.components.seconds, privacy: .public)秒以内に応答しなかったため、サーバー経由で再試行します")
                await self.retryWithServerRecognition(
                    recognizer: recognizer,
                    requestBox: requestBox,
                    prosodyAccumulator: prosodyAccumulator,
                    continuation: continuation
                )
            }
        }
    }

    private func retryWithServerRecognition(
        recognizer: SFSpeechRecognizer,
        requestBox: RecognitionRequestBox,
        prosodyAccumulator: ProsodyAccumulator,
        continuation: AsyncThrowingStream<SpeechRecognitionEvent, Error>.Continuation
    ) {
        guard !hasRetriedWithServerRecognition else { return }
        hasRetriedWithServerRecognition = true

        Self.logger.info("サーバー経由の音声認識へ再試行します")
        recognitionTask?.cancel()
        runRecognitionAttempt(
            recognizer: recognizer,
            preferOnDevice: false,
            requestBox: requestBox,
            prosodyAccumulator: prosodyAccumulator,
            continuation: continuation,
            isRetry: true
        )
    }

    private func teardown() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}

/// マイクのリアルタイムタップから、その時点で有効なSFSpeechAudioBufferRecognitionRequestへ
/// バッファを橋渡しするスレッドセーフな箱。オンデバイス→サーバーへの切り替え時、
/// エンジン・タップを再構築せずにリクエスト差し替えのみで済ませるために使う。
nonisolated private final class RecognitionRequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        let current = request
        lock.unlock()
        current?.append(buffer)
    }

    func replace(with newRequest: SFSpeechAudioBufferRecognitionRequest) {
        lock.lock()
        request = newRequest
        lock.unlock()
    }
}
