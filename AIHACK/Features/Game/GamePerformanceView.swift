import SwiftUI

/// 演技画面。カウントダウン→録音インジケーターの2状態を1画面内で切り替える。
/// カメラプレビューは表示しない（既存方針を継続。映像は保存・表示しない）。
struct GamePerformanceView: View {
    enum Mode: Equatable {
        case countdown(Int)
        case recording(audioLevel: Float)
    }

    let prompt: String
    let mode: Mode

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            Spacer()

            Text("『\(prompt)』と言ってください")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
                .accessibilityLabel("お題は \(prompt) です")

            Spacer()

            indicator

            Spacer()
        }
        .padding(Spacing.xl)
    }

    @ViewBuilder
    private var indicator: some View {
        switch mode {
        case .countdown(let n):
            CountdownNumberView(number: n, reduceMotion: reduceMotion)
        case .recording(let level):
            RecordingIndicatorView(audioLevel: level, reduceMotion: reduceMotion)
        }
    }
}

private struct CountdownNumberView: View {
    let number: Int
    let reduceMotion: Bool

    var body: some View {
        Text("\(number)")
            .font(.system(size: 96, weight: .heavy, design: .rounded))
            .foregroundStyle(GamePalette.titleGradient)
            .id(number)
            .transition(reduceMotion ? .identity : .scale.combined(with: .opacity))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: number)
            .accessibilityLabel("\(number)")
    }
}

private struct RecordingIndicatorView: View {
    let audioLevel: Float
    let reduceMotion: Bool

    private var ringExpansion: CGFloat {
        reduceMotion ? 0 : CGFloat(min(max(audioLevel, 0), 1)) * 60
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.red.opacity(0.25), lineWidth: 6)
                .frame(width: 140, height: 140)

            Circle()
                .stroke(Color.red, lineWidth: 6)
                .frame(width: 140 + ringExpansion, height: 140 + ringExpansion)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: audioLevel)

            Image(systemName: "mic.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.red)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("録音中")
    }
}

#Preview {
    GamePerformanceView(prompt: "え", mode: .countdown(3))
}
