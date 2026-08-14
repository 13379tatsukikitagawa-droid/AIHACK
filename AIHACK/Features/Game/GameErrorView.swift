import SwiftUI
import UIKit

/// 通信失敗・権限未許可を示す画面。ゲームを停止させず、必ず先に進める導線を用意する。
/// はぁって言うゲーム・30秒プレゼンの両方で共用する、Game機能内の共通コンポーネント。
struct GameErrorView: View {
    /// trueの場合「もう一度試す」ボタンを表示する（通信エラー等、録音済みデータでの再試行が可能な場合）。
    let canRetry: Bool
    /// trueの場合「設定を開く」ボタンを表示する（マイク・カメラ等の権限拒否の場合）。
    let isPermissionIssue: Bool
    let message: String
    /// 前の画面に戻るボタンのラベル（呼び出し元の文脈に応じて指定する）。
    let backLabel: String
    let onRetry: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            Image(systemName: iconName)
                .font(.system(size: 56))
                .foregroundStyle(.orange)

            Text(message)
                .font(Typography.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            if canRetry {
                Button(action: onRetry) {
                    Text("もう一度試す")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: Layout.minTapTarget)
                        .background(GamePalette.actionGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Spacing.xl)
            }

            if isPermissionIssue {
                Button("設定を開く", action: openSettings)
                    .font(.system(.headline, design: .rounded))
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: Layout.minTapTarget)
            }

            Button(backLabel, action: onBack)
                .frame(minHeight: Layout.minTapTarget)

            Spacer()
        }
        .padding(Spacing.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }

    private var iconName: String {
        isPermissionIssue ? "mic.slash.fill" : "wifi.exclamationmark"
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    GameErrorView(
        canRetry: true,
        isPermissionIssue: false,
        message: "通信に失敗しました。もう一度お試しください。",
        backLabel: "カード選択に戻る",
        onRetry: {},
        onBack: {}
    )
}
