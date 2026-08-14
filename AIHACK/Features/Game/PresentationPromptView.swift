import SwiftUI

/// お題提示画面。準備時間中もお題を表示し続けたまま、カウントダウンだけを切り替える。
struct PresentationPromptView: View {
    enum Mode: Equatable {
        case waiting
        case preparing(Int)
    }

    let prompt: String
    let mode: Mode
    let onStart: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            Spacer()

            VStack(spacing: Spacing.sm) {
                Text("お題")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                Text(prompt)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            switch mode {
            case .waiting:
                waitingContent
            case .preparing(let n):
                preparingContent(n)
            }

            Spacer()
        }
        .padding(Spacing.xl)
    }

    private var waitingContent: some View {
        VStack(spacing: Spacing.md) {
            Button(action: onStart) {
                Text("はじめる")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.heavy)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: Layout.minTapTarget + 8)
                    .background(GamePalette.presentationGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.xl)
            .accessibilityLabel("はじめる。準備時間5秒のあと、30秒のプレゼンが始まります")

            Text("準備時間5秒のあと、30秒のプレゼンが始まります")
                .font(Typography.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func preparingContent(_ n: Int) -> some View {
        VStack(spacing: Spacing.sm) {
            Text("\(n)")
                .font(.system(size: 80, weight: .heavy, design: .rounded))
                .foregroundStyle(GamePalette.presentationGradient)
                .id(n)
                .transition(reduceMotion ? .identity : .scale.combined(with: .opacity))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: n)
                .accessibilityLabel("\(n)")

            Text("準備してください")
                .font(Typography.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    PresentationPromptView(prompt: "このアプリの魅力を売り込んでください", mode: .waiting, onStart: {})
}
