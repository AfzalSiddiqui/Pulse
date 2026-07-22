import Foundation

/// High-level LLM client that orchestrates streaming requests.
///
/// Acts as the primary entry point for Pulse consumers. Supports pluggable
/// ``LLMStreamingProvider`` backends, with a built-in OpenAI-compatible default.
public final class LLMClient: Sendable {

    private let baseURL: URL
    private let apiKey: String
    private let session: StreamingSession
    private let configuration: PulseConfiguration
    private let decoder: SSEDecoder

    // MARK: - Init

    public init(
        baseURL: URL,
        apiKey: String,
        decodingStrategy: SSEDecoder.DecodingStrategy = .openAI,
        configuration: PulseConfiguration = .default,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.configuration = configuration
        self.decoder = SSEDecoder(strategy: decodingStrategy)
        self.session = StreamingSession(
            reader: HTTPStreamReader(session: urlSession, configuration: configuration),
            decoder: SSEDecoder(strategy: decodingStrategy),
            configuration: configuration
        )
    }

    // MARK: - Streaming

    /// Stream tokens for the given prompt string (convenience).
    public func stream(prompt: String) async throws -> TokenStream {
        let request = LLMRequest.prompt(prompt)
        return try await stream(request: request)
    }

    /// Stream tokens for a fully specified ``LLMRequest``.
    public func stream(request llmRequest: LLMRequest) async throws -> TokenStream {
        let urlRequest = try buildURLRequest(from: llmRequest)
        return try await session.start(request: urlRequest)
    }

    // MARK: - Request Building

    private func buildURLRequest(from llmRequest: LLMRequest) throws -> URLRequest {
        let endpoint = baseURL.appendingPathComponent("chat/completions")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = configuration.connectionTimeout

        var body: [String: Any] = [
            "model": llmRequest.model,
            "temperature": llmRequest.temperature,
            "max_tokens": llmRequest.maxTokens,
            "stream": llmRequest.stream
        ]

        var messages: [[String: String]] = []

        if let systemPrompt = llmRequest.systemPrompt {
            messages.append(["role": "system", "content": systemPrompt])
        }

        for message in llmRequest.messages {
            messages.append(["role": message.role.rawValue, "content": message.content])
        }

        body["messages"] = messages

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return request
    }
}

// MARK: - LLMStreamingProvider Conformance

extension LLMClient: LLMStreamingProvider {}
