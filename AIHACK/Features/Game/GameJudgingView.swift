import SwiftUI

/// 判定中のローディング画面。既存のAvatarViewのthinking表現を流用し、待ち時間を退屈させない。
/// AvatarViewは状態を受け取って描画するだけの純粋なViewであり、ChatViewModelには依存しない。
struct GameJudgingView: View {
    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            AvatarView(state: .thinking, audioLevel: 0, lastSpeechPulseAt: nil, smileLevel: 0, isCalmMode: false)
                .frame(maxWidth: 200, maxHeight: 200)

            Text("AIが判定中…")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AIが判定中です")
    }
}

#Preview {
    GameJudgingView()
}
