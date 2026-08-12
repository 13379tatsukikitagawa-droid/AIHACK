import SwiftUI

/// 顔トラッキングの特徴量を確認するための開発用画面。
/// LLMへの統合やアバター表示は行わず、取得できていることの確認に留める。
struct FaceDebugView: View {
    let viewModel: ChatViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    privacyNotice
                    trackingToggle

                    if viewModel.isCameraPermissionDenied {
                        cameraPermissionBanner
                    } else if !viewModel.isFaceTrackingSupported {
                        unsupportedBanner
                    } else {
                        detectionStatus
                        featureGauges
                    }
                }
                .padding(Spacing.lg)
            }
            .background(Color(.systemBackground))
            .navigationTitle("表情トラッキング（開発用）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
                }
            }
        }
    }

    private var privacyNotice: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(.green)
            Text("映像は保存・送信されません。数値化された特徴量のみをこの端末上で処理しています。")
                .font(Typography.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var trackingToggle: some View {
        Toggle(isOn: Binding(
            get: { viewModel.isCameraActive },
            set: { isOn in
                if isOn {
                    viewModel.startCameraTracking()
                } else {
                    viewModel.stopCameraTracking()
                }
            }
        )) {
            Text("会話中もカメラを有効にする")
                .font(Typography.subheadline)
        }
        .disabled(!viewModel.isFaceTrackingSupported)
        .padding(Spacing.md)
        .frame(minHeight: Layout.minTapTarget)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
        .accessibilityLabel("会話中もカメラを有効にする")
    }

    private var cameraPermissionBanner: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "camera.metering.unknown")
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("カメラが許可されていません")
                    .font(Typography.headline)
                Text("表情トラッキングを使うには、設定アプリでカメラを許可してください。")
                    .font(Typography.footnote)
                    .foregroundStyle(.secondary)
                Button("設定を開く", action: openSettings)
                    .font(Typography.footnote)
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: Layout.minTapTarget)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
    }

    private var unsupportedBanner: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("この端末は顔トラッキング（TrueDepthカメラ）に対応していません。")
                .font(Typography.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private var detectionStatus: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: viewModel.faceSignals.isFaceDetected ? "face.smiling.fill" : "questionmark.circle")
                .font(Typography.title2)
                .foregroundStyle(viewModel.faceSignals.isFaceDetected ? Color.green : Color.secondary)
            Text(viewModel.faceSignals.isFaceDetected ? "顔を検出しています" : "顔が検出されていません")
                .font(Typography.headline)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var featureGauges: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            FeatureGaugeRow(title: "笑顔", value: viewModel.faceSignals.smile, range: 0...1)
            FeatureGaugeRow(title: "眉の上がり", value: viewModel.faceSignals.browRaise, range: 0...1)
            FeatureGaugeRow(title: "眉のより", value: viewModel.faceSignals.browFurrow, range: 0...1)
            FeatureGaugeRow(title: "目の開き", value: viewModel.faceSignals.eyeOpenness, range: 0...1)
            FeatureGaugeRow(title: "視線（左右）", value: viewModel.faceSignals.gazeHorizontal, range: -1...1)
            FeatureGaugeRow(title: "視線（上下）", value: viewModel.faceSignals.gazeVertical, range: -1...1)
            FeatureGaugeRow(title: "口の開き", value: viewModel.faceSignals.jawOpen, range: 0...1)
            FeatureGaugeRow(title: "頭の向き（左右）", value: viewModel.faceSignals.headYaw, range: -1...1)
            FeatureGaugeRow(title: "頭の向き（上下）", value: viewModel.faceSignals.headPitch, range: -1...1)
            FeatureGaugeRow(title: "頭の傾き", value: viewModel.faceSignals.headRoll, range: -1...1)
        }
    }
}

private struct FeatureGaugeRow: View {
    let title: String
    let value: Float
    let range: ClosedRange<Float>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isSigned: Bool { range.lowerBound < 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(title)
                    .font(Typography.subheadline)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(Typography.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: isSigned ? .center : .leading) {
                    Capsule()
                        .fill(Color(.secondarySystemBackground))

                    if isSigned {
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: signedBarWidth(totalWidth: geometry.size.width))
                            .offset(x: signedBarOffset(totalWidth: geometry.size.width))
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: value)
                    } else {
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: unsignedBarWidth(totalWidth: geometry.size.width))
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: value)
                    }
                }
            }
            .frame(height: Layout.gaugeBarHeight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(String(format: "%.2f", value))
    }

    private var clampedValue: Float {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private func unsignedBarWidth(totalWidth: CGFloat) -> CGFloat {
        let fraction = (clampedValue - range.lowerBound) / (range.upperBound - range.lowerBound)
        return max(2, totalWidth * CGFloat(fraction))
    }

    private func signedBarWidth(totalWidth: CGFloat) -> CGFloat {
        let maxAbs = max(abs(range.lowerBound), abs(range.upperBound))
        let fraction = maxAbs > 0 ? abs(clampedValue) / maxAbs : 0
        return max(2, (totalWidth / 2) * CGFloat(fraction))
    }

    private func signedBarOffset(totalWidth: CGFloat) -> CGFloat {
        let width = signedBarWidth(totalWidth: totalWidth)
        return clampedValue >= 0 ? width / 2 : -width / 2
    }
}

#Preview {
    FaceDebugView(viewModel: ChatViewModel())
}
