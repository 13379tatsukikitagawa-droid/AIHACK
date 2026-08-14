import SwiftUI
import UIKit

/// Gameモードのコンテナ画面。ChatView(Mirror)からfullScreenCoverで独立して提示され、
/// 「はぁって言うゲーム」「30秒プレゼン」「ランキング」を切り替える。
/// 各モードのViewModel（GameViewModel / PresentationViewModel）は互いに一切依存せず、
/// このファイルが導線としてのみ両者を束ねる。
struct GameView: View {
    private enum Mode: Equatable {
        case home
        case emotionGuess
        case presentation
        case leaderboard
    }

    @State private var mode: Mode = .home
    @State private var emotionGuessViewModel = GameViewModel()
    @State private var presentationViewModel = PresentationViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            topBar
            content
        }
        .background(Color(.systemBackground))
        .onChange(of: emotionGuessViewModel.phase) { _, newPhase in
            guard mode == .emotionGuess else { return }
            UIAccessibility.post(notification: .announcement, argument: accessibilityAnnouncement(for: newPhase))
        }
        .onChange(of: presentationViewModel.phase) { _, newPhase in
            guard mode == .presentation else { return }
            UIAccessibility.post(notification: .announcement, argument: accessibilityAnnouncement(for: newPhase))
        }
        .onDisappear {
            emotionGuessViewModel.teardown()
            presentationViewModel.teardown()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .home:
            GameHomeView(
                onPlayEmotionGuess: {
                    emotionGuessViewModel.startFirstRound()
                    mode = .emotionGuess
                },
                onPlayPresentation: {
                    presentationViewModel.startFirstRound()
                    mode = .presentation
                },
                onShowLeaderboard: {
                    mode = .leaderboard
                }
            )

        case .emotionGuess:
            emotionGuessContent

        case .presentation:
            presentationContent

        case .leaderboard:
            LeaderboardView(leaderboard: presentationViewModel.leaderboard)
        }
    }

    // MARK: - はぁって言うゲーム

    @ViewBuilder
    private var emotionGuessContent: some View {
        switch emotionGuessViewModel.phase {
        case .home:
            // GameView側のmodeで遷移を管理するため、この分岐には到達しない。
            EmptyView()

        case .cardSelection:
            EmotionCardSelectionView(cards: emotionGuessViewModel.cards, onSelect: emotionGuessViewModel.selectCard)

        case .countdown(let n):
            GamePerformanceView(prompt: emotionGuessViewModel.currentPrompt, mode: .countdown(n))

        case .recording:
            GamePerformanceView(prompt: emotionGuessViewModel.currentPrompt, mode: .recording(audioLevel: emotionGuessViewModel.audioLevel))

        case .judging:
            GameJudgingView()

        case .result:
            if let result = emotionGuessViewModel.lastResult, let selectedCard = emotionGuessViewModel.selectedCard {
                GameResultView(
                    prompt: emotionGuessViewModel.currentPrompt,
                    selectedCard: selectedCard,
                    result: result,
                    streak: emotionGuessViewModel.streak,
                    onPlayAgain: emotionGuessViewModel.startNextRound
                )
            }

        case .error(let reason, let message):
            GameErrorView(
                canRetry: reason == .network,
                isPermissionIssue: reason == .permission,
                message: message,
                backLabel: "カード選択に戻る",
                onRetry: emotionGuessViewModel.retryJudging,
                onBack: emotionGuessViewModel.returnToCardSelection
            )
        }
    }

    // MARK: - 30秒プレゼン

    @ViewBuilder
    private var presentationContent: some View {
        switch presentationViewModel.phase {
        case .prompt:
            PresentationPromptView(
                prompt: presentationViewModel.currentPrompt,
                mode: .waiting,
                onStart: presentationViewModel.beginPreparation
            )

        case .preparing(let n):
            PresentationPromptView(
                prompt: presentationViewModel.currentPrompt,
                mode: .preparing(n),
                onStart: {}
            )

        case .presenting(let remaining):
            PresentationTimerView(
                remainingSeconds: remaining,
                totalSeconds: PresentationTuning.presentationSeconds,
                audioLevel: presentationViewModel.audioLevel,
                onEndEarly: presentationViewModel.endPresentationEarly
            )

        case .scoring:
            GameJudgingView()

        case .result:
            if let result = presentationViewModel.lastResult {
                PresentationResultView(
                    prompt: presentationViewModel.currentPrompt,
                    result: result,
                    onPlayAgain: presentationViewModel.startNextRound,
                    onRegister: { nickname in
                        presentationViewModel.leaderboard.register(nickname: nickname, score: result.total)
                    },
                    onShowLeaderboard: { mode = .leaderboard }
                )
            }

        case .error(let reason, let message):
            GameErrorView(
                canRetry: reason == .network,
                isPermissionIssue: reason == .permission,
                message: message,
                backLabel: "お題に戻る",
                onRetry: presentationViewModel.retryScoring,
                onBack: presentationViewModel.returnToPrompt
            )
        }
    }

    // MARK: - 共通トップバー

    private var topBar: some View {
        HStack {
            backButton
            Spacer()
            if mode == .emotionGuess {
                streakBadge
            }
            Spacer()
            closeButton
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    @ViewBuilder
    private var backButton: some View {
        if mode != .home {
            Button {
                mode = .home
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(Typography.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
            .accessibilityLabel("ゲームのトップに戻る")
        } else {
            Color.clear.frame(width: Layout.minTapTarget, height: Layout.minTapTarget)
        }
    }

    private var streakBadge: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "flame.fill")
            Text("連続正解 \(emotionGuessViewModel.streak)")
        }
        .font(Typography.subheadline)
        .fontWeight(.bold)
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(GamePalette.actionGradient, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("連続正解数 \(emotionGuessViewModel.streak)")
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(Typography.title2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
        .accessibilityLabel("ゲームを終了してMirrorに戻る")
    }

    private func accessibilityAnnouncement(for phase: GameViewModel.GamePhase) -> String {
        switch phase {
        case .home: return "感情当てゲーム"
        case .cardSelection: return "演じる感情を選んでください"
        case .countdown(let n): return "\(n)"
        case .recording: return "録音中"
        case .judging: return "AIが判定中です"
        case .result: return "結果が出ました"
        case .error(_, let message): return message
        }
    }

    private func accessibilityAnnouncement(for phase: PresentationViewModel.PresentationPhase) -> String {
        switch phase {
        case .prompt: return "お題が表示されました"
        case .preparing(let n): return "\(n)"
        case .presenting(let remaining): return "残り\(remaining)秒"
        case .scoring: return "AIが採点中です"
        case .result: return "結果が出ました"
        case .error(_, let message): return message
        }
    }
}

#Preview {
    GameView()
}
