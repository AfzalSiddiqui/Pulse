import Foundation

/// A provider-agnostic request to an LLM endpoint.
public struct LLMRequest: Sendable {

    /// The conversation messages to send.
    public let messages: [Message]

    /// Model identifier (e.g. `"gpt-4o"`, `"claude-sonnet-4-20250514"`).
    public let model: String

    /// Sampling temperature.
    public let temperature: Double

    /// Maximum tokens to generate.
    public let maxTokens: Int

    /// Whether to request streaming output.
    public let stream: Bool

    /// Optional system prompt.
    public let systemPrompt: String?

    /// Arbitrary additional parameters forwarded to the provider.
    public let additionalParameters: [String: String]

    // MARK: - Message

    public struct Message: Sendable, Codable {
        public let role: Role
        public let content: String

        public enum Role: String, Sendable, Codable {
            case system
            case user
            case assistant
        }

        public init(role: Role, content: String) {
            self.role = role
            self.content = content
        }
    }

    // MARK: - Init

    public init(
        messages: [Message],
        model: String = "gpt-4o",
        temperature: Double = 0.7,
        maxTokens: Int = 4096,
        stream: Bool = true,
        systemPrompt: String? = nil,
        additionalParameters: [String: String] = [:]
    ) {
        self.messages = messages
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.stream = stream
        self.systemPrompt = systemPrompt
        self.additionalParameters = additionalParameters
    }

    /// Convenience initializer for a single user prompt.
    public static func prompt(
        _ text: String,
        model: String = "gpt-4o",
        systemPrompt: String? = nil
    ) -> LLMRequest {
        LLMRequest(
            messages: [Message(role: .user, content: text)],
            model: model,
            systemPrompt: systemPrompt
        )
    }
}
