import Foundation

/// Protocol abstracting any LLM backend capable of streaming token responses.
///
/// Conform to this protocol to plug Pulse into OpenAI, Anthropic, Azure,
/// local Llama servers, or custom enterprise banking models.
public protocol LLMStreamingProvider: Sendable {

    /// Open a streaming connection and return an async sequence of token strings.
    ///
    /// - Parameter request: The provider-agnostic request payload.
    /// - Returns: A ``TokenStream`` that yields tokens as they arrive.
    func stream(request: LLMRequest) async throws -> TokenStream
}
