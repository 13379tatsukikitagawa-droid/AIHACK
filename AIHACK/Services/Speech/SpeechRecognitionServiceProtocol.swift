import Foundation

nonisolated protocol SpeechRecognitionServiceProtocol: Sendable {
    /// 音声認識を開始し、部分結果・確定結果・音量レベルを逐次流すストリームを返す
    func startRecognition() -> AsyncThrowingStream<SpeechRecognitionEvent, Error>
    /// 発話の終了を明示し、最終認識結果の確定を要求する
    func finishRecognition() async
}
