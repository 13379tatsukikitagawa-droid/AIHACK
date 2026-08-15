import SwiftUI

/// CrisisSafetyFilterが危機的表現を検知した際に、LLMへの送信の代わりに表示する画面。
/// この画面自体がユーザーの入力の「送信先」となり、相談窓口以外への導線は持たない。
struct CrisisSupportView: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("ひとりで抱えこまないでください")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("今の気持ちを、話せる人や窓口に話してみませんか。よろしければ下記に連絡してみてください。")
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: Spacing.md) {
                        contactRow(
                            title: "よりそいホットライン",
                            subtitle: "0120-279-338（24時間・無料・匿名）",
                            phoneDigits: "0120279338"
                        )
                        contactRow(
                            title: "いのちの電話",
                            subtitle: "0570-064-556（ナビダイヤル）",
                            phoneDigits: "0570064556"
                        )
                        webRow(
                            title: "厚生労働省 まもろうよ こころ",
                            subtitle: "SNS相談など、他の相談窓口の一覧",
                            urlString: "https://www.mhlw.go.jp/mamorouyokokoro/"
                        )
                    }

                    Text("今すぐ命に関わる危険がある場合は、110番（警察）または119番（救急）に連絡してください。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(Spacing.lg)
            }
            .background(Theme.Palette.background)
            .navigationTitle("相談窓口のご案内")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる", action: onDismiss)
                }
            }
        }
    }

    private func contactRow(title: String, subtitle: String, phoneDigits: String) -> some View {
        row(title: title, subtitle: subtitle, systemImage: "phone.fill", url: URL(string: "tel:\(phoneDigits)"))
    }

    private func webRow(title: String, subtitle: String, urlString: String) -> some View {
        row(title: title, subtitle: subtitle, systemImage: "safari.fill", url: URL(string: urlString))
    }

    @ViewBuilder
    private func row(title: String, subtitle: String, systemImage: String, url: URL?) -> some View {
        if let url {
            Link(destination: url) {
                rowContent(title: title, subtitle: subtitle, systemImage: systemImage)
            }
        }
    }

    private func rowContent(title: String, subtitle: String, systemImage: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer()
            Image(systemName: systemImage)
                .foregroundStyle(Theme.Palette.accent)
        }
        .padding(Spacing.md)
        .frame(minHeight: Layout.minTapTarget)
        .background(Theme.Palette.surface, in: Theme.Radius.shape(Theme.Radius.medium))
    }
}

#Preview {
    CrisisSupportView(onDismiss: {})
}
