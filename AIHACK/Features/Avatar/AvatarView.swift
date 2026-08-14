import SwiftUI

/// SwiftUIのCanvas/Shapeのみで構成する抽象的なアバター表示。
/// 人間の顔は模写せず、常時わずかに呼吸する「ブロブ」形状で生命感を表現する。
/// 状態(ConversationState)ごとに変形パターンを切り替え、聞いている状態ではマイク音量、
/// 話している状態では発話タイミングに同期して形状が変化する。
///
/// TimelineView(.animation)は表示中のみ毎フレーム再評価され、他の作業（ARSessionの
/// カメラ処理・音声認識のバッファ処理・音声合成のdelegateコールバック）はいずれも
/// 専用のバックグラウンドスレッド/シリアルキューで行われるため、MainActor上で行う
/// このビューの描画計算（三角関数少数回・10点程度のパス構築）はごく軽量に保っている。
struct AvatarView: View {
    let state: ConversationState
    let audioLevel: Float
    let lastSpeechPulseAt: Date?
    /// カメラが有効かつ顔検出時の笑顔レベル(0...1)。無効時は0を渡す。
    let smileLevel: Float
    /// 音声モード（ハンズフリーセッション）中、部屋の照明を落とすような落ち着いたトーンにするかどうか。
    /// trueの間、既存のradial gradientの彩度をわずかに下げる。会話の状態遷移そのものには影響しない。
    let isCalmMode: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let pointCount = 10

    var body: some View {
        Group {
            if reduceMotion {
                Canvas { context, size in
                    draw(context: context, size: size, now: Self.staticPhase(for: state), reactive: false)
                }
            } else {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        draw(
                            context: context,
                            size: size,
                            now: timeline.date.timeIntervalSinceReferenceDate,
                            reactive: true
                        )
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .saturation(isCalmMode ? 0.85 : 1.0)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: isCalmMode)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("AIアバター")
        .accessibilityValue(state.displayLabel)
    }

    private func draw(context: GraphicsContext, size: CGSize, now: TimeInterval, reactive: Bool) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let baseRadius = Double(min(size.width, size.height)) * 0.32

        let path = blobPath(center: center, baseRadius: baseRadius, now: now, reactive: reactive)
        let color = AvatarPalette.color(for: state)

        context.fill(
            path,
            with: .radialGradient(
                Gradient(colors: [color.opacity(0.9), color.opacity(0.4)]),
                center: center,
                startRadius: 0,
                endRadius: baseRadius * 1.3
            )
        )
    }

    private func blobPath(center: CGPoint, baseRadius: Double, now: TimeInterval, reactive: Bool) -> Path {
        var points: [CGPoint] = []
        for i in 0..<Self.pointCount {
            let angle = (Double(i) / Double(Self.pointCount)) * 2 * .pi
            let r = radius(at: angle, now: now, baseRadius: baseRadius, reactive: reactive)
            points.append(CGPoint(x: center.x + CGFloat(cos(angle)) * r, y: center.y + CGFloat(sin(angle)) * r))
        }

        var path = Path()
        guard let first = points.first, let last = points.last else { return path }

        path.move(to: midpoint(last, first))
        for i in 0..<points.count {
            let current = points[i]
            let next = points[(i + 1) % points.count]
            path.addQuadCurve(to: midpoint(current, next), control: current)
        }
        path.closeSubpath()
        return path
    }

    /// 呼吸と笑顔への反応は常時の性質のため、静止表現(Reduce Motion時)でも残す。
    /// マイク音量・発話パルスなど時々刻々変化する入力への反応のみreactiveで無効化する。
    private func radius(at angle: Double, now: TimeInterval, baseRadius: Double, reactive: Bool) -> Double {
        let breath = sin(now * 0.6) * baseRadius * 0.04
        let smileBoost = Double(smileLevel) * baseRadius * 0.03
        let calm = baseRadius + breath + smileBoost

        guard reactive else { return calm }

        switch state {
        case .idle:
            return calm

        case .listening:
            let level = Double(min(max(audioLevel, 0), 1))
            let jitter = sin(angle * 3 + now * 4) * baseRadius * 0.02 * level
            // 無音時でも完全に静止させず、相槌のようなごく小さな揺れを常時残すことで
            // 「聞いている」気配を伝える。周期をjitterとずらし、単調な脈動に見えないようにする。
            let presenceRipple = sin(angle * 1.7 - now * 0.9) * baseRadius * 0.015
            let pulse = level * baseRadius * 0.12
            return baseRadius + breath * 0.6 + pulse + jitter + presenceRipple + smileBoost

        case .thinking:
            let wave = sin(angle * 3 - now * 1.8) * baseRadius * 0.08
            return baseRadius + breath * 0.5 + wave + smileBoost

        case .speaking:
            let elapsed = lastSpeechPulseAt.map { now - $0.timeIntervalSinceReferenceDate } ?? .infinity
            let decay = max(0, 1 - elapsed / 0.28)
            let pulse = decay * baseRadius * 0.16
            let ripple = sin(angle * 5 + now * 6) * baseRadius * 0.03 * decay
            return baseRadius + breath * 0.5 + pulse + ripple + smileBoost

        case .error:
            return calm
        }
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    /// Reduce Motion時、状態ごとに異なる静止シルエットになるよう固定した時刻を割り当てる。
    private static func staticPhase(for state: ConversationState) -> TimeInterval {
        switch state {
        case .idle: return 0
        case .listening: return 0.4
        case .thinking: return 0.8
        case .speaking: return 1.2
        case .error: return 0
        }
    }
}

#Preview {
    AvatarView(state: .speaking, audioLevel: 0.4, lastSpeechPulseAt: Date(), smileLevel: 0.3, isCalmMode: false)
        .padding(40)
}
