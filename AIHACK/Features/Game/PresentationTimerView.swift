import SwiftUI

/// プレゼン本番画面。残り時間を大きなリング＋数字で表示する。ブースでの実演を想定し、
/// 離れた場所からも見やすいサイズを優先する。カメラプレビューは表示しない。
struct PresentationTimerView: View {
    let remainingSeconds: Int
    let totalSeconds: Int
    let audioLevel: Float
    let onEndEarly: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(remainingSeconds) / Double(totalSeconds)
    }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(GamePalette.presentationGradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .linear(duration: 0.3), value: progress)

                Text("\(remainingSeconds)")
                    .font(.system(size: 100, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
            }
            .frame(width: 240, height: 240)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("残り\(remainingSeconds)秒")

            recordingIndicator

            Spacer()

            Button(role: .destructive, action: onEndEarly) {
                Text("終了する")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: Layout.minTapTarget)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, Spacing.xl)
            .accessibilityHint("ここまでの内容だけで採点します")
        }
        .padding(Spacing.xl)
    }

    private var recordingIndicator: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "mic.fill")
            Text("録音中")
        }
        .font(Typography.footnote)
        .fontWeight(.bold)
        .foregroundStyle(Color.red)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("録音中")
    }
}

#Preview {
    PresentationTimerView(remainingSeconds: 18, totalSeconds: 30, audioLevel: 0.4, onEndEarly: {})
}
