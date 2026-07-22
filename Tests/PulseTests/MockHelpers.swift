import Foundation
@testable import Pulse

/// A mock LLM provider for unit tests.
final class TestMockProvider: LLMStreamingProvider, @unchecked Sendable {

    var tokens: [String]
    var delay: Duration
    var shouldFail: Bool
    var failError: PulseError

    init(
        tokens: [String] = ["Hello", " ", "World"],
        delay: Duration = .zero,
        shouldFail: Bool = false,
        failError: PulseError = .networkFailure("Mock failure")
    ) {
        self.tokens = tokens
        self.delay = delay
        self.shouldFail = shouldFail
        self.failError = failError
    }

    func stream(request: LLMRequest) async throws -> TokenStream {
        if shouldFail {
            throw failError
        }

        let tokens = self.tokens
        let delay = self.delay

        return TokenStream { continuation in
            let task = Task {
                for token in tokens {
                    guard !Task.isCancelled else {
                        continuation.finish(throwing: PulseError.cancelled)
                        return
                    }
                    if delay != .zero {
                        try? await Task.sleep(for: delay)
                    }
                    continuation.yield(token)
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}

/// Build a raw SSE chunk string from tokens for testing the parser.
func makeSSEChunk(tokens: [String], includeDone: Bool = true) -> String {
    var result = ""
    for token in tokens {
        result += "data: \(token)\n\n"
    }
    if includeDone {
        result += "data: [DONE]\n\n"
    }
    return result
}

/// Build an OpenAI-format SSE chunk for testing the decoder.
func makeOpenAIChunk(content: String) -> String {
    """
    {"choices":[{"delta":{"content":"\(content)"}}]}
    """
}

/// Build an Anthropic-format SSE chunk for testing the decoder.
func makeAnthropicChunk(text: String) -> String {
    """
    {"type":"content_block_delta","delta":{"text":"\(text)"}}
    """
}
