import SwiftUI
import UIKit

private enum ChatDisplayMode {
    case avatar
    case transcript
}

struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    @State private var showingFaceDebug = false
    @State private var showingAnalysis = false
    @State private var showingSettings = false
    @State private var showingMemory = false
    @State private var showingGame = false
    @State private var analysisInitialTab: AnalysisTab = .conversation
    @State private var displayMode: ChatDisplayMode = .avatar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            Group {
                switch displayMode {
                case .avatar:
                    avatarModeBody
                case .transcript:
                    transcriptModeBody
                }
            }
            .safeAreaInset(edge: .top) {
                gameEntryBanner
            }
            .safeAreaInset(edge: .bottom) {
                inputBar
                    .padding(.top, Spacing.sm)
                    .background(.bar)
            }
            .background(calmBackground)
            .navigationTitle("フィーリン君")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    displayModeToggleButton
                }
                ToolbarItem(placement: .topBarTrailing) {
                    faceTrackingButton
                }
                ToolbarItem(placement: .topBarTrailing) {
                    moreMenu
                }
            }
        }
        .onChange(of: viewModel.conversationState) { _, newState in
            UIAccessibility.post(notification: .announcement, argument: newState.displayLabel)
        }
        .onChange(of: viewModel.isHandsFreeActive) { _, isActive in
            let message = isActive ? "音声モードに入りました。まもなくAIが話しかけます。" : "音声モードを終了しました。"
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        .onChange(of: showingFaceDebug) { _, isPresented in
            // 確認画面はカメラ動作状態の「ビューア」に過ぎない。初回表示時のみ開始のきっかけを与え、
            // 閉じてもトラッキングは継続する（会話中ずっと動作させるための意図的な仕様）。
            if isPresented, !viewModel.isCameraActive {
                viewModel.startCameraTracking()
            }
        }
        .onChange(of: viewModel.isCameraActive) { _, isActive in
            if !isActive {
                showingFaceDebug = false
            }
        }
        .sheet(isPresented: $showingFaceDebug) {
            FaceDebugView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingAnalysis) {
            AnalysisView(sessionLog: viewModel.sessionLog, hypothesisStore: viewModel.hypothesisStore, initialTab: analysisInitialTab)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(memoryStore: viewModel.memoryStore)
        }
        .sheet(isPresented: $showingMemory) {
            MemoryView(memoryStore: viewModel.memoryStore)
        }
        .fullScreenCover(isPresented: $showingGame) {
            GameView()
        }
        .sheet(isPresented: crisisSupportPresented) {
            CrisisSupportView(onDismiss: viewModel.dismissCrisisSupport)
        }
    }

    /// crisisSupportTriggerの有無をBindingへ変換する。falseへ変化した場合
    /// （スワイプで閉じられた場合を含む）は必ずviewModel側の状態も一緒にクリアする。
    private var crisisSupportPresented: Binding<Bool> {
        Binding(
            get: { viewModel.crisisSupportTrigger != nil },
            set: { isPresented in
                if !isPresented { viewModel.dismissCrisisSupport() }
            }
        )
    }

    /// Mirrorの静かな世界観から意図的に区別された、ゲームコーナー（はぁって言うゲーム／
    /// 30秒プレゼン）への入口。色（GamePalette）はゲームモードのポップさを保つためあえて
    /// 変更しないが、配置は1本の帯に留め、Mirror本体を圧迫しないようにする。
    private var gameEntryBanner: some View {
        Button {
            showingGame = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "theatermasks.fill")
                    .font(.system(size: 20))
                Text("ゲーム")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.heavy)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(GamePalette.actionGradient, in: Theme.Radius.shape(Theme.Radius.medium))
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xs)
        }
        .buttonStyle(.plain)
        .frame(minHeight: Layout.minTapTarget + 12)
        .accessibilityLabel("ゲームで遊ぶ")
    }

    /// 音声モード（ハンズフリーセッション）中、部屋の照明を落とすような控えめなトーンに変化させる背景。
    /// セマンティックカラー(Theme.Palette.background)はそのままに、ごくわずかな暗さを重ねるだけに留め、
    /// ダーク/ライトいずれのモードでも破綻しないようにする。
    private var calmBackground: some View {
        Theme.Palette.background
            .overlay(Color.black.opacity(viewModel.isHandsFreeActive ? 0.035 : 0))
            .animation(Theme.Motion.animation(Theme.Motion.settle, reduceMotion: reduceMotion), value: viewModel.isHandsFreeActive)
    }

    private var displayModeToggleButton: some View {
        Button {
            displayMode = displayMode == .avatar ? .transcript : .avatar
        } label: {
            Image(systemName: displayMode == .avatar ? "list.bullet.rectangle" : "person.crop.circle")
        }
        .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
        .accessibilityLabel(displayMode == .avatar ? "会話履歴を表示" : "アバター表示に戻る")
    }

    /// 主要な操作（マイク・音声/テキスト切り替え・送信）以外はすべてこの「その他」メニューに
    /// 集約する。並び順は使用頻度の目安（メモ・仮説 → 履歴 → 設定）とする。表情トラッキングは
    /// 独立した専用ボタン（faceTrackingButton）に切り出したためここには含めない。
    /// Label(_:systemImage:)を使うことで、各項目のアイコン・ラベルの視覚的な重みが自動的に揃う。
    private var moreMenu: some View {
        Menu {
            Button {
                showingMemory = true
            } label: {
                Label(memoryMenuLabel, systemImage: "text.book.closed")
            }
            Button {
                analysisInitialTab = .hypothesis
                showingAnalysis = true
            } label: {
                Label("仮説", systemImage: "lightbulb")
            }
            Button {
                analysisInitialTab = .conversation
                showingAnalysis = true
            } label: {
                Label("履歴", systemImage: "chart.bar.doc.horizontal")
            }
            Button {
                showingSettings = true
            } label: {
                Label("設定", systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
        .accessibilityLabel("その他のメニュー")
    }

    /// 表情トラッキングは会話中の確認頻度が高いため、「その他」メニューに埋もれさせず
    /// 独立したツールバーボタンとして常時アクセスできるようにする。
    private var faceTrackingButton: some View {
        Button {
            showingFaceDebug = true
        } label: {
            Image(systemName: viewModel.isCameraActive ? "camera.fill" : "camera")
        }
        .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
        .accessibilityLabel(cameraMenuLabel)
    }

    private var memoryMenuLabel: String {
        let count = viewModel.memoryStore.topics.count
        return count > 0 ? "メモ（\(min(count, 99))）" : "メモ"
    }

    private var cameraMenuLabel: String {
        viewModel.isCameraActive ? "表情トラッキング（動作中）" : "表情トラッキング"
    }

    private var avatarModeBody: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Spacing.sm)

            AvatarView(
                state: viewModel.conversationState,
                audioLevel: viewModel.audioLevel,
                lastSpeechPulseAt: viewModel.lastSpeechPulseAt,
                smileLevel: viewModel.isCameraActive ? viewModel.faceSignals.smile : 0,
                isCalmMode: viewModel.isHandsFreeActive
            )
            .padding(.horizontal, Spacing.xxl)
            .frame(maxHeight: Layout.avatarMaxHeight)

            StatusIndicatorView(state: viewModel.conversationState)
                .padding(.top, Spacing.lg)

            // 音声モードでは応答・発言をテキストとして表示しない（対面会話を模すため）。
            // エラーだけは「何が起きたか分からない状態」を避けるため例外的にテキスト表示する。
            VStack(spacing: Spacing.sm) {
                statusBanners

                if let retryNotice = viewModel.retryNotice {
                    retryBanner(retryNotice)
                } else if let errorMessage = viewModel.errorMessage {
                    errorBanner(errorMessage)
                }
            }
            .padding(.top, Spacing.lg)
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
    }

    @ViewBuilder
    private var statusBanners: some View {
        if !viewModel.isAPIKeyConfigured {
            apiKeyWarningBanner
        }
        if viewModel.isMicPermissionDenied {
            microphonePermissionBanner
        }
        if viewModel.isCameraPermissionDenied {
            cameraPermissionBanner
        }
    }

    private var transcriptModeBody: some View {
        VStack(spacing: 0) {
            StatusIndicatorView(state: viewModel.conversationState)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xs)
            messageList
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.md) {
                    statusBanners

                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if let retryNotice = viewModel.retryNotice {
                        retryBanner(retryNotice)
                            .id("retry-banner")
                    }

                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(errorMessage)
                            .id("error-banner")
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.sm)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.retryNotice) {
                guard viewModel.retryNotice != nil else { return }
                withAnimation(Theme.Motion.gentle) {
                    proxy.scrollTo("retry-banner", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.errorMessage) {
                guard viewModel.errorMessage != nil else { return }
                withAnimation(Theme.Motion.gentle) {
                    proxy.scrollTo("error-banner", anchor: .bottom)
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastID = viewModel.messages.last?.id else { return }
        withAnimation(Theme.Motion.gentle) {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }

    private var apiKeyWarningBanner: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("APIキーが未設定です")
                    .font(Typography.headline)
                Text("OrcaRouterのAPIキーが読み込めていません。Xcodeの実行スキームに環境変数 ORCA_ROUTER_API_KEY を設定するか、Configuration/Secrets.xcconfig.example を参考に配布用の設定を行ってください。")
                    .font(Typography.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: Theme.Radius.shape(Theme.Radius.medium))
    }

    private var microphonePermissionBanner: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "mic.slash.fill")
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("マイク・音声認識が許可されていません")
                    .font(Typography.headline)
                Text("音声で話しかけるには、設定アプリでマイクと音声認識を許可してください。")
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
        .background(Theme.Palette.surface, in: Theme.Radius.shape(Theme.Radius.medium))
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
        .background(Theme.Palette.surface, in: Theme.Radius.shape(Theme.Radius.medium))
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "xmark.octagon.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(Typography.footnote)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: Theme.Radius.shape(Theme.Radius.medium))
    }

    private func retryBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            ProgressView()
                .controlSize(.small)
            Text(message)
                .font(Typography.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: Theme.Radius.shape(Theme.Radius.medium))
        .accessibilityElement(children: .combine)
    }

    private var inputBar: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            MicButton(
                state: viewModel.conversationState,
                audioLevel: viewModel.audioLevel,
                isHandsFreeActive: viewModel.isHandsFreeActive,
                isEnabled: viewModel.isMicEnabled,
                action: viewModel.toggleListening
            )

            if viewModel.isGenerating {
                stopGeneratingButton
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    private var stopGeneratingButton: some View {
        Button(role: .destructive) {
            viewModel.stop()
        } label: {
            Image(systemName: "stop.circle.fill")
                .font(Typography.title2)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
        .accessibilityLabel("生成を中断")
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(spacing: 0) {
            if isUser { Spacer(minLength: Spacing.xxl) }

            bubbleContent
                .containerRelativeFrame(.horizontal, alignment: isUser ? .trailing : .leading) { width, _ in
                    width * Layout.bubbleMaxWidthRatio
                }

            if !isUser { Spacer(minLength: Spacing.xxl) }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if message.isStreaming && message.content.isEmpty {
                TypingIndicator()
            } else {
                Text(message.content)
                    .font(Typography.body)
                    .foregroundStyle(foregroundColor)
                    .textSelection(.enabled)
            }

            if let faceDescription = message.faceDescription {
                FaceDescriptionDisclosureView(description: faceDescription)
            }

            if let voiceDescription = message.voiceDescription {
                VoiceDescriptionDisclosureView(description: voiceDescription)
            }

            if let argument = message.toulminArgument {
                ArgumentDisclosureView(argument: argument)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(backgroundColor, in: Theme.Radius.shape(Theme.Radius.medium))
    }

    private var backgroundColor: Color {
        isUser ? Theme.Palette.accent : Theme.Palette.surface
    }

    private var foregroundColor: Color {
        isUser ? Color.white : Color.primary
    }
}

private struct FaceDescriptionDisclosureView: View {
    let description: String
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Button {
                withAnimation(Theme.Motion.animation(Theme.Motion.gentle, reduceMotion: reduceMotion)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "eye.fill")
                    Text(isExpanded ? "表情情報を隠す" : "表情情報を見る")
                }
                .font(Typography.caption)
                .foregroundStyle(Color.white.opacity(0.85))
            }
            .frame(minHeight: Layout.minTapTarget, alignment: .leading)
            .accessibilityLabel(isExpanded ? "表情情報を隠す" : "表情情報を見る")

            if isExpanded {
                Text(description)
                    .font(Typography.footnote)
                    .foregroundStyle(Color.white.opacity(0.95))
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.15), in: Theme.Radius.shape(Theme.Radius.medium))
            }
        }
    }
}

