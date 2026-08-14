import SwiftUI

/// 「30秒プレゼン」のランキング画面。スコア降順で表示し、上位3件をメダル的に強調する。
/// 直近このセッションで登録したエントリ（leaderboard.lastRegisteredEntryID）を自動的にスクロール・強調する。
struct LeaderboardView: View {
    let leaderboard: Leaderboard

    @State private var showingResetConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            Text("ランキング")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(GamePalette.titleGradient)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.sm)

            if leaderboard.entries.isEmpty {
                emptyState
            } else {
                list
            }

            Button(role: .destructive) {
                showingResetConfirmation = true
            } label: {
                Text("ランキングをすべてリセット")
                    .font(Typography.footnote)
            }
            .frame(minHeight: Layout.minTapTarget)
            .padding(.bottom, Spacing.md)
            .disabled(leaderboard.entries.isEmpty)
        }
        .confirmationDialog(
            "ランキングをすべてリセットしますか？",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("すべて削除", role: .destructive) {
                leaderboard.resetAll()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません。記録されたすべてのスコアが削除されます。")
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Spacer()
            Image(systemName: "list.number")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("まだ記録がありません")
                .font(Typography.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(Array(leaderboard.entries.enumerated()), id: \.element.id) { index, entry in
                        LeaderboardRow(
                            rank: index + 1,
                            entry: entry,
                            isHighlighted: entry.id == leaderboard.lastRegisteredEntryID
                        )
                        .id(entry.id)
                    }
                }
                .padding(Spacing.lg)
            }
            .onAppear {
                guard let highlighted = leaderboard.lastRegisteredEntryID else { return }
                proxy.scrollTo(highlighted, anchor: .center)
            }
        }
    }
}

private struct LeaderboardRow: View {
    let rank: Int
    let entry: LeaderboardEntry
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            rankBadge

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.nickname)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
                Text(entry.recordedAt, style: .date)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(entry.score)")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.heavy)
                .monospacedDigit()
        }
        .padding(Spacing.md)
        .frame(minHeight: Layout.minTapTarget)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isHighlighted ? GamePalette.presentationExpressionAxisColor : Color.clear, lineWidth: 2.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rank)位、\(entry.nickname)、\(entry.score)点\(isHighlighted ? "、今回の記録" : "")")
    }

    private var rankBadge: some View {
        ZStack {
            Circle()
                .fill(medalColor)
                .frame(width: 36, height: 36)
            Text("\(rank)")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.heavy)
                .foregroundStyle(.white)
        }
    }

    private var medalColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.78)
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)
        default: return Color.secondary.opacity(0.5)
        }
    }
}

#Preview {
    LeaderboardView(leaderboard: Leaderboard())
}
