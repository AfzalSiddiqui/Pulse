import XCTest
@testable import Pulse

final class TokenStreamTests: XCTestCase {

    // MARK: - Basic Iteration

    func testIteratesAllTokens() async throws {
        let stream = TokenStream.from(["Hello", " ", "World"])
        var collected: [String] = []

        for try await token in stream {
            collected.append(token)
        }

        XCTAssertEqual(collected, ["Hello", " ", "World"])
    }

    // MARK: - Empty Stream

    func testEmptyStreamFinishesImmediately() async throws {
        let stream = TokenStream.empty
        var count = 0

        for try await _ in stream {
            count += 1
        }

        XCTAssertEqual(count, 0)
    }

    // MARK: - From Text

    func testFromTextSplitsIntoWords() async throws {
        let stream = TokenStream.fromText("Hello beautiful World")
        var collected: [String] = []

        for try await token in stream {
            collected.append(token)
        }

        XCTAssertEqual(collected, ["Hello", "beautiful", "World"])
    }

    // MARK: - Error Propagation

    func testErrorPropagation() async {
        let stream = TokenStream { continuation in
            continuation.yield("token1")
            continuation.finish(throwing: PulseError.networkFailure("test"))
        }

        var received: [String] = []
        do {
            for try await token in stream {
                received.append(token)
            }
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(received, ["token1"])
            guard case PulseError.networkFailure = error else {
                XCTFail("Expected networkFailure, got \(error)")
                return
            }
        }
    }

    // MARK: - Cancellation

    func testCancellationStopsStream() async throws {
        let stream = TokenStream { continuation in
            let task = Task {
                for i in 0..<1000 {
                    guard !Task.isCancelled else {
                        continuation.finish(throwing: PulseError.cancelled)
                        return
                    }
                    continuation.yield("token\(i)")
                    try? await Task.sleep(for: .milliseconds(10))
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }

        var collected: [String] = []

        let consumeTask = Task {
            for try await token in stream {
                collected.append(token)
                if collected.count >= 5 {
                    break
                }
            }
        }

        try await consumeTask.value

        // Should have stopped around 5 tokens
        XCTAssertEqual(collected.count, 5)
    }

    // MARK: - Large Stream

    func testHandlesLargeTokenCount() async throws {
        let count = 10_000
        let tokens = (0..<count).map { "token\($0)" }
        let stream = TokenStream.from(tokens)

        var received = 0
        for try await _ in stream {
            received += 1
        }

        XCTAssertEqual(received, count)
    }
}