private struct VoiceDescriptionDisclosureView: View {
    let description: String
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Button {
                withAnimation(Theme.Motion.animation(Theme.Motion.gentle, reduceMotion: reduceMotion)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "waveform")
                    Text(isExpanded ? "声の情報を隠す" : "声の情報を見る")
                }
                .font(Typography.caption)
                .foregroundStyle(Color.white.opacity(0.85))
            }
            .frame(minHeight: Layout.minTapTarget, alignment: .leading)
            .accessibilityLabel(isExpanded ? "声の情報を隠す" : "声の情報を見る")

            if isExpanded {
                Text(description)
                    .font(Typography.footnote)
                    .foregroundStyle(Color.white.opacity(0.95))
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.15), in: Theme.Radius.shape(Theme.Radius.medium))
            }
        }
    }
}

private struct ArgumentDisclosureView: View {
    let argument: ToulminArgument
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Button {
                withAnimation(Theme.Motion.animation(Theme.Motion.gentle, reduceMotion: reduceMotion)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Text(isExpanded ? "論証構造を隠す" : "論証構造を見る")
                }
                .font(Typography.caption)
                .foregroundStyle(Color.secondary)
            }
            .frame(minHeight: Layout.minTapTarget, alignment: .leading)
            .accessibilityLabel(isExpanded ? "論証構造を隠す" : "論証構造を見る")

