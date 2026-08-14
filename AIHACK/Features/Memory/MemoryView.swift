import SwiftUI

/// 好み・関心・話題の記憶を一覧・確認・削除する画面。表情・声の記録とは異なり、
/// ここに表示される内容はディスクに永続化されている（アプリを終了しても消えない）。
struct MemoryView: View {
    let memoryStore: MemoryStore

    @Environment(\.dismiss) private var dismiss
    @State private var topicPendingDeletion: MemoryTopic?
    @State private var showingDeleteAllConfirmation = false
    @State private var expandedTopicID: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if memoryStore.topics.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            privacyNotice
                        }
                        .listRowSeparator(.hidden)

                        Section("記憶されたトピック（\(memoryStore.topics.count)件）") {
                            ForEach(sortedTopics) { topic in
                                topicRow(topic)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("メモ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
                }
                if !memoryStore.topics.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("すべて削除", role: .destructive) {
                            showingDeleteAllConfirmation = true
                        }
                        .frame(minHeight: Layout.minTapTarget)
                    }
                }
            }
            .confirmationDialog(
                "すべての記憶を削除しますか？",
                isPresented: $showingDeleteAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("すべて削除", role: .destructive) {
                    memoryStore.deleteAll()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この操作は取り消せません。記憶されたすべてのトピックが削除され、以降の会話で参照されなくなります。")
            }
            .confirmationDialog(
                topicPendingDeletion.map { "「\($0.topic)」を削除しますか？" } ?? "",
                isPresented: Binding(
                    get: { topicPendingDeletion != nil },
                    set: { isPresented in if !isPresented { topicPendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    if let topic = topicPendingDeletion {
                        memoryStore.deleteTopic(topic.id)
                    }
                    topicPendingDeletion = nil
                }
                Button("キャンセル", role: .cancel) { topicPendingDeletion = nil }
            }
        }
    }

    private var sortedTopics: [MemoryTopic] {
        memoryStore.topics.sorted { $0.lastMentionedAt > $1.lastMentionedAt }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "まだ記憶がありません",
            systemImage: "text.book.closed",
            description: Text("会話の中で話した好みや関心のある話題が、少しずつここに記録されていきます。")
        )
    }

    private var privacyNotice: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "externaldrive.fill.badge.checkmark")
                .foregroundStyle(.blue)
            Text("この記憶は端末に保存され、次回以降の会話でも保持されます。表情・声の記録とは異なり、アプリを終了しても消えません。いつでも個別に、またはまとめて削除できます。")
                .font(Typography.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.bubbleCornerRadius, style: .continuous))
    }

    private func topicRow(_ topic: MemoryTopic) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedTopicID == topic.id },
                set: { isExpanded in expandedTopicID = isExpanded ? topic.id : nil }
            )
        ) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if topic.relatedSummaries.isEmpty {
                    Text("関連する発言の要約はありません。")
                        .font(Typography.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(topic.relatedSummaries, id: \.self) { summary in
                        HStack(alignment: .top, spacing: Spacing.xs) {
                            Image(systemName: "quote.opening")
                                .font(Typography.caption)
                                .foregroundStyle(.secondary)
                            Text(summary)
                                .font(Typography.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.xs)
        } label: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(topic.topic)
                    .font(Typography.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: Spacing.md) {
                    metaItem(icon: "text.bubble", text: "\(topic.mentionCount)回")
                    metaItem(icon: "calendar", text: dateLabel(topic.firstMentionedAt))
                    metaItem(icon: "clock", text: dateLabel(topic.lastMentionedAt))
                }
            }
            .padding(.vertical, Spacing.xs)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                topicPendingDeletion = topic
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(topic.topic)、\(topic.mentionCount)回言及、初回\(dateLabel(topic.firstMentionedAt))、直近\(dateLabel(topic.lastMentionedAt))")
    }

    private func metaItem(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(text)
        }
        .font(Typography.caption)
        .foregroundStyle(.secondary)
    }

    private func dateLabel(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }
}

#Preview {
    MemoryView(memoryStore: MemoryStore(llmService: OrcaRouterService()))
}

#if DEBUG
private func makeSampleMemoryStore() -> MemoryStore {
    let store = MemoryStore(llmService: OrcaRouterService())
    let now = Date()
    store.debugSetTopics([
        MemoryTopic(
            topic: "コーヒー",
            firstMentionedAt: now.addingTimeInterval(-86400 * 30),
            lastMentionedAt: now.addingTimeInterval(-3600),
            mentionCount: 6,
            relatedSummaries: ["浅煎りのコーヒーが好きだと話していた", "週末によく喫茶店に行くと話していた"]
        ),
        MemoryTopic(
            topic: "サッカー",
            firstMentionedAt: now.addingTimeInterval(-86400 * 14),
            lastMentionedAt: now.addingTimeInterval(-86400 * 10),
            mentionCount: 2,
            relatedSummaries: ["応援しているチームがあると話していた"]
        )
    ])
    return store
}

#Preview("サンプルデータあり") {
    MemoryView(memoryStore: makeSampleMemoryStore())
}
#endif
