import Foundation
import Observation
import AVFoundation
import UIKit
import os

@MainActor
@Observable
final class ChatViewModel {
    private static let logger = Logger(subsystem: "com.tatsukikitagawa.AIHACK", category: "ConversationFlow")
    private static let latencyLogger = Logger(subsystem: "com.tatsukikitagawa.AIHACK", category: "TTSLatency")
    private(set) var messages: [ChatMessage] = []
    var inputText: String = ""
    private(set) var conversationState: ConversationState = .idle
    private(set) var errorMessage: String?
    /// 429（レート制限）による自動リトライの状況。ユーザーへ「待たされている理由」を明示するために使う。
    private(set) var retryNotice: String?

    private(set) var liveTranscript: String = ""
    private(set) var audioLevel: Float = 0
    private(set) var isMicPermissionDenied = false
    /// ハンズフリー会話セッションが有効かどうか。listening/thinking/speakingを跨いで保持される。
    private(set) var isHandsFreeActive = false

    private(set) var faceSignals: FaceSignals = .neutral
    private(set) var isCameraActive = false
    private(set) var isCameraPermissionDenied = false

    /// アバターの発話同期に使う、直近の単語境界イベントの発生時刻
    private(set) var lastSpeechPulseAt: Date?

    /// セッション分析画面で参照する、メモリ上のみの記録。ディスクへは保存しない。
    let sessionLog = SessionLog()

    /// セッション全体の観察に基づく仮説生成の状態。会話の応答経路とは独立して動作する。
    let hypothesisStore: HypothesisStore

    /// 好み・関心・話題の記憶。表情・声とは異なりディスクへ永続化され、セッションをまたいで保持される。
    let memoryStore: MemoryStore

    let isAPIKeyConfigured: Bool

    private let llmService: LLMServiceProtocol
    private let speechRecognitionService: SpeechRecognitionServiceProtocol
    private let speechSynthesisService: SpeechSynthesisServiceProtocol
    private let faceTrackingService: FaceTrackingServiceProtocol

    private var streamingTask: Task<Void, Never>?
    private var listeningTask: Task<Void, Never>?
    private var faceTrackingTask: Task<Void, Never>?
    private var isGeneratingText = false
    private var isSpeakingAudio = false
    private var isAudioSessionConfigured = false
    private var lastFaceSampleAt: Date?
    /// 現在処理中の発話ターンの開始時刻。最初の音声が鳴るまでの時間を計測するために使う。
    private var activeTurnStartedAt: Date?
    private var hasLoggedFirstAudioLatency = false
    /// thinking/speaking状態での「進行があった最後の時刻」。スタック検知の基準として使う。
    private var lastProgressAt: Date?
    private var stuckStateWatchdogTask: Task<Void, Never>?
    /// 直近の発話1回分の韻律特徴量。finalTranscriptの直前に届くため、commitTranscript()の
    /// タイミングで読み取り、消費後はnilに戻す。
    private var pendingVoiceSignals: VoiceSignals?
    /// 直近に有意な音量を検知した時刻。無音区間の自動送信判定、および音声モードの
    /// 長時間無音タイムアウト判定の両方から参照する（consumeRecognition内でのみ更新）。
    private var lastSoundDetectedAt = Date()
    /// 音声モード（ハンズフリーセッション）終了時に、次にidleへ到達したタイミングで
    /// 締めの一言を再生すべきかどうか。
    private var pendingFarewell = false
    /// listening状態が続いているのに一定時間まったく発話がない場合、セッションを終える監視タスク。
    private var inactivityWatchdogTask: Task<Void, Never>?