            if isExpanded {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    argumentRow(label: "主張", value: argument.claim)
                    if let grounds = argument.grounds {
                        argumentRow(label: "根拠", value: grounds)
                    }
                    if let warrant = argument.warrant {
                        argumentRow(label: "論拠", value: warrant)
                    }
                    if let backing = argument.backing {
                        argumentRow(label: "裏付け", value: backing)
                    }
                    if let qualifier = argument.qualifier {
                        qualifierRow(qualifier)
                    }
                    if let rebuttal = argument.rebuttal {
                        argumentRow(label: "例外", value: rebuttal)
                    }
                }
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Palette.surfaceElevated, in: Theme.Radius.shape(Theme.Radius.medium))
            }
        }
    }

    private func argumentRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Typography.caption)
                .fontWeight(Theme.Weight.emphasis)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Typography.footnote)
                .foregroundStyle(.primary)
        }
    }

    private func qualifierRow(_ qualifier: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "gauge.medium")
                Text("確からしさ")
                    .fontWeight(Theme.Weight.emphasis)
            }
            .font(Typography.caption)
            .foregroundStyle(.secondary)
            Text(qualifier)
                .font(Typography.footnote)
                .foregroundStyle(.primary)
                .italic()
        }
    }
}

private struct TypingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: Layout.typingDotSpacing) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: Layout.typingDotSize, height: Layout.typingDotSize)
                    .scaleEffect(animate ? 1 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animate
                    )
            }
        }
        .accessibilityLabel("応答を生成中")
        .onAppear { animate = true }
    }
}

