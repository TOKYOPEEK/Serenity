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
        request.timeoutInterval = 30
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
                messages: [Message(role: "system", content: system)] + messages
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