    init(
        llmService: LLMServiceProtocol = OrcaRouterService(),
        speechRecognitionService: SpeechRecognitionServiceProtocol = SpeechRecognitionService(),
        speechSynthesisService: SpeechSynthesisServiceProtocol = SpeechSynthesisRouter(
            deviceEngine: SpeechSynthesisService(),
            orcaRouterEngine: OrcaRouterTTSService()
        ),
        faceTrackingService: FaceTrackingServiceProtocol = FaceTrackingService()
    ) {
        self.llmService = llmService
        self.speechRecognitionService = speechRecognitionService
        self.speechSynthesisService = speechSynthesisService
        self.faceTrackingService = faceTrackingService
        self.isAPIKeyConfigured = !Secrets.orcaRouterAPIKey.isEmpty
        self.memoryStore = MemoryStore(llmService: llmService)
        self.hypothesisStore = HypothesisStore(llmService: llmService, sessionLog: sessionLog, memoryStore: self.memoryStore)

        observeSpeechSynthesisEvents()
        observeAudioInterruptions()
        observeRouteChanges()
        observeAppForeground()
        observeAppBackground()
        observeLLMRetryEvents()
    }

    private func observeLLMRetryEvents() {
        Task { [weak self] in
            guard let self else { return }
            for await event in self.llmService.retryEvents() {
                self.handleRetryEvent(event)
            }
        }
    }

    private func handleRetryEvent(_ event: LLMRetryEvent) {
        Self.logger.info("""
        LLMリトライ通知を受信: attempt=\(event.attempt, privacy: .public)/\(event.maxAttempts, privacy: .public) \
        delay=\(event.delay, privacy: .public) fallback=\(event.usingFallbackModel, privacy: .public)
        """)
        let fallbackNote = event.usingFallbackModel ? "代替モデルに切り替えて" : ""
        retryNotice = "混雑のため\(fallbackNote)\(Int(event.delay))秒後に再試行します（\(event.attempt)/\(event.maxAttempts)回目）"
    }

    // MARK: - 導出プロパティ

