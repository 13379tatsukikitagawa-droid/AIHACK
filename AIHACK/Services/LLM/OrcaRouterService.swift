import Foundation
import os

/// OrcaRouter（OpenAI互換のAPIゲートウェイ）経由でLLMのストリーミング応答・構造化応答を取得するサービス。
/// actorとして実装し、通信処理がMainActorをブロックしないようにする。
/// APIキーはいかなる理由でもログへ出力しない。
actor OrcaRouterService: LLMServiceProtocol {
    nonisolated private static let endpoint = URL(string: "https://api.orcarouter.ai/v1/chat/completions")!
    nonisolated private static let logger = Logger(subsystem: "com.tatsukikitagawa.AIHACK", category: "LLMNetwork")

    /// 429受信時の指数バックオフ待機時間（秒）。この配列の長さがリトライ上限回数になる。
    nonisolated private static let backoffDelays: [TimeInterval] = [1, 2, 4]

    private let session: URLSession
    private var retryContinuation: AsyncStream<LLMRetryEvent>.Continuation?

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// 429による自動リトライの発生を通知するストリーム。購読は1箇所を想定した単一continuationの単純な実装。
    nonisolated func retryEvents() -> AsyncStream<LLMRetryEvent> {
        AsyncStream { continuation in
            Task { await self.setRetryContinuation(continuation) }
        }
    }

    private func setRetryContinuation(_ continuation: AsyncStream<LLMRetryEvent>.Continuation) {
        retryContinuation = continuation
    }

    private func emitRetry(attempt: Int, delay: TimeInterval, usingFallbackModel: Bool) {
        Self.logger.info("""
        429を受信。\(delay, privacy: .public)秒後にリトライします \
        (\(attempt, privacy: .public)/\(Self.backoffDelays.count, privacy: .public)回目, \
        fallbackModel=\(usingFallbackModel, privacy: .public))
        """)
        retryContinuation?.yield(LLMRetryEvent(
            attempt: attempt,
            maxAttempts: Self.backoffDelays.count,
            delay: delay,
            usingFallbackModel: usingFallbackModel
        ))
    }

    /// attempt番号（0始まり。0が初回）に応じて使用するモデルを決める。
    /// 0・1回目は指定されたモデルのまま、2回目以降（＝2回連続で429）は代替モデルへ切り替える。
    nonisolated private static func model(forAttempt attempt: Int, original: String) -> String {
        attempt >= 2 ? ModelCatalog.rateLimitFallback : original
    }

    private enum AttemptResult<Value> {
        case success(Value)
        case rateLimited
    }

    // MARK: - ストリーミング応答

    nonisolated func streamResponse(
        for messages: [ChatMessage],
        model: String,
        systemPrompt: String?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.performStream(for: messages, model: model, systemPrompt: systemPrompt, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func performStream(
        for messages: [ChatMessage],
        model: String,
        systemPrompt: String?,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        guard !Secrets.orcaRouterAPIKey.isEmpty else {
            Self.logger.error("APIキーが未設定のため送信を中止しました")
            throw LLMError.missingAPIKey
        }

        for attempt in 0...Self.backoffDelays.count {
            let attemptModel = Self.model(forAttempt: attempt, original: model)
            let result = try await performStreamAttempt(
                for: messages,
                model: attemptModel,
                systemPrompt: systemPrompt,
                continuation: continuation
            )

            switch result {
            case .success:
                return
            case .rateLimited:
                guard attempt < Self.backoffDelays.count else {
                    Self.logger.error("レート制限のためリトライ上限に達しました（ストリーミング）")
                    throw LLMError.rateLimited
                }
                let delay = Self.backoffDelays[attempt]
                let nextModel = Self.model(forAttempt: attempt + 1, original: model)
                emitRetry(attempt: attempt + 1, delay: delay, usingFallbackModel: nextModel != model)
                try await Task.sleep(for: .seconds(delay))
            }
        }
    }

    private func performStreamAttempt(
        for messages: [ChatMessage],
        model: String,
        systemPrompt: String?,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws -> AttemptResult<Void> {
        let requestBody = ChatCompletionRequest(
            model: model,
            models: [model],
            route: "fallback",
            messages: Self.requestMessages(for: messages, systemPrompt: systemPrompt),
            stream: true
        )

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Secrets.orcaRouterAPIKey)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            Self.logger.error("リクエストのエンコードに失敗: \(error.localizedDescription, privacy: .public)")
            throw LLMError.decoding(error.localizedDescription)
        }

        Self.logger.info("ストリーミングリクエスト送信: url=\(Self.endpoint.absoluteString, privacy: .public) model=\(model, privacy: .public) messageCount=\(messages.count, privacy: .public)")

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            Self.logger.error("ネットワークエラー(ストリーミング): \(error.localizedDescription, privacy: .public)")
            throw LLMError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            Self.logger.error("HTTPURLResponseへの変換に失敗しました")
            throw LLMError.network("不正なレスポンスです。")
        }

        Self.logger.info("ストリーミング応答受信: status=\(httpResponse.statusCode, privacy: .public)")

        if httpResponse.statusCode == 429 {
            _ = try? await Self.collectBody(from: bytes)
            return .rateLimited
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let errorData = try? await Self.collectBody(from: bytes)
            let bodyPreview = errorData.flatMap { String(data: $0, encoding: .utf8) } ?? "(本文なし)"
            Self.logger.error("APIエラー(ストリーミング): status=\(httpResponse.statusCode, privacy: .public) body=\(bodyPreview, privacy: .public)")
            let message = Self.extractErrorMessage(from: errorData) ?? "サーバーエラーが発生しました。"
            if httpResponse.statusCode == 401 {
                throw LLMError.unauthorized
            }
            throw LLMError.apiError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            for try await line in bytes.lines {
                try Task.checkCancellation()

                guard line.hasPrefix("data:") else { continue }
                let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
                guard !payload.isEmpty else { continue }
                if payload == "[DONE]" { break }

                guard let data = payload.data(using: .utf8) else { continue }

                guard let chunk = try? JSONDecoder().decode(ChatCompletionChunk.self, from: data) else {
                    // 不正なチャンクは無視し、ストリーム全体は継続するが、内容はログに残す
                    Self.logger.error("SSEチャンクのデコードに失敗: \(payload, privacy: .public)")
                    continue
                }

                if let delta = chunk.choices.first?.delta.content, !delta.isEmpty {
                    continuation.yield(delta)
                }
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            Self.logger.error("ストリーム読み取り中にエラー: \(error.localizedDescription, privacy: .public)")
            throw LLMError.network(error.localizedDescription)
        }

        return .success(())
    }

    // MARK: - 非ストリーミング構造化応答

    func completeStructured<T: Decodable & Sendable>(
        for messages: [ChatMessage],
        model: String,
        systemPrompt: String?,
        as type: T.Type
    ) async throws -> T {
        guard !Secrets.orcaRouterAPIKey.isEmpty else {
            Self.logger.error("APIキーが未設定のため送信を中止しました（構造化応答）")
            throw LLMError.missingAPIKey
        }

        for attempt in 0...Self.backoffDelays.count {
            let attemptModel = Self.model(forAttempt: attempt, original: model)
            let result = try await completeStructuredAttempt(
                for: messages,
                model: attemptModel,
                systemPrompt: systemPrompt,
                as: type
            )

            switch result {
            case .success(let value):
                return value
            case .rateLimited:
                guard attempt < Self.backoffDelays.count else {
                    Self.logger.error("レート制限のためリトライ上限に達しました（構造化応答）")
                    throw LLMError.rateLimited
                }
                let delay = Self.backoffDelays[attempt]
                let nextModel = Self.model(forAttempt: attempt + 1, original: model)
                emitRetry(attempt: attempt + 1, delay: delay, usingFallbackModel: nextModel != model)
                try await Task.sleep(for: .seconds(delay))
            }
        }

        // 上のループは必ずreturn/throwするが、コンパイラの制御フロー解析のために安全網を置く
        throw LLMError.rateLimited
    }

    private func completeStructuredAttempt<T: Decodable & Sendable>(
        for messages: [ChatMessage],
        model: String,
        systemPrompt: String?,
        as type: T.Type
    ) async throws -> AttemptResult<T> {
        let requestBody = ChatCompletionRequest(
            model: model,
            models: [model],
            route: "fallback",
            messages: Self.requestMessages(for: messages, systemPrompt: systemPrompt),
            stream: false
        )

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Secrets.orcaRouterAPIKey)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            Self.logger.error("リクエストのエンコードに失敗（構造化応答）: \(error.localizedDescription, privacy: .public)")
            throw LLMError.decoding(error.localizedDescription)
        }

        Self.logger.info("構造化リクエスト送信: url=\(Self.endpoint.absoluteString, privacy: .public) model=\(model, privacy: .public) messageCount=\(messages.count, privacy: .public)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            Self.logger.error("ネットワークエラー(構造化応答): \(error.localizedDescription, privacy: .public)")
            throw LLMError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            Self.logger.error("HTTPURLResponseへの変換に失敗しました（構造化応答）")
            throw LLMError.network("不正なレスポンスです。")
        }

        Self.logger.info("構造化応答受信: status=\(httpResponse.statusCode, privacy: .public)")

        if httpResponse.statusCode == 429 {
            return .rateLimited
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let bodyPreview = String(data: data, encoding: .utf8) ?? "(本文なし)"
            Self.logger.error("APIエラー(構造化応答): status=\(httpResponse.statusCode, privacy: .public) body=\(bodyPreview, privacy: .public)")
            let message = Self.extractErrorMessage(from: data) ?? "サーバーエラーが発生しました。"
            if httpResponse.statusCode == 401 {
                throw LLMError.unauthorized
            }
            throw LLMError.apiError(statusCode: httpResponse.statusCode, message: message)
        }

        let completion: ChatCompletionResponse
        do {
            completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            let bodyPreview = String(data: data, encoding: .utf8) ?? "(本文なし)"
            Self.logger.error("構造化応答のデコードに失敗: \(error.localizedDescription, privacy: .public) body=\(bodyPreview, privacy: .public)")
            throw LLMError.decoding(error.localizedDescription)
        }

        guard let content = completion.choices.first?.message.content else {
            Self.logger.error("構造化応答のcontentが空です")
            throw LLMError.decoding("応答内容が空です。")
        }

        guard let contentData = Self.stripCodeFences(content).data(using: .utf8) else {
            throw LLMError.decoding("応答内容をUTF-8として解釈できません。")
        }

        do {
            let decoded = try JSONDecoder().decode(T.self, from: contentData)
            return .success(decoded)
        } catch {
            Self.logger.error("応答のデコードに失敗: \(error.localizedDescription, privacy: .public) content=\(content, privacy: .public)")
            throw LLMError.decoding(error.localizedDescription)
        }
    }

    // MARK: - 共通ヘルパー

    nonisolated private static func requestMessages(
        for messages: [ChatMessage],
        systemPrompt: String?
    ) -> [ChatCompletionRequestMessage] {
        var requestMessages: [ChatCompletionRequestMessage] = []

        if let systemPrompt, !systemPrompt.isEmpty {
            requestMessages.append(ChatCompletionRequestMessage(role: "system", content: systemPrompt))
        }

        requestMessages += messages.map { message in
            ChatCompletionRequestMessage(
                role: message.role == .user ? "user" : "assistant",
                content: message.content
            )
        }

        return requestMessages
    }

    /// LLMが指示に反してコードブロック記法でJSONを囲んで返した場合の保険的な除去処理
    nonisolated private static func stripCodeFences(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }

        if let firstNewline = trimmed.firstIndex(of: "\n") {
            trimmed = String(trimmed[trimmed.index(after: firstNewline)...])
        }
        if trimmed.hasSuffix("```") {
            trimmed = String(trimmed.dropLast(3))
        }
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func collectBody(from bytes: URLSession.AsyncBytes) async throws -> Data {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
        }
        return data
    }

    nonisolated private static func extractErrorMessage(from data: Data?) -> String? {
        guard let data else { return nil }
        return (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.error.message
    }
}
