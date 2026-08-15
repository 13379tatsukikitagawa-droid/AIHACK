import Foundation
import Observation
import os

/// 「30秒プレゼン」ゲームの状態と進行を管理する。ChatViewModel（Mirror/会話機能）にも
/// GameViewModel（はぁって言うゲーム）にも一切依存しない、完全に独立したViewModel。
/// 採点・判定ロジックはこのファイルとServices/Game配下の専用ファイルにのみ存在する。
@MainActor
@Observable
final class PresentationViewModel {
    private static let logger = Logger(subsystem: "com.tatsukikitagawa.AIHACK", category: "Game")

    enum PresentationErrorReason: Equatable {
        case network
        case permission
    }

    enum PresentationPhase: Equatable {
        case prompt
        case preparing(Int)
        case presenting(remainingSeconds: Int)
        case scoring
        case result
        case error(reason: PresentationErrorReason, message: String)
    }

    private struct JudgingContext {
        let prompt: String
        let transcript: String
        let faceDescription: String
        let voiceDescription: String
    }

    private(set) var phase: PresentationPhase = .prompt
    private(set) var currentPrompt: String = ""
    private(set) var lastResult: PresentationScoreResult?
    private(set) var audioLevel: Float = 0
    /// 本番中の表情の推移（結果画面のグラフ用）。約0.4秒間隔で間引いて記録する。
    private(set) var faceTimeline: [FaceSignalSample] = []
    /// 本番中の音量の推移（結果画面のグラフ用）。約0.4秒間隔で間引いて記録する。
    private(set) var volumeTimeline: [PresentationVolumeSample] = []

    let isAPIKeyConfigured: Bool
    let leaderboard: Leaderboard

    private let scoreService: PresentationScoreServiceProtocol
    private let faceTrackingService: FaceTrackingServiceProtocol
    private let speechRecognitionService: SpeechRecognitionServiceProtocol

    private var previousPrompt: String?
    private var pendingContext: JudgingContext?

    private var faceTracker = PresentationFaceExpressivenessTracker()
    private var capturedTranscript = ""
    private var capturedVoiceSignals: VoiceSignals = .empty
    private var lastFaceSampleAt: Date?
    private var lastVolumeSampleAt: Date?
    /// 表情・音量の推移を間引いて記録する最小間隔。密度が高すぎるとグラフが読みにくくなるため。
    private static let timelineSampleInterval: TimeInterval = 0.4

    private var faceTrackingTask: Task<Void, Never>?
    private var voiceTask: Task<Void, Never>?

    /// leaderboardはデフォルト引数式にできない（Leaderboardが@MainActorのため、
    /// パラメータのデフォルト式は分離コンテキストの制約でinit呼び出しができない）。
    /// そのため任意のOptionalとして受け取り、本体（MainActorとして分離済み）で生成する。
    init(
        llmService: LLMServiceProtocol = OrcaRouterService(),
        faceTrackingService: FaceTrackingServiceProtocol = FaceTrackingService(),
        speechRecognitionService: SpeechRecognitionServiceProtocol = SpeechRecognitionService(),
        leaderboard: Leaderboard? = nil
    ) {
        self.faceTrackingService = faceTrackingService
        self.speechRecognitionService = speechRecognitionService
        self.scoreService = PresentationScoreService(llmService: llmService)
        self.isAPIKeyConfigured = !Secrets.orcaRouterAPIKey.isEmpty
        self.leaderboard = leaderboard ?? Leaderboard()
    }

    // MARK: - ラウンド開始

    func startFirstRound() {
        previousPrompt = nil
        currentPrompt = PresentationPrompt.random(excluding: nil)
        lastResult = nil
        pendingContext = nil
        phase = .prompt
    }

    func startNextRound() {
        let next = PresentationPrompt.random(excluding: currentPrompt)
        previousPrompt = currentPrompt
        currentPrompt = next
        lastResult = nil
        pendingContext = nil
        phase = .prompt
    }

    func returnToPrompt() {
        pendingContext = nil
        phase = .prompt
    }

    // MARK: - 準備 → 本番

    func beginPreparation() {
        guard phase == .prompt else { return }
        guard isAPIKeyConfigured else {
            phase = .error(reason: .network, message: "APIキーが未設定のため採点できません。")
            return
        }
        Task { [weak self] in await self?.runPreparationFlow() }
    }

    private func runPreparationFlow() async {
        guard await ensurePermissions() else { return }
        await runPreparingCountdown()
        await performPresentingPhase()
    }

    /// マイクは必須（拒否時は進行できない）。カメラは任意で、拒否・非対応でも
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

    private func runPreparingCountdown() async {
        for n in stride(from: PresentationTuning.preparationSeconds, through: 1, by: -1) {
            phase = .preparing(n)
            try? await Task.sleep(for: .seconds(1))
        }
    }

