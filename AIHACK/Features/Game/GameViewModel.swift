import Foundation
import Observation
import os

/// 感情当てゲームの状態と進行を管理する。ChatViewModel（Mirror/会話機能）とは完全に独立した
/// ViewModelであり、感情の推測・断定ロジックはこのファイルとServices/Game配下にのみ存在する。
/// 会話機能側のFaceTrackingService/SpeechRecognitionServiceは既存の観測ロジックをそのまま
/// 流用するが、インスタンスは新規に生成し、Mirror側の状態とは一切共有しない。
@MainActor
@Observable
final class GameViewModel {
    private static let logger = Logger(subsystem: "com.tatsukikitagawa.AIHACK", category: "Game")

    enum GameErrorReason: Equatable {
        case network
        case permission
    }

    enum GamePhase: Equatable {
        case home
        case cardSelection
        case countdown(Int)
        case recording
        case judging
        case result
        case error(reason: GameErrorReason, message: String)
    }

    private struct JudgingContext {
        let prompt: String
        let faceDescription: String?
        let voiceDescription: String?
    }

    private(set) var phase: GamePhase = .home
    private(set) var currentPrompt: String = ""
    private(set) var streak: Int = 0
    private(set) var selectedCard: EmotionCard?
    private(set) var lastResult: EmotionGuessResult?
    private(set) var audioLevel: Float = 0

    let cards: [EmotionCard] = EmotionCard.all
    let isAPIKeyConfigured: Bool

    private let emotionGuessService: EmotionGuessServiceProtocol
    private let faceTrackingService: FaceTrackingServiceProtocol
    private let speechRecognitionService: SpeechRecognitionServiceProtocol

    private var previousPrompt: String?
    private var pendingContext: JudgingContext?

    private var peakFaceSignals: FaceSignals?
    private var peakFaceScore: Float = -1
    private var capturedVoiceSignals: VoiceSignals = .empty

    private var faceTrackingTask: Task<Void, Never>?

    init(
        llmService: LLMServiceProtocol = OrcaRouterService(),
        faceTrackingService: FaceTrackingServiceProtocol = FaceTrackingService(),
        speechRecognitionService: SpeechRecognitionServiceProtocol = SpeechRecognitionService()
    ) {
        self.faceTrackingService = faceTrackingService
        self.speechRecognitionService = speechRecognitionService
        self.emotionGuessService = EmotionGuessService(llmService: llmService)
        self.isAPIKeyConfigured = !Secrets.orcaRouterAPIKey.isEmpty
    }

    // MARK: - ラウンド開始

    func startFirstRound() {
        streak = 0
        previousPrompt = nil
        currentPrompt = GamePrompt.random(excluding: nil)
        selectedCard = nil
        lastResult = nil
        pendingContext = nil
        phase = .cardSelection
    }

    func startNextRound() {
        let next = GamePrompt.random(excluding: currentPrompt)
        previousPrompt = currentPrompt
        currentPrompt = next
        selectedCard = nil
        lastResult = nil
        pendingContext = nil
        phase = .cardSelection
    }

    func returnToCardSelection() {
        selectedCard = nil
        pendingContext = nil
        phase = .cardSelection
    }

    // MARK: - カード選択 → 演技

    func selectCard(_ card: EmotionCard) {
        guard phase == .cardSelection else { return }
        selectedCard = card
        Task { [weak self] in await self?.beginPerformance() }
    }

    private func beginPerformance() async {
        guard isAPIKeyConfigured else {
            phase = .error(reason: .network, message: "APIキーが未設定のため判定できません。")
            return
        }
        guard await ensurePermissions() else { return }
        await runCountdown()
        await performRecordingPhase()
    }

    /// マイクは必須（拒否時はゲームを進行できない）。カメラは任意で、拒否・非対応でも
    /// 声の観測のみでゲームを続行できるようにし、体験を止めないことを優先する。
    private func ensurePermissions() async -> Bool {
        let micStatus = SpeechPermissionCoordinator.currentStatus()
        let resolvedMic = micStatus == .notDetermined ? await SpeechPermissionCoordinator.requestAccess() : micStatus
        guard resolvedMic == .authorized else {
            phase = .error(reason: .permission, message: "マイクと音声認識の利用が許可されていません。設定から許可してください。")
            return false
        }

        guard faceTrackingService.isSupported else { return true }

        let cameraStatus = FacePermissionCoordinator.currentStatus()
        if cameraStatus == .notDetermined {
            _ = await FacePermissionCoordinator.requestAccess()
        }
        return true
    }

    private func runCountdown() async {
        for n in stride(from: GameTuning.countdownSeconds, through: 1, by: -1) {
            phase = .countdown(n)
            try? await Task.sleep(for: .seconds(1))
        }
    }

    // MARK: - 録音（表情・声の観測）