    var canSend: Bool {
        (conversationState == .idle || conversationState == .error)
            && isAPIKeyConfigured
            && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isGenerating: Bool {
        conversationState == .thinking || conversationState == .speaking
    }

    var isInputEnabled: Bool {
        conversationState == .idle || conversationState == .error
    }

    var isMicEnabled: Bool {
        isAPIKeyConfigured && (conversationState == .idle || conversationState == .error || conversationState == .listening)
    }

    var isFaceTrackingSupported: Bool {
        faceTrackingService.isSupported
    }

    /// conversationStateの変更を一箇所に集約する。変化のたびにセッションログへ記録するほか、
    /// ハンズフリー会話の状態遷移（各遷移で何を開始・停止するか）もここに集約する。
    /// - .error に入るとハンズフリーセッションは終了する（再開はユーザーの明示操作に委ねる）
    /// - .idle に入り、かつハンズフリーが有効なら、ユーザー操作を挟まず自動的に待ち受けを再開する
    /// - .thinking / .speaking では、一定時間まったく進行がない場合に強制復帰するウォッチドッグを張る
    private func setConversationState(_ newState: ConversationState) {
        guard conversationState != newState else { return }
        Self.logger.info("状態遷移: \(String(describing: self.conversationState), privacy: .public) -> \(String(describing: newState), privacy: .public)")
        conversationState = newState
        sessionLog.recordStateTransition(newState)
        scheduleStuckStateWatchdog(for: newState)
        updateInactivityWatchdog(for: newState)

        if newState == .error {
            isHandsFreeActive = false
        } else if newState == .idle, isHandsFreeActive {
            startListening()
        } else if newState == .idle, pendingFarewell {
            pendingFarewell = false
            playFarewell()
        }
    }

    /// LLM応答・音声再生の進行があったことを記録する。ウォッチドッグはこの時刻を基準に判定する。
    private func markProgress() {
        lastProgressAt = Date()
    }

    /// thinking/speakingが一定時間まったく進行しない場合に強制的にidleへ戻す安全網。
    /// listeningは「ユーザーがまだ話していないだけ」の可能性があるため対象外とする。
    private func scheduleStuckStateWatchdog(for state: ConversationState) {
        stuckStateWatchdogTask?.cancel()
        stuckStateWatchdogTask = nil

        guard state == .thinking || state == .speaking else { return }
        lastProgressAt = Date()
        let expectedState = state

        stuckStateWatchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(HandsFreeTuning.stuckStateCheckInterval))
                guard !Task.isCancelled, let self else { return }
                guard self.conversationState == expectedState else { return }

                let idleFor = Date().timeIntervalSince(self.lastProgressAt ?? Date())
                if idleFor >= HandsFreeTuning.stuckStateTimeout {
                    Self.logger.error("""
                    状態\(String(describing: expectedState), privacy: .public)が\
                    \(idleFor, format: .fixed(precision: 1), privacy: .public)秒進行しなかったため強制復帰します
                    """)
                    self.forceRecoverFromStuckState()
                    return
                }
            }
        }
    }

    /// listening状態のあいだだけ有効な、長時間無音の監視。stuckStateWatchdogと同じポーリング方式を用い、
    /// 発話が検知されるたびにconsumeRecognition側でlastSoundDetectedAtが更新される前提で判定する。
    private func updateInactivityWatchdog(for state: ConversationState) {
        guard state == .listening, isHandsFreeActive else {
            cancelInactivityWatchdog()
            return
        }
        scheduleInactivityWatchdog()
    }

    private func scheduleInactivityWatchdog() {
        inactivityWatchdogTask?.cancel()
        lastSoundDetectedAt = Date()

        inactivityWatchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(HandsFreeTuning.stuckStateCheckInterval))
                guard !Task.isCancelled, let self else { return }
                guard self.conversationState == .listening, self.isHandsFreeActive else { return }

                let idleFor = Date().timeIntervalSince(self.lastSoundDetectedAt)
                if idleFor >= HandsFreeTuning.conversationInactivityTimeout {
                    Self.logger.info("""
                    \(idleFor, format: .fixed(precision: 1), privacy: .public)秒間発話がなかったため、\
                    音声モードを終えます
                    """)
                    self.endHandsFreeSessionDueToInactivity()
                    return
                }
            }
        }
    }

    private func cancelInactivityWatchdog() {
        inactivityWatchdogTask?.cancel()
        inactivityWatchdogTask = nil
    }

    private func endHandsFreeSessionDueToInactivity() {
        stopHandsFreeSession()
    }

    private func forceRecoverFromStuckState() {
        streamingTask?.cancel()
        streamingTask = nil
        speechSynthesisService.stop()
        Task { await speechRecognitionService.finishRecognition() }
        isHandsFreeActive = false
        errorMessage = "応答が確認できませんでした。もう一度お試しください。"
        setConversationState(.error)
    }

    // MARK: - テキスト送信（Step 1）

    func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = ""
        performSend(trimmed, inputMethod: .text)
    }

    /// テキスト送信・ハンズフリー自動送信の共通経路。
    /// ハンズフリー時は.listeningから直接.thinkingへ遷移させる（.idleを経由すると
    /// setConversationStateのハンズフリー再開ロジックが誤って先に発火してしまうため）。
    private func performSend(_ trimmed: String, inputMethod: InputMethod) {
        guard !trimmed.isEmpty,
              conversationState == .idle || conversationState == .error || conversationState == .listening,
              isAPIKeyConfigured else { return }

        errorMessage = nil
        retryNotice = nil
        ensureAudioSessionConfigured()

        let faceDescription: String?
        let faceContext: FaceContextRecord
        if !isCameraActive {
            faceDescription = nil
            faceContext = .notSent(.cameraDisabled)
        } else if !faceSignals.isFaceDetected {
            faceDescription = nil
            faceContext = .notSent(.faceNotDetected)
        } else if let described = FaceSignalDescriber.describe(faceSignals) {
            faceDescription = described
            faceContext = .sent(described)
        } else {
            faceDescription = nil
            faceContext = .notSent(.noSignificantChange)
        }

        let voiceDescription: String?
        let voiceContext: VoiceContextRecord
        let voiceSignals = pendingVoiceSignals
        pendingVoiceSignals = nil
        if inputMethod != .voice {
            voiceDescription = nil
            voiceContext = .notSent(.notVoiceInput)
        } else if let voiceSignals {
            let baseline = VoiceSignalDescriber.averageBaseline(from: sessionLog.voiceSignalSamples)
            let baselineSampleCount = sessionLog.voiceSignalSamples.count
            sessionLog.recordVoiceSignalSample(voiceSignals)
            if let baseline,
               let described = VoiceSignalDescriber.describe(current: voiceSignals, baseline: baseline, baselineSampleCount: baselineSampleCount) {
                voiceDescription = described
                voiceContext = .sent(described)
            } else if baselineSampleCount < VoiceSignalDescriber.minimumBaselineSamples {
                voiceDescription = nil
                voiceContext = .notSent(.insufficientBaseline)
            } else {
                voiceDescription = nil
                voiceContext = .notSent(.noSignificantChange)
            }
        } else {
            voiceDescription = nil
            voiceContext = .notSent(.insufficientBaseline)
        }

        // 直近の会話履歴（今回の発言・応答を含まない時点のスナップショット）
        let context = ConversationContext(
            userUtterance: trimmed,
            faceDescription: faceDescription,
            voiceDescription: voiceDescription,
            history: messages
        )

        let userMessage = ChatMessage(role: .user, content: trimmed, faceDescription: faceDescription, voiceDescription: voiceDescription)
        messages.append(userMessage)

        let assistantID = UUID()
        messages.append(ChatMessage(id: assistantID, role: .assistant, content: "", isStreaming: true))
        isGeneratingText = true
        setConversationState(.thinking)

        let turnStartedAt = Date()
        activeTurnStartedAt = turnStartedAt
        hasLoggedFirstAudioLatency = false
        streamingTask = Task { [weak self] in
            await self?.runStream(
                context: context,
                assistantID: assistantID,
                turnStartedAt: turnStartedAt,
                inputMethod: inputMethod,
                faceContext: faceContext,
                voiceContext: voiceContext
            )
        }
    }

    func stop() {
        streamingTask?.cancel()
        speechSynthesisService.stop()
    }

    private func runStream(
        context: ConversationContext,
        assistantID: UUID,
        turnStartedAt: Date,
        inputMethod: InputMethod,
        faceContext: FaceContextRecord,
        voiceContext: VoiceContextRecord
    ) async {
        var chunker = SentenceChunker()
        var failed = false
        var wasCancelled = false
        var firstTokenAt: Date?

        let responseModel = ModelSelector.responseModel(for: context.userUtterance)
        let memoryContext = MemoryContextBuilder.build(from: memoryStore.topics)
        let systemPrompt = SystemPrompt.conversation(
            faceDescription: context.faceDescription,
            voiceDescription: context.voiceDescription,
            memoryContext: memoryContext
        )
        let requestMessages = context.history + [ChatMessage(role: .user, content: context.userUtterance)]

        do {
            let stream = llmService.streamResponse(for: requestMessages, model: responseModel, systemPrompt: systemPrompt)
            for try await delta in stream {
                if firstTokenAt == nil {
                    firstTokenAt = Date()
                    retryNotice = nil
                }
                markProgress()
                appendDelta(delta, to: assistantID)
                for sentence in chunker.append(delta) {
                    speechSynthesisService.enqueue(sentence)
                }
            }
            if let remainder = chunker.flushRemainder() {
                speechSynthesisService.enqueue(remainder)
            }
        } catch is CancellationError {
            wasCancelled = true
            retryNotice = nil
            speechSynthesisService.stop()
        } catch {
            failed = true
            retryNotice = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "予期しないエラーが発生しました。"
            removeMessageIfEmpty(assistantID)
        }

        finishStreamingText(assistantID)
        isGeneratingText = false
        streamingTask = nil
        let completedAt = Date()

        if failed {
            setConversationState(.error)
        } else if !isSpeakingAudio {
            // 読み上げがまだ続いている場合はイベント監視側がidleへ遷移させる
            setConversationState(.idle)
        }

        // 論証構造の抽出は応答本文が確定してから行う（読み上げ開始の遅延要因にしない）
        let wasSimpleUtterance = !ModelSelector.shouldStructure(utterance: context.userUtterance)
        var structuringModelUsed: String?
        var argument: ToulminArgument?
        if !failed, !wasCancelled, !wasSimpleUtterance {
            structuringModelUsed = ModelSelector.structuringModel
            argument = await requestArgumentStructure(context: context, assistantID: assistantID)
        }

        let responseText = messages.first(where: { $0.id == assistantID })?.content ?? ""

        // 記憶の抽出は完全に独立したバックグラウンド処理。会話の応答速度には一切影響しない。
        if !failed, !wasCancelled {
            memoryStore.extractAndStore(userUtterance: context.userUtterance, assistantResponse: responseText)
        }

        sessionLog.recordTurn(TurnLog(
            timestamp: turnStartedAt,
            userUtterance: context.userUtterance,
            inputMethod: inputMethod,
            faceContext: faceContext,
            voiceContext: voiceContext,
            responseModel: responseModel,
            wasSimpleUtterance: wasSimpleUtterance,
            structuringModel: structuringModelUsed,
            assistantResponse: responseText,
            toulminArgument: argument,
            timeToFirstToken: firstTokenAt.map { $0.timeIntervalSince(turnStartedAt) },
            timeToCompletion: (failed || wasCancelled) ? nil : completedAt.timeIntervalSince(turnStartedAt)
        ))
    }

    @discardableResult
    private func requestArgumentStructure(context: ConversationContext, assistantID: UUID) async -> ToulminArgument? {
        guard let spokenResponse = messages.first(where: { $0.id == assistantID })?.content,
              !spokenResponse.isEmpty else { return nil }

        let requestMessages = context.history + [
            ChatMessage(role: .user, content: context.userUtterance),
            ChatMessage(role: .assistant, content: spokenResponse)
        ]

        do {
            let argument = try await llmService.completeStructured(
                for: requestMessages,
                model: ModelSelector.structuringModel,
                systemPrompt: SystemPrompt.toulminStructuring,
                as: ToulminArgument.self
            )
            if let index = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[index].toulminArgument = argument
            }
            return argument
        } catch {
            // 構造化に失敗しても会話は継続する（プレーンテキストの応答のみで完結させる）
            return nil
        }
    }

    private func appendDelta(_ delta: String, to assistantID: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == assistantID }) else { return }
        messages[index].content += delta
    }

    private func finishStreamingText(_ assistantID: UUID) {
        if let index = messages.firstIndex(where: { $0.id == assistantID }) {
            messages[index].isStreaming = false
        }
    }

    private func removeMessageIfEmpty(_ assistantID: UUID) {
        if let index = messages.firstIndex(where: { $0.id == assistantID }), messages[index].content.isEmpty {
            messages.remove(at: index)
        }
    }

    // MARK: - 音声合成イベント監視

    private func observeSpeechSynthesisEvents() {
        Task { [weak self] in
            guard let self else { return }
            for await event in self.speechSynthesisService.events() {
                self.handleSpeechSynthesisEvent(event)
            }
        }
    }

    private func handleSpeechSynthesisEvent(_ event: SpeechSynthesisEvent) {
        switch event {
        case .speechDidBegin:
            logFirstAudioLatencyIfNeeded()
            isSpeakingAudio = true
            lastSpeechPulseAt = Date()
            markProgress()
            if conversationState != .error {
                setConversationState(.speaking)
            }
        case .wordBoundary:
            lastSpeechPulseAt = Date()
            markProgress()
        case .queueDidDrain:
            isSpeakingAudio = false
            if conversationState == .speaking {
                setConversationState(isGeneratingText ? .thinking : .idle)
            }
        case .ttsUsage(let characterCount):
            sessionLog.recordTTSUsage(characterCount: characterCount)
        }
    }

    /// 送信から最初の音声が鳴るまでの時間を計測する。エンジン切り替えの比較検証に使う。
    private func logFirstAudioLatencyIfNeeded() {
        guard !hasLoggedFirstAudioLatency, let start = activeTurnStartedAt else { return }
        hasLoggedFirstAudioLatency = true
        let elapsed = Date().timeIntervalSince(start)
        Self.latencyLogger.info("""
        最初の音声再生開始までの時間: engine=\(TTSPreference.engine.rawValue, privacy: .public) \
        elapsed=\(elapsed, format: .fixed(precision: 3), privacy: .public)秒
        """)
    }

    // MARK: - 音声入力（ハンズフリー会話）

    /// マイクボタンの唯一の操作。listening中に押せばハンズフリーセッション自体を終了し、
    /// それ以外なら新しいハンズフリーセッションを開始する。
    func toggleListening() {
        if conversationState == .listening {
            stopHandsFreeSession()
        } else {
            startHandsFreeSession()
        }
    }

    /// ハンズフリーセッションを開始する。すぐにlistening状態へ入るのではなく、まず固定の迎えの一言を
    /// LLMを介さず即座に再生し（待たせないことを優先）、その再生完了に伴う.idleへの遷移をきっかけに
    /// setConversationState側の既存ロジックが自然にstartListening()へつなげる。
    private func startHandsFreeSession() {
        errorMessage = nil
        retryNotice = nil
        isMicPermissionDenied = false
        pendingFarewell = false
        if conversationState == .error {
            setConversationState(.idle)
        }
        isHandsFreeActive = true
        playVoiceModeGreeting()
    }

    private func playVoiceModeGreeting() {
        ensureAudioSessionConfigured()
        let isFirstTime = VoiceModeIntroductionState.markEnteredAndReturnWasFirstTime()
        speechSynthesisService.enqueue(VoiceModeGreeting.greeting(isFirstTime: isFirstTime))
    }

    /// ハンズフリーセッションを終了する。直前の発話が認識できていれば、それは送信された上で終了する
    /// （commitTranscript側で isHandsFreeActive の値を見て再待ち受けするかどうかを判断するため、
    /// ここで先にfalseにしておくことで「この発話を最後に終了する」動作になる）。
    /// playsFarewellがtrueの場合、次にidleへ到達したタイミングで締めの一言を再生する
    /// （バックグラウンド遷移による強制終了時など、TTS再生が適さない場合はfalseを渡す）。
    private func stopHandsFreeSession(playsFarewell: Bool = true) {
        isHandsFreeActive = false
        if playsFarewell {
            pendingFarewell = true
        }
        stopListening()
    }

    private func playFarewell() {
        ensureAudioSessionConfigured()
        speechSynthesisService.enqueue(VoiceModeGreeting.farewell)
    }

    private func startListening() {
        guard isMicEnabled, conversationState != .listening else { return }
        errorMessage = nil
        liveTranscript = ""
        audioLevel = 0
        pendingVoiceSignals = nil
        ensureAudioSessionConfigured()

        Task { [weak self] in
            guard let self else { return }

            let status = SpeechPermissionCoordinator.currentStatus()
            let resolvedStatus = status == .notDetermined ? await SpeechPermissionCoordinator.requestAccess() : status

            guard resolvedStatus == .authorized else {
                self.isMicPermissionDenied = true
                self.setConversationState(.error)
                self.errorMessage = "マイクと音声認識の利用が許可されていません。"
                return
            }

            self.isMicPermissionDenied = false

            // 急かされている印象を避けるため、マイクを開く前にごく短い間（呼吸1回分程度）を置く。
            try? await Task.sleep(for: .seconds(HandsFreeTuning.listeningEntryPause))
            guard !Task.isCancelled, self.isMicEnabled, self.conversationState != .listening else { return }

            self.setConversationState(.listening)
            self.listeningTask = Task { await self.consumeRecognition() }
        }
    }

    func stopListening() {
        guard conversationState == .listening else {
            Self.logger.info("stopListening()が呼ばれたが、conversationStateがlisteningではない: \(String(describing: self.conversationState), privacy: .public)")
            return
        }
        Self.logger.info("finishRecognition()を呼び出します（マイク停止操作）")
        Task { await speechRecognitionService.finishRecognition() }
    }

    private func consumeRecognition() async {
        // 無音区間の検出用。発話が一度も検出されないまま無音が続くだけでは確定させない
        // （liveTranscriptが空のうちは判定しない）ため、開始時刻をそのまま基準にしておいてよい。
        // lastSoundDetectedAtはプロパティ（音声モードの長時間無音タイムアウト監視と共有するため）。
        lastSoundDetectedAt = Date()
        var hasTriggeredAutoCommit = false

        do {
            for try await event in speechRecognitionService.startRecognition() {
                switch event {
                case .partialTranscript(let text):
                    liveTranscript = text
                case .finalTranscript(let text):
                    Self.logger.info("finalTranscriptイベントを受信: length=\(text.count, privacy: .public)")
                    liveTranscript = text
                    commitTranscript()
                case .voiceSignals(let signals):
                    pendingVoiceSignals = signals
                case .audioLevel(let level):
                    audioLevel = level

                    guard !hasTriggeredAutoCommit else { break }

                    if level > HandsFreeTuning.silenceAudioLevelThreshold {
                        lastSoundDetectedAt = Date()
                    } else if isHandsFreeActive,
                              !liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                              Date().timeIntervalSince(lastSoundDetectedAt) >= HandsFreeTuning.silenceDurationForAutoSend {
                        Self.logger.info("無音を\(HandsFreeTuning.silenceDurationForAutoSend, privacy: .public)秒検出したため、発話終了とみなし確定します")
                        hasTriggeredAutoCommit = true
                        Task { await speechRecognitionService.finishRecognition() }
                    }
                }
            }
            Self.logger.info("音声認識ストリームが正常終了しました")
        } catch {
            Self.logger.error("音声認識ストリームがエラーで終了しました: \(error.localizedDescription, privacy: .public)")
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "音声認識でエラーが発生しました。"
            setConversationState(.error)
            liveTranscript = ""
            audioLevel = 0
        }

        if conversationState == .listening {
            Self.logger.info("ストリーム終了時点でconversationStateがlisteningのまま残っていたため、idleへ復帰させます")
            setConversationState(.idle)
        }
        listeningTask = nil
    }

    /// 認識確定を送信へつなげる唯一の経路。ハンズフリー中は自動的に送信し、
    /// 認識結果が空または極端に短い場合は送信せず待ち受けへ戻る（.idleに遷移させることで
    /// setConversationState側のハンズフリー再開ロジックに委ねる）。
    private func commitTranscript() {
        let trimmed = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        liveTranscript = ""
        audioLevel = 0
        Self.logger.info("commitTranscript(): trimmedLength=\(trimmed.count, privacy: .public)")

        guard trimmed.count >= HandsFreeTuning.minimumTranscriptLength else {
            Self.logger.info("認識結果が空または短すぎるため送信をスキップします")
            setConversationState(.idle)
            return
        }

        performSend(trimmed, inputMethod: .voice)
    }

    // MARK: - オーディオセッション

    private func ensureAudioSessionConfigured() {
        guard !isAudioSessionConfigured else { return }
        do {
            try AudioSessionCoordinator.configureForVoiceChat()
            isAudioSessionConfigured = true
        } catch {
            errorMessage = "オーディオセッションの準備に失敗しました: \(error.localizedDescription)"
        }
    }

    private func observeAudioInterruptions() {
        Task { [weak self] in
            guard let self else { return }
            for await notification in NotificationCenter.default.notifications(named: AVAudioSession.interruptionNotification) {
                guard let info = notification.userInfo,
                      let rawValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: rawValue),
                      type == .began else { continue }
                self.handleAudioInterruption()
            }
        }
    }

    private func observeRouteChanges() {
        Task { [weak self] in
            guard let self else { return }
            for await notification in NotificationCenter.default.notifications(named: AVAudioSession.routeChangeNotification) {
                guard let info = notification.userInfo,
                      let rawValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: rawValue),
                      reason == .oldDeviceUnavailable else { continue }
                self.handleAudioInterruption()
            }
        }
    }

    private func handleAudioInterruption() {
        // 電話の着信やSiriなど外部要因の割り込みでは、安全のためハンズフリーセッションごと終了する。
        // 自動再開はユーザーの明示操作に委ねる。
        isHandsFreeActive = false
        if conversationState == .listening {
            Task { await speechRecognitionService.finishRecognition() }
        }
        if isSpeakingAudio {
            speechSynthesisService.stop()
        }
    }

    private func observeAppForeground() {
        Task { [weak self] in
            guard let self else { return }
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                self.refreshMicPermissionStatus()
            }
        }
    }

    private func refreshMicPermissionStatus() {
        guard isMicPermissionDenied else { return }
        if SpeechPermissionCoordinator.currentStatus() != .denied {
            isMicPermissionDenied = false
            if conversationState == .error {
                setConversationState(.idle)
            }
        }
    }

    private func observeAppBackground() {
        Task { [weak self] in
            guard let self else { return }
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didEnterBackgroundNotification) {
                if self.isCameraActive {
                    self.stopCameraTracking()
                }
                if self.isHandsFreeActive {
                    // バックグラウンド遷移による強制終了ではTTS再生が適さないため、締めの一言は再生しない。
                    self.stopHandsFreeSession(playsFarewell: false)
                }
            }
        }
    }

    // MARK: - 顔トラッキング（確認用途。LLMへの統合は行わない）

    func startCameraTracking() {
        guard !isCameraActive else { return }
        guard faceTrackingService.isSupported else {
            errorMessage = "この端末は顔トラッキングに対応していません。"
            return
        }

        Task { [weak self] in
            guard let self else { return }

            let status = FacePermissionCoordinator.currentStatus()
            let resolvedStatus = status == .notDetermined ? await FacePermissionCoordinator.requestAccess() : status

            guard resolvedStatus == .authorized else {
                self.isCameraPermissionDenied = true
                self.errorMessage = "カメラの利用が許可されていません。"
                return
            }

            self.isCameraPermissionDenied = false
            self.isCameraActive = true
            self.faceTrackingTask = Task { await self.consumeFaceSignals() }
        }
    }

    func stopCameraTracking() {
        faceTrackingService.stopTracking()
        faceTrackingTask?.cancel()
        faceTrackingTask = nil
        isCameraActive = false
        faceSignals = .neutral
    }

    private func consumeFaceSignals() async {
        for await signals in faceTrackingService.startTracking() {
            faceSignals = signals
            recordFaceSignalSampleIfNeeded(signals)
        }
        isCameraActive = false
        faceTrackingTask = nil
    }

    /// FaceTrackingServiceからの更新（最大約12Hz）をさらに1.5秒間隔へ間引いてセッションログへ記録する。
    private func recordFaceSignalSampleIfNeeded(_ signals: FaceSignals) {
        let now = Date()
        if let last = lastFaceSampleAt, now.timeIntervalSince(last) < 1.5 { return }
        lastFaceSampleAt = now
        sessionLog.recordFaceSignalSample(signals, at: now)
    }
}
