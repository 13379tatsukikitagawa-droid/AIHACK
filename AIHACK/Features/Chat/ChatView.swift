import SwiftUI
import UIKit

private enum ChatDisplayMode {
    case avatar
    case transcript
}

struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var showingFaceDebug = false
    @State private var showingAnalysis = false
    @State private var showingSettings = false
    @State private var showingMemory = false
    @State private var analysisInitialTab: AnalysisTab = .conversation
    @State private var displayMode: ChatDisplayMode = .avatar

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
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: Spacing.sm) {
                    handsFreeIndicator
                    inputBar
                }
                .padding(.top, Spacing.sm)
                .background(.bar)
            }
            .background(Color(.systemBackground))
            .navigationTitle("AIHACK")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    displayModeToggleButton
                    analysisButton
                    hypothesisButton
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    cameraToggleButton
                    memoryButton
                    settingsButton
                }
            }
        }
        .onChange(of: viewModel.conversationState) { _, newState in
            UIAccessibility.post(notification: .announcement, argument: newState.displayLabel)
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

    private var analysisButton: some View {
        Button {
            analysisInitialTab = .conversation
            showingAnalysis = true
        } label: {
            Image(systemName: "chart.bar.doc.horizontal")
        }
        .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
        .accessibilityLabel("セッション分析を表示")
    }

    private var hypothesisButton: some View {
        Button {
            analysisInitialTab = .hypothesis
            showingAnalysis = true
        } label: {
            Image(systemName: "lightbulb")
        }
        .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
        .accessibilityLabel("仮説を表示")
    }

    private var cameraToggleButton: some View {
        Button {
            showingFaceDebug = true
        } label: {
            Image(systemName: viewModel.isCameraActive ? "camera.fill" : "camera")
                .foregroundStyle(viewModel.isCameraActive ? Color.red : Color.primary)
        }
        .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
        .accessibilityLabel(viewModel.isCameraActive ? "カメラ動作中。表情トラッキング画面を開く" : "表情トラッキングを開始")
    }

    private var memoryButton: some View {
        Button {
            showingMemory = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "text.book.closed")
                if viewModel.memoryStore.topics.count > 0 {
                    Text("\(min(viewModel.memoryStore.topics.count, 99))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Color.red, in: Circle())
                        .offset(x: 10, y: -8)
                }
            }
        }
        .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
        .accessibilityLabel("メモを表示。\(viewModel.memoryStore.topics.count)件のトピックが記録されています")
    }

    private var settingsButton: some View {
        Button {
            showingSettings = true
        } label: {
            Image(systemName: "gearshape")
        }
        .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
        .accessibilityLabel("設定を表示")
    }

    private var avatarModeBody: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Spacing.sm)

            AvatarView(
                state: viewModel.conversationState,
                audioLevel: viewModel.audioLevel,
                lastSpeechPulseAt: viewModel.lastSpeechPulseAt,
                smileLevel: viewModel.isCameraActive ? viewModel.faceSignals.smile : 0
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
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("retry-banner", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.errorMessage) {
                guard viewModel.errorMessage != nil else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("error-banner", anchor: .bottom)
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastID = viewModel.messages.last?.id else { return }
        withAnimation(.easeOut(duration: 0.2)) {
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
                Text("Configuration/Secrets.swift に OrcaRouter の APIキーを設定してください。手順は README.md を参照してください。")
                    .font(Typography.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
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
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
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
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
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
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            MicButton(
                state: viewModel.conversationState,
                audioLevel: viewModel.audioLevel,
                isHandsFreeActive: viewModel.isHandsFreeActive,
                isEnabled: viewModel.isMicEnabled,
                action: viewModel.toggleListening
            )

            messageInputField

            actionButton
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    /// ハンズフリー会話セッションが有効な間、listening以外の状態でも常に表示する。
    /// プライバシーに関わるため、マイクが自動的に再起動されうることを曖昧にしない。
    @ViewBuilder
    private var handsFreeIndicator: some View {
        if viewModel.isHandsFreeActive {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "person.wave.2.fill")
                Text("ハンズフリー会話中（マイクボタンで終了）")
            }
            .font(Typography.caption)
            .fontWeight(.medium)
            .foregroundStyle(Color.white)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(Color.orange, in: Capsule())
            .padding(.horizontal, Spacing.lg)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("ハンズフリー会話中です。マイクボタンで終了できます。")
        }
    }

    @ViewBuilder
    private var messageInputField: some View {
        if viewModel.conversationState == .listening {
            liveTranscriptView
        } else {
            TextField("メッセージを入力", text: $viewModel.inputText, axis: .vertical)
                .font(Typography.body)
                .lineLimit(1...5)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.inputBarCornerRadius, style: .continuous))
                .disabled(!viewModel.isInputEnabled)
                .focused($isInputFocused)
                .onSubmit(sendIfPossible)
        }
    }

    private var liveTranscriptView: some View {
        HStack {
            Text(viewModel.liveTranscript.isEmpty ? "聞き取り中…" : viewModel.liveTranscript)
                .font(Typography.body)
                .foregroundStyle(viewModel.liveTranscript.isEmpty ? Color.secondary : Color.primary.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: Layout.minTapTarget)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.inputBarCornerRadius, style: .continuous))
        .accessibilityLabel("認識中のテキスト")
        .accessibilityValue(viewModel.liveTranscript.isEmpty ? "まだ発話がありません" : viewModel.liveTranscript)
    }

    @ViewBuilder
    private var actionButton: some View {
        if viewModel.isGenerating {
            Button(role: .destructive) {
                viewModel.stop()
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(Typography.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
            .accessibilityLabel("生成を中断")
        } else {
            Button(action: sendIfPossible) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(Typography.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
            .disabled(!viewModel.canSend)
            .accessibilityLabel("送信")
        }
    }

    private func sendIfPossible() {
        guard viewModel.canSend else { return }
        viewModel.send()
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
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
    }

    private var backgroundColor: Color {
        isUser ? Color.accentColor : Color(.secondarySystemBackground)
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
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
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
                    .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
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
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
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
                    .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
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
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
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
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
            }
        }
    }

    private func argumentRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Typography.caption)
                .fontWeight(.semibold)
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
                    .fontWeight(.semibold)
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
                .fontWeight(.medium)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(Color(.secondarySystemBackground), in: Capsule())
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
        .animation(.easeInOut(duration: 0.2), value: state)
        .accessibilityLabel(accessibilityLabel)
    }

    private var iconName: String {
        state == .listening ? "stop.fill" : "mic.fill"
    }

    private var backgroundColor: Color {
        if state == .listening { return Color.red }
        if isStandingByForHandsFree { return Color.orange }
        return Color.accentColor
    }

    private var accessibilityLabel: String {
        if state == .listening { return "ハンズフリー音声入力を停止" }
        if isStandingByForHandsFree { return "ハンズフリー会話中。応答後に自動的に聞き取りを再開します" }
        return "ハンズフリー音声入力を開始"
    }
}

#Preview {
    ChatView()
}