    private func performRecordingPhase() async {
        phase = .recording
        resetRoundCapture()

        faceTrackingTask = Task { [weak self] in await self?.consumeFaceSignalsForRound() }
        let voiceTask = Task { [weak self] in await self?.consumeVoiceRecognitionForRound() }
        let watchdogTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(GameTuning.maxRecordingDuration))
            await self?.speechRecognitionService.finishRecognition()
        }

        // 録音処理全体が万一停止しない場合でも、ブースでの実演が固まらないよう
        // 音声処理の完了と固定の上限時間のいずれか早い方で必ず先へ進む安全網。
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await voiceTask.value }
            group.addTask {
                try? await Task.sleep(for: .seconds(GameTuning.maxRecordingDuration + GameTuning.recordingHardDeadlineGrace))
            }
            await group.next()
            group.cancelAll()
        }

        watchdogTask.cancel()
        voiceTask.cancel()
        faceTrackingService.stopTracking()
        faceTrackingTask?.cancel()
        faceTrackingTask = nil

        let faceSignals = peakFaceSignals ?? .neutral
        let voiceSignals = capturedVoiceSignals
        let roundPrompt = currentPrompt

        await proceedToJudging(prompt: roundPrompt, faceSignals: faceSignals, voiceSignals: voiceSignals)
    }

    private func resetRoundCapture() {
        peakFaceSignals = nil
        peakFaceScore = -1
        capturedVoiceSignals = .empty
        audioLevel = 0
    }

    private func consumeFaceSignalsForRound() async {
        for await signals in faceTrackingService.startTracking() {
            guard signals.isFaceDetected else { continue }
            let score = Self.expressiveness(of: signals)
            if score > peakFaceScore {
                peakFaceScore = score
                peakFaceSignals = signals
            }
        }
    }

    /// 表情の変化の大きさを表す簡易スコア。ニュートラルからの乖離が最大だった瞬間の
    /// 1サンプルを、その演技を代表する表情として採用する。
    private static func expressiveness(of signals: FaceSignals) -> Float {
        abs(signals.smile)
            + abs(signals.browRaise)
            + abs(signals.browFurrow)
            + (1 - signals.eyeOpenness)
            + abs(signals.jawOpen)
            + abs(signals.gazeHorizontal)
            + abs(signals.gazeVertical)
            + abs(signals.headYaw)
            + abs(signals.headPitch)
            + abs(signals.headRoll)
    }

    private func consumeVoiceRecognitionForRound() async {
        let startedAt = Date()
        var lastSoundAt = Date()
        var hasDetectedSpeech = false
        var hasRequestedStop = false

        do {
            for try await event in speechRecognitionService.startRecognition() {
                switch event {
                case .audioLevel(let level):
                    audioLevel = level
                    if level > GameTuning.silenceAudioLevelThreshold {
                        lastSoundAt = Date()
                        hasDetectedSpeech = true
                    }

                    guard !hasRequestedStop else { break }
                    let elapsed = Date().timeIntervalSince(startedAt)
                    let silenceElapsed = Date().timeIntervalSince(lastSoundAt)
                    if hasDetectedSpeech,
                       elapsed >= GameTuning.minimumRecordingDuration,
                       silenceElapsed >= GameTuning.silenceDurationForAutoStop {
                        hasRequestedStop = true
                        Task { [weak self] in await self?.speechRecognitionService.finishRecognition() }
                    }
                case .voiceSignals(let signals):
                    capturedVoiceSignals = signals
                case .partialTranscript, .finalTranscript:
                    break
                }
            }
        } catch {
            Self.logger.info("演技中の音声認識がエラーで終了しました（判定は継続します）: \(error.localizedDescription, privacy: .public)")
        }

        audioLevel = 0
    }

    // MARK: - 判定

    private func proceedToJudging(prompt: String, faceSignals: FaceSignals, voiceSignals: VoiceSignals) async {
        phase = .judging
        let faceDescription = FaceSignalDescriber.describe(faceSignals)
        let voiceDescription = GameVoiceSignalDescriber.describe(voiceSignals)
        pendingContext = JudgingContext(prompt: prompt, faceDescription: faceDescription, voiceDescription: voiceDescription)
        await performJudging()
    }

    private func performJudging() async {
        guard let context = pendingContext, let selectedCard else { return }

        let startedAt = Date()
        do {
            let result = try await emotionGuessService.guess(
                prompt: context.prompt,
                cards: cards,
                faceDescription: context.faceDescription,
                voiceDescription: context.voiceDescription
            )
            let elapsed = Date().timeIntervalSince(startedAt)
            Self.logger.info("判定完了: elapsed=\(elapsed, format: .fixed(precision: 2), privacy: .public)秒 guessed=\(result.guessedCard.id, privacy: .public)")

            lastResult = result
            if result.guessedCard.id == selectedCard.id {
                streak += 1
            } else {
                streak = 0
            }
            phase = .result
        } catch {
            Self.logger.error("判定に失敗しました: \(error.localizedDescription, privacy: .public)")
            phase = .error(reason: .network, message: "通信に失敗しました。もう一度お試しください。")
        }
    }

    /// 通信エラーからの再試行。録音をやり直さず、直前の観測記述をそのまま使って再判定する。
    func retryJudging() {
        guard case .error(.network, _) = phase else { return }
        Task { [weak self] in await self?.performJudging() }
    }

    // MARK: - 後片付け

    /// ゲーム画面を離れる際に呼ぶ。カメラ・マイクを確実に停止する。
    func teardown() {
        faceTrackingService.stopTracking()
        faceTrackingTask?.cancel()
        faceTrackingTask = nil
        Task { [weak self] in await self?.speechRecognitionService.finishRecognition() }
    }
}
