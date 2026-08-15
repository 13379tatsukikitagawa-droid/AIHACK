# AIHACK

AIをアバターとして画面に表示し、ユーザーとリアルタイムに会話するiOSアプリ（開発中）。

現在のスコープ: テキスト入力によるOrcaRouter経由のLLMストリーミング応答表示
音声認識・音声合成・カメラ・ARKit・Toulminモデルによる構造化を実装

## セットアップ

### 1. OrcaRouter APIキーの設定

1. `AIHACK/Configuration/Secrets.example.swift` に記載のテンプレートを参考に、`AIHACK/Configuration/Secrets.swift` の `orcaRouterAPIKey` に取得したAPIキー（`sk-orca-` から始まる文字列）を設定してください。

   ```swift
   enum Secrets {
       static let orcaRouterAPIKey = "sk-orca-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
   }
   ```

2. `Secrets.swift` は `.gitignore` に登録済みのため、リポジトリにはコミットされません。APIキーが空のままの場合、アプリはLLM通信を行わず、チャット画面上部に設定を促すメッセージを表示します。

### 2. ビルド・実行

1. Xcodeで `AIHACK.xcodeproj` を開く
2. 実行先にiOSシミュレータ（iPhone推奨）を選択
3. ビルド・実行し、画面下部の入力欄にメッセージを送信するとOrcaRouter経由のLLM応答がストリーミング表示されます
