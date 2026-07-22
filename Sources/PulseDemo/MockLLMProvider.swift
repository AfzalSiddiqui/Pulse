import Foundation
import Pulse

/// A mock LLM provider that simulates realistic token-by-token streaming
/// without hitting any real API. Used by the demo app and integration tests.
public final class MockLLMProvider: LLMStreamingProvider, Sendable {

    private let tokenDelay: Duration
    private let responseText: String

    public init(
        responseText: String = """
        Blockchain is a distributed ledger technology that enables secure, \
        transparent, and tamper-proof record-keeping across a decentralized \
        network of computers. Each block in the chain contains a cryptographic \
        hash of the previous block, a timestamp, and transaction data, creating \
        an immutable chain of records. This technology underpins cryptocurrencies \
        like Bitcoin and Ethereum, but its applications extend far beyond digital \
        currencies to supply chain management, healthcare records, financial \
        services, and decentralized identity systems. The consensus mechanisms \
        that validate transactions — such as Proof of Work and Proof of Stake — \
        ensure that no single entity controls the network, making blockchain \
        inherently resistant to censorship and single points of failure.
        """,
        tokenDelay: Duration = .milliseconds(30)
    ) {
        self.responseText = responseText
        self.tokenDelay = tokenDelay
    }

    public func stream(request: LLMRequest) async throws -> TokenStream {
        let words = responseText.split(separator: " ").map { String($0) + " " }
        let delay = tokenDelay

        return TokenStream { continuation in
            let task = Task {
                for word in words {
                    guard !Task.isCancelled else {
                        continuation.finish(throwing: PulseError.cancelled)
                        return
                    }
                    try? await Task.sleep(for: delay)
                    continuation.yield(word)
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
