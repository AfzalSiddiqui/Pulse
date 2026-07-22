import Foundation

/// A type-erased `AsyncSequence` that yields token strings one at a time.
///
/// This is the core streaming primitive of the Pulse engine. It wraps an
/// `AsyncThrowingStream<String, Error>` while exposing a clean public API
/// with full Swift 6 `Sendable` compliance.
public struct TokenStream: AsyncSequence, Sendable {
    public typealias Element = String

    private let makeStream: @Sendable (AsyncThrowingStream<String, Error>.Continuation) -> Void

    // The underlying stream, created lazily.
    private let stream: AsyncThrowingStream<String, Error>

    // MARK: - Init

    /// Create a ``TokenStream`` from a builder closure that drives a continuation.
    public init(
        _ build: @Sendable @escaping (AsyncThrowingStream<String, Error>.Continuation) -> Void
    ) {
        self.makeStream = build
        self.stream = AsyncThrowingStream(build)
    }

    /// Create a ``TokenStream`` from an existing `AsyncThrowingStream`.
    public init(wrapping stream: AsyncThrowingStream<String, Error>) {
        self.stream = stream
        self.makeStream = { _ in }
    }

    // MARK: - AsyncSequence

    public struct AsyncIterator: AsyncIteratorProtocol {
        var base: AsyncThrowingStream<String, Error>.AsyncIterator

        public mutating func next() async throws -> String? {
            try await base.next()
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(base: stream.makeAsyncIterator())
    }
}

// MARK: - Convenience Factories

extension TokenStream {

    /// Create an empty stream that finishes immediately.
    public static var empty: TokenStream {
        TokenStream { $0.finish() }
    }

    /// Create a stream from an array of tokens (useful for testing).
    public static func from(_ tokens: [String]) -> TokenStream {
        TokenStream { continuation in
            for token in tokens {
                continuation.yield(token)
            }
            continuation.finish()
        }
    }

    /// Create a stream from a single string, split into word-level tokens.
    public static func fromText(_ text: String) -> TokenStream {
        let words = text.split(separator: " ").map(String.init)
        return .from(words)
    }
}
