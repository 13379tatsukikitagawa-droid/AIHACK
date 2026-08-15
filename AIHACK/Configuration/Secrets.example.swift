// Secrets.example.swift
//
// APIキーはソースコードに直書きしない。実際の値は SecretsManager.swift が
// 「環境変数（ORCA_ROUTER_API_KEY） → Info.plist経由（Secrets.xcconfig.exampleを参照）」の順で
// 実行時に解決する。ローカル開発では、Xcodeの Product > Scheme > Edit Scheme > Run >
// Arguments > Environment Variables に ORCA_ROUTER_API_KEY を設定するのが最も手軽。
//
// このファイルは Xcode の File System Synchronized Group によって自動的にビルド対象へ
// 含まれてしまい、Secrets.swift と同名の enum を定義すると型の重複宣言でビルドが失敗するため、
// あえてコード化せずコメントのテンプレートとして残している（Secrets.swift自体はSecretsManagerへの
// 薄い委譲のみを行い、キーの値そのものは保持しない）。
