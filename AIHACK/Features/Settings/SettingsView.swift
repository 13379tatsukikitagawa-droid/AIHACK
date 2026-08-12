import SwiftUI
import AVFoundation

/// 読み上げ音声の選択画面。高品質・プレミアム音声を優先表示し、試聴・ダウンロード導線を提供する。
struct SettingsView: View {
    let memoryStore: MemoryStore

    @Environment(\.dismiss) private var dismiss
    @State private var voices: [VoiceOption] = VoiceCatalog.japaneseVoices()
    @State private var selectedIdentifier: String? = VoicePreference.load()
    @State private var previewSynthesizer = AVSpeechSynthesizer()
    @State private var previewingIdentifier: String?

    @State private var ttsEngine: TTSEngineKind = TTSPreference.engine
    @State private var ttsVoice: TTSVoice = TTSPreference.voice
    @State private var ttsSpeed: Double = TTSPreference.speed
    @State private var previewingTTSVoice: TTSVoice?
    @State private var ttsPreviewTask: Task<Void, Never>?
    @State private var ttsPreviewPlayer: AVAudioPlayer?

    @State private var showingDeleteAllMemoryConfirmation = false

    private var defaultVoice: VoiceOption? { VoiceCatalog.systemDefaultVoice() }
    private var effectiveIdentifier: String? { selectedIdentifier ?? defaultVoice?.identifier }

