import Foundation

/// APIキーなどの機密情報を取得する唯一の窓口。ソースコードへの直書きを避け、
/// 「① 環境変数（ローカル開発・CI向け） → ② Info.plist（xcconfig経由でビルド時注入。配布ビルド向け）」
/// の優先順で解決する。バイナリに文字列リテラルとして焼き込まれる直書きと異なり、
/// 値は実行時にのみ解決され、リポジトリにも成果物のソースにも平文で残らない。
///
/// 環境変数はXcodeのScheme（Product > Scheme > Edit Scheme > Run > Arguments >
/// Environment Variables）で設定する。Info.plist経由の値はConfiguration/Secrets.xcconfig
/// （.gitignore対象。Secrets.xcconfig.exampleを参照して作成し、TARGETS > AIHACK > Info >
/// Configurations でDebug/Release双方に割り当てる）で定義したビルド変数を、
/// project.pbxprojの INFOPLIST_KEY_OrcaRouterAPIKey = "$(ORCA_ROUTER_API_KEY)" が
/// 生成後のInfo.plistへ注入する。
enum SecretsManager {
    static var orcaRouterAPIKey: String {
        resolve(environmentKey: "ORCA_ROUTER_API_KEY", infoPlistKey: "OrcaRouterAPIKey")
    }

    private static func resolve(environmentKey: String, infoPlistKey: String) -> String {
        if let fromEnvironment = ProcessInfo.processInfo.environment[environmentKey],
           !fromEnvironment.isEmpty {
            return fromEnvironment
        }

        if let fromInfoPlist = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String,
           !fromInfoPlist.isEmpty,
           !fromInfoPlist.hasPrefix("$(") {
            // ビルド変数が未定義のまま展開されず "$(ORCA_ROUTER_API_KEY)" という
            // リテラル文字列が残るケースを、値ありと誤判定しないよう除外する。
            return fromInfoPlist
        }

        return ""
    }
}