    // MARK: - 本番30秒（表情・声・発話内容の観測）

    private func performPresentingPhase() async {
        phase = .presenting(remainingSeconds: PresentationTuning.presentationSeconds)
        faceTracker = PresentationFaceExpressivenessTracker()
        capturedTranscript = ""
        capturedVoiceSignals = .empty
        audioLevel = 0
        faceTimeline = []
        volumeTimeline = []
        lastFaceSampleAt = nil
        lastVolumeSampleAt = nil

        faceTrackingTask = Task { [weak self] in await self?.consumeFaceSignalsForPresentation() }
        voiceTask = Task { [weak self] in await self?.consumeVoiceForPresentation() }

        for remaining in stride(from: PresentationTuning.presentationSeconds - 1, through: 0, by: -1) {
            try? await Task.sleep(for: .seconds(1))
            guard case .presenting = phase else { return }
            phase = .presenting(remainingSeconds: remaining)
        }

        await finishPresenting()
    }

    /// ユーザーによる「終了する」操作。時間内の内容のみで採点するため、直ちに締めくくる。
    func endPresentationEarly() {
        guard case .presenting = phase else { return }
        Task { [weak self] in await self?.finishPresenting() }
    }

    /// 時間切れ・早期終了のいずれからも呼ばれる。phaseの状態で二重実行を防ぐため冪等。
    private func finishPresenting() async {
        guard case .presenting = phase else { return }

        faceTrackingService.stopTracking()
        faceTrackingTask?.cancel()
        faceTrackingTask = nil

        await speechRecognitionService.finishRecognition()
        _ = await voiceTask?.value
        voiceTask = nil

        let faceDescription = PresentationFaceSignalDescriber.describe(faceTracker.summary)
        let voiceDescription = PresentationVoiceSignalDescriber.describe(capturedVoiceSignals)
        pendingContext = JudgingContext(
            prompt: currentPrompt,
            transcript: capturedTranscript,
            faceDescription: faceDescription,
            voiceDescription: voiceDescription
        )

        await performScoring()
    }

    private func consumeFaceSignalsForPresentation() async {
        for await signals in faceTrackingService.startTracking() {
            guard signals.isFaceDetected else { continue }
            faceTracker.consider(signals)

            let now = Date()
            if lastFaceSampleAt == nil || now.timeIntervalSince(lastFaceSampleAt!) >= Self.timelineSampleInterval {
                faceTimeline.append(FaceSignalSample(timestamp: now, signals: signals))
                lastFaceSampleAt = now
            }
        }
    }

    private func consumeVoiceForPresentation() async {
        do {
            for try await event in speechRecognitionService.startRecognition() {
                switch event {
                case .partialTranscript(let text):
                    capturedTranscript = text
                case .finalTranscript(let text):
                    capturedTranscript = text
                case .voiceSignals(let signals):
                    capturedVoiceSignals = signals
                case .audioLevel(let level):
                    audioLevel = level
                    let now = Date()
                    if lastVolumeSampleAt == nil || now.timeIntervalSince(lastVolumeSampleAt!) >= Self.timelineSampleInterval {
                        volumeTimeline.append(PresentationVolumeSample(timestamp: now, level: level))
                        lastVolumeSampleAt = now
                    }
                }
            }
        } catch {
            Self.logger.info("プレゼン中の音声認識がエラーで終了しました（採点は継続します）: \(error.localizedDescription, privacy: .public)")
        }
        audioLevel = 0
    }

    // MARK: - 採点

    private func performScoring() async {
        guard let context = pendingContext else { return }
        phase = .scoring

        let startedAt = Date()
        do {
            let result = try await scoreService.score(
                prompt: context.prompt,
                transcript: context.transcript,
                voiceDescription: context.voiceDescription,
                faceDescription: context.faceDescription
            )
            let elapsed = Date().timeIntervalSince(startedAt)
            Self.logger.info("プレゼン採点完了: elapsed=\(elapsed, format: .fixed(precision: 2), privacy: .public)秒 total=\(result.total, privacy: .public)")

            lastResult = result
            phase = .result
        } catch {
            Self.logger.error("プレゼン採点に失敗しました: \(error.localizedDescription, privacy: .public)")
            phase = .error(reason: .network, message: "通信に失敗しました。もう一度お試しください。")
        }
    }

    /// 通信エラーからの再試行。録音をやり直さず、直前の観測記述をそのまま使って再採点する。
    func retryScoring() {
        guard case .error(.network, _) = phase else { return }
        Task { [weak self] in await self?.performScoring() }
    }

    // MARK: - 後片付け

    func teardown() {
        faceTrackingService.stopTracking()
        faceTrackingTask?.cancel()
        faceTrackingTask = nil
        voiceTask?.cancel()
        voiceTask = nil
        Task { [weak self] in await self?.speechRecognitionService.finishRecognition() }
    }
}