    var body: some View {
        NavigationStack {
            Group {
                if voices.isEmpty {
                    ContentUnavailableView(
                        "音声が見つかりません",
                        systemImage: "speaker.slash",
                        description: Text("端末に日本語の読み上げ音声が見つかりませんでした。")
                    )
                } else {
                    List {
                        Section("読み上げエンジン") {
                            enginePicker
                        }

                        if ttsEngine == .orcaRouter {
                            Section {
                                speedControl
                            } header: {
                                Text("OrcaRouter音声")
                            } footer: {
                                Text("通信に失敗、または3秒以内に応答がない場合は、自動的に端末内の音声に切り替わります。")
                            }

                            Section("音声を選ぶ") {
                                ForEach(TTSVoice.allCases) { voice in
                                    ttsVoiceRow(voice)
                                }
                            }
                        }

                        Section {
                            currentSelectionSummary
                            downloadGuidanceBanner
                        }
                        .listRowSeparator(.hidden)

                        Section {
                            ForEach(voices) { voice in
                                voiceRow(voice)
                            }
                        } header: {
                            Text("端末内の音声")
                        } footer: {
                            if ttsEngine == .orcaRouter {
                                Text("OrcaRouterでの合成に失敗した場合、ここで選んだ音声で読み上げられます。")
                            }
                        }

                        Section {
                            Button("すべての記憶を削除", role: .destructive) {
                                showingDeleteAllMemoryConfirmation = true
                            }
                            .frame(minHeight: Layout.minTapTarget)
                            .disabled(memoryStore.topics.isEmpty)
                        } header: {
                            Text("記憶")
                        } footer: {
                            Text("好み・関心の話題として記憶された内容（\(memoryStore.topics.count)件）をすべて削除します。この操作は取り消せません。")
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
                }
            }
            .onDisappear {
                previewSynthesizer.stopSpeaking(at: .immediate)
                ttsPreviewTask?.cancel()
                ttsPreviewPlayer?.stop()
            }
            .confirmationDialog(
                "すべての記憶を削除しますか？",
                isPresented: $showingDeleteAllMemoryConfirmation,
                titleVisibility: .visible
            ) {
                Button("すべて削除", role: .destructive) {
                    memoryStore.deleteAll()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この操作は取り消せません。記憶されたすべてのトピックが削除され、以降の会話で参照されなくなります。")
            }
        }
    }

    private var enginePicker: some View {
        Picker("エンジン", selection: $ttsEngine) {
            Text("OrcaRouter（高品質）").tag(TTSEngineKind.orcaRouter)
            Text("端末内").tag(TTSEngineKind.device)
        }
        .pickerStyle(.segmented)
        .onChange(of: ttsEngine) { _, newValue in
            TTSPreference.engine = newValue
        }
    }

    private var speedControl: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("速度")
                    .font(Typography.subheadline)
                Spacer()
                Text(String(format: "%.2fx", ttsSpeed))
                    .font(Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $ttsSpeed, in: 0.5...2.0, step: 0.05)
                .onChange(of: ttsSpeed) { _, newValue in
                    TTSPreference.speed = newValue
                }
                .accessibilityLabel("読み上げ速度")
                .accessibilityValue(String(format: "%.2f倍", ttsSpeed))
        }
    }

    private func ttsVoiceRow(_ voice: TTSVoice) -> some View {
        let isSelected = voice == ttsVoice

        return HStack(spacing: Spacing.sm) {
            Button {
                ttsVoice = voice
                TTSPreference.voice = voice
            } label: {
                HStack(spacing: Spacing.sm) {
                    Text(voice.label)
                        .font(Typography.body)
                        .foregroundStyle(.primary)
                    Spacer(minLength: Spacing.sm)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .frame(minHeight: Layout.minTapTarget)
            }
            .buttonStyle(.plain)

            Button {
                previewOrcaRouterVoice(voice)
            } label: {
                Image(systemName: previewingTTSVoice == voice ? "stop.circle.fill" : "play.circle")
                    .font(Typography.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
            .accessibilityLabel("\(voice.label)を試聴")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(voice.label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func previewOrcaRouterVoice(_ voice: TTSVoice) {
        ttsPreviewTask?.cancel()
        ttsPreviewPlayer?.stop()

        if previewingTTSVoice == voice {
            previewingTTSVoice = nil
            return
        }

        previewingTTSVoice = voice
        let speed = ttsSpeed
        ttsPreviewTask = Task {
            do {
                let data = try await OrcaRouterTTSService.fetchPreview(voice: voice, speed: speed)
                guard !Task.isCancelled else { return }
                let player = try AVAudioPlayer(data: data)
                ttsPreviewPlayer = player
                player.play()
                try? await Task.sleep(for: .seconds(player.duration))
            } catch {
                // 試聴専用の一時的なリクエストのため、失敗しても静かに終了する
            }
            if !Task.isCancelled {
                previewingTTSVoice = nil
            }
        }
    }

    private var currentSelectionSummary: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "waveform")
                .foregroundStyle(Color.accentColor)
            if let current = voices.first(where: { $0.identifier == effectiveIdentifier }) ?? defaultVoice {
                VStack(alignment: .leading, spacing: 2) {
                    Text("現在の音声: \(current.name)")
                        .font(Typography.subheadline)
                    Text("品質: \(current.qualityTier.label)")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("システム標準の音声を使用しています")
                    .font(Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var downloadGuidanceBanner: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("より高品質な音声について")
                    .font(Typography.headline)
                Text("「高品質」「プレミアム」の音声は、端末に未ダウンロードの場合、実際には標準品質で再生されることがあります。設定アプリの「アクセシビリティ」→「読み上げコンテンツ」→「音声」→「日本語」からダウンロードできます。")
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

    private func voiceRow(_ voice: VoiceOption) -> some View {
        let isSelected = voice.identifier == effectiveIdentifier

        return HStack(spacing: Spacing.sm) {
            Button {
                selectedIdentifier = voice.identifier
                VoicePreference.save(voice.identifier)
            } label: {
                HStack(spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(voice.name)
                            .font(Typography.body)
                            .foregroundStyle(.primary)
                        Text(voice.qualityTier.label)
                            .font(Typography.caption)
                            .foregroundStyle(voice.qualityTier == .standard ? Color.secondary : Color.accentColor)
                    }
                    Spacer(minLength: Spacing.sm)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .frame(minHeight: Layout.minTapTarget)
            }
            .buttonStyle(.plain)

            Button {
                preview(voice)
            } label: {
                Image(systemName: previewingIdentifier == voice.identifier ? "stop.circle.fill" : "play.circle")
                    .font(Typography.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
            .accessibilityLabel("\(voice.name)を試聴")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(voice.name)、\(voice.qualityTier.label)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func preview(_ voice: VoiceOption) {
        guard let synthesisVoice = AVSpeechSynthesisVoice(identifier: voice.identifier) else { return }

        if previewingIdentifier == voice.identifier {
            previewSynthesizer.stopSpeaking(at: .immediate)
            previewingIdentifier = nil
            return
        }

        previewSynthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: "こんにちは。これは音声のサンプルです。")
        utterance.voice = synthesisVoice
        previewingIdentifier = voice.identifier
        previewSynthesizer.speak(utterance)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    SettingsView(memoryStore: MemoryStore(llmService: OrcaRouterService()))
}