private struct StatusIndicatorView: View {
    let state: ConversationState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: iconName)
                .symbolEffect(.pulse, isActive: isActive && !reduceMotion)
            Text(state.displayLabel)
                .font(Typography.footnote)
                .fontWeight(Theme.Weight.emphasis)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(Theme.Palette.surface, in: Capsule())
        .foregroundStyle(AvatarPalette.color(for: state))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.displayLabel)
    }

    private var isActive: Bool {
        state == .listening || state == .thinking || state == .speaking
    }

    private var iconName: String {
        switch state {
        case .idle: return "circle"
        case .listening: return "waveform"
        case .thinking: return "ellipsis"
        case .speaking: return "speaker.wave.2.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

private struct MicButton: View {
    let state: ConversationState
    let audioLevel: Float
    /// ハンズフリー会話セッションが有効かどうか（listening以外の間も、待機中であることを示すため使う）
    let isHandsFreeActive: Bool
    let isEnabled: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// listening中ではないが、AIの応答を挟んで自動的に再開する見込みがある状態
    private var isStandingByForHandsFree: Bool {
        isHandsFreeActive && state != .listening
    }

    var body: some View {
        VStack(spacing: 2) {
            Button(action: action) {
                ZStack {
                    if state == .listening && !reduceMotion {
                        Circle()
                            .stroke(Color.red.opacity(0.35), lineWidth: 2)
                            .frame(
                                width: Layout.micButtonSize + CGFloat(audioLevel) * Layout.micLevelRingMaxExpansion,
                                height: Layout.micButtonSize + CGFloat(audioLevel) * Layout.micLevelRingMaxExpansion
                            )
                            .animation(.easeOut(duration: 0.15), value: audioLevel)
                    }

                    Circle()
                        .fill(backgroundColor)
                        .frame(width: Layout.micButtonSize, height: Layout.micButtonSize)

                    Image(systemName: iconName)
                        .font(Typography.title2)
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
            .disabled(!isEnabled)
            // ハンズフリー待機中は「押せない」だけでなく「セッションが生きている」ことも見た目で示すため、
            // 通常の無効表示（薄く表示）にはしない。
            .opacity(isEnabled || isStandingByForHandsFree ? 1 : 0.4)
            .animation(Theme.Motion.gentle, value: state)

            // 単なる「マイクに切り替える」ではなく、行為の意味が伝わる控えめなラベルを添える。
            Text(captionText)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var captionText: String {
        if state == .listening { return "とめる" }
        if isStandingByForHandsFree { return "きいています" }
        return "聞いてもらう"
    }

    private var iconName: String {
        state == .listening ? "stop.fill" : "waveform.and.mic"
    }

    private var backgroundColor: Color {
        if state == .listening { return Color.red }
        if isStandingByForHandsFree { return Color.orange }
        return Color.accentColor
    }

    private var accessibilityLabel: String {
        if state == .listening { return "聞き取りをやめる" }
        if isStandingByForHandsFree { return "AIが応答中です。終わったら自動的に聞き取りを再開します" }
        return "話す。タップするとAIが聞いてくれます"
    }
}

#Preview {
    ChatView()
}
