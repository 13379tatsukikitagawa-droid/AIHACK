/// OrcaRouterへ渡すモデルIDを一箇所で管理する。
/// "orcarouter/auto" は無料枠（orcarouter/free 等）へルーティングされ429が頻発したため、
/// GET /v1/models で実在を確認した有料モデルへ明示的に差し替えている。
/// 用途ごとに異なる vendor/model を割り当てたくなった場合はここだけを変更すればよい。
nonisolated enum ModelCatalog {
    /// 短い相槌・挨拶など、軽量な応答生成に使うモデル。低価格・低遅延を優先。
    static let lightweight = "openai/gpt-4o-mini"
    /// 通常の会話応答に使うモデル。低価格かつ応答が速いモデルを優先し、体感速度を最優先する。
    static let conversational = "openai/gpt-4o-mini"
    /// 論証構造（Toulminモデル）の抽出に使うモデル。中程度の性能で、JSON出力の安定性を優先する。
    static let reasoning = "openai/gpt-4.1-mini"
    /// セッション全体の観察に基づく仮説生成に使う、最も高性能なモデル。速度より質を優先する。
    static let hypothesisGeneration = "anthropic/claude-opus-4.8"
    /// 429（レート制限）発生時に切り替える代替モデル。同時混雑を避けるため会話用とは別プロバイダを指定する。
    static let rateLimitFallback = "deepseek/deepseek-v4-flash"
    /// OrcaRouter TTS（/v1/audio/speech）で使う音声合成モデル。GET /v1/models と実リクエストの両方で稼働を確認済み。
    static let ttsPrimary = "openai/gpt-4o-mini-tts"
    /// 会話から記憶に値する話題を抽出する軽量な判定に使うモデル。速度とコストを優先する。
    static let memoryExtraction = "openai/gpt-4o-mini"
    /// 感情当てゲーム（Game機能）の感情推測に使うモデル。ブースでの実演のためテンポを損なわない
    /// 速度を保ちつつ、対話用の軽量モデルより一段上の推論力を持つモデルを割り当て、判定の妥当性を優先する。
    static let emotionGuessing = "openai/gpt-4.1-mini"
    /// 「30秒プレゼン」（Game機能）の採点に使うモデル。内容の説得力を判定する必要があるため、
    /// 速度より精度を優先し、仮説生成と同じ最も高性能なモデルを割り当てる。
    static let presentationScoring = "anthropic/claude-opus-4.8"
}
