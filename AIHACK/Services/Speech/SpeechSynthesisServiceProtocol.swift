import Foundation

protocol SpeechSynthesisServiceProtocol: Sendable {
    /// 読み上げ開始・キュー完了イベントを流すストリームを返す
    func events() -> AsyncStream<SpeechSynthesisEvent>
    /// テキストを読み上げキューへ追加する
    func enqueue(_ text: String)
    /// 現在の発話とキューをすべて中断する
    func stop()
}
