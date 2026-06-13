import Foundation

// MARK: - LLMError
enum LLMError: LocalizedError {
    case noAPIKey
    case badURL
    case unauthorized
    case rateLimited
    case serverError(Int)
    case emptyResponse
    case network(Error)
    case api(String)   // message extracted from the provider's error body

    var errorDescription: String? {
        switch self {
        case .noAPIKey:         return L("llm.error.no_key")
        case .badURL:           return L("llm.error.bad_url")
        case .unauthorized:     return L("llm.error.unauthorized")
        case .rateLimited:      return L("llm.error.rate_limited")
        case .serverError:      return L("llm.error.server")
        case .emptyResponse:    return L("llm.error.empty")
        case .network:          return L("llm.error.network")
        case .api(let message): return message
        }
    }
}

// MARK: - LLMClient
/// Async client for Anthropic and OpenAI-compatible chat-completion endpoints.
struct LLMClient {
    struct Config {
        let endpoint: String
        let model: String
        let apiKey: String
        /// OpenAI-style reasoning effort ("none" disables slow reasoning).
        /// Only sent to providers known to accept it — nil omits the field.
        var reasoningEffort: String? = nil
    }

    struct Message: Codable {
        let role: String
        let content: String
    }

    // MARK: Request/response payloads

    private struct AnthropicRequest: Encodable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [Message]
    }

    private struct AnthropicResponse: Decodable {
        struct Content: Decodable { let text: String? }
        let content: [Content]?
    }

    private struct OpenAIRequest: Encodable {
        let model: String
        let max_tokens: Int
        let messages: [Message]
        let reasoning_effort: String?

        enum CodingKeys: String, CodingKey {
            case model, max_tokens, messages, reasoning_effort
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(model, forKey: .model)
            try c.encode(max_tokens, forKey: .max_tokens)
            try c.encode(messages, forKey: .messages)
            // Omitted entirely when nil so strict providers don't reject it.
            try c.encodeIfPresent(reasoning_effort, forKey: .reasoning_effort)
        }
    }

    private struct OpenAIResponse: Decodable {
        struct Choice: Decodable {
            struct Msg: Decodable { let content: String? }
            let message: Msg?
        }
        let choices: [Choice]?
    }

    /// Both providers wrap errors as {"error": {"message": "..."}}
    private struct ProviderErrorBody: Decodable {
        struct Err: Decodable { let message: String? }
        let error: Err?
    }

    // MARK: API

    func complete(
        system: String,
        messages: [Message],
        maxTokens: Int,
        config: Config
    ) async throws -> String {
        guard !config.apiKey.isEmpty else { throw LLMError.noAPIKey }

        let endpoint = config.endpoint.isEmpty
            ? "https://api.anthropic.com/v1/messages"
            : config.endpoint
        guard let url = URL(string: endpoint) else { throw LLMError.badURL }

        let isAnthropic = endpoint.contains("anthropic.com")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if isAnthropic {
            request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.httpBody = try JSONEncoder().encode(AnthropicRequest(
                model: config.model, max_tokens: maxTokens, system: system, messages: messages
            ))
        } else {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(OpenAIRequest(
                model: config.model, max_tokens: maxTokens,
                messages: [Message(role: "system", content: system)] + messages,
                reasoning_effort: config.reasoningEffort
            ))
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LLMError.network(error)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw httpError(status: http.statusCode, data: data)
        }

        let text: String?
        if isAnthropic {
            text = (try? JSONDecoder().decode(AnthropicResponse.self, from: data))?
                .content?.first?.text
        } else {
            text = (try? JSONDecoder().decode(OpenAIResponse.self, from: data))?
                .choices?.first?.message?.content
        }
        guard let text, !text.isEmpty else { throw LLMError.emptyResponse }
        return text
    }

    // MARK: Streaming (SSE)

    private struct OpenAIStreamChunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable { let content: String? }
            let delta: Delta?
        }
        let choices: [Choice]?
    }

    private struct AnthropicStreamChunk: Decodable {
        struct Delta: Decodable { let text: String? }
        let type: String?
        let delta: Delta?
    }

    private struct OpenAIStreamRequest: Encodable {
        let model: String
        let max_tokens: Int
        let messages: [Message]
        let reasoning_effort: String?
        let stream = true
        enum CodingKeys: String, CodingKey { case model, max_tokens, messages, reasoning_effort, stream }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(model, forKey: .model)
            try c.encode(max_tokens, forKey: .max_tokens)
            try c.encode(messages, forKey: .messages)
            try c.encode(stream, forKey: .stream)
            try c.encodeIfPresent(reasoning_effort, forKey: .reasoning_effort)
        }
    }

    private struct AnthropicStreamRequest: Encodable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [Message]
        let stream = true
    }

    /// Streams the reply token-by-token. Yields text deltas as they arrive.
    func stream(
        system: String,
        messages: [Message],
        maxTokens: Int,
        config: Config
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard !config.apiKey.isEmpty else { throw LLMError.noAPIKey }
                    let endpoint = config.endpoint.isEmpty
                        ? "https://api.anthropic.com/v1/messages"
                        : config.endpoint
                    guard let url = URL(string: endpoint) else { throw LLMError.badURL }

                    let isAnthropic = endpoint.contains("anthropic.com")
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 60
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    if isAnthropic {
                        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
                        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                        request.httpBody = try JSONEncoder().encode(AnthropicStreamRequest(
                            model: config.model, max_tokens: maxTokens, system: system, messages: messages))
                    } else {
                        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
                        request.httpBody = try JSONEncoder().encode(OpenAIStreamRequest(
                            model: config.model, max_tokens: maxTokens,
                            messages: [Message(role: "system", content: system)] + messages,
                            reasoning_effort: config.reasoningEffort))
                    }

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                        throw httpError(status: http.statusCode, data: Data())
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let d = payload.data(using: .utf8) else { continue }
                        if isAnthropic {
                            if let chunk = try? JSONDecoder().decode(AnthropicStreamChunk.self, from: d),
                               chunk.type == "content_block_delta", let t = chunk.delta?.text {
                                continuation.yield(t)
                            }
                        } else if let chunk = try? JSONDecoder().decode(OpenAIStreamChunk.self, from: d),
                                  let t = chunk.choices?.first?.delta?.content {
                            continuation.yield(t)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: (error as? LLMError) ?? LLMError.network(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func httpError(status: Int, data: Data) -> LLMError {
        switch status {
        case 401, 403: return .unauthorized
        case 429:      return .rateLimited
        case 500...:   return .serverError(status)
        default:
            if let body = try? JSONDecoder().decode(ProviderErrorBody.self, from: data),
               let message = body.error?.message, !message.isEmpty {
                return .api(message)
            }
            return .serverError(status)
        }
    }
}
