import XCTest
@testable import Pulse

final class ErrorHandlingTests: XCTestCase {

    // MARK: - PulseError Properties

    func testErrorDescriptions() {
        let cases: [(PulseError, String)] = [
            (.networkFailure("timeout"), "Network failure: timeout"),
            (.invalidStream("bad format"), "Invalid stream: bad format"),
            (.cancelled, "Stream cancelled"),
            (.decodingFailure("utf8"), "Decoding failure: utf8"),
            (.serverError(500), "Server error: HTTP 500"),
            (.invalidContentType("text/html"), "Invalid content type: text/html"),
            (.bufferOverflow(100), "Buffer overflow at 100 tokens"),
            (.providerError("rate limit"), "Provider error: rate limit"),
            (.internalError("bug"), "Internal error: bug"),
        ]

        for (error, expected) in cases {
            XCTAssertEqual(error.errorDescription, expected)
        }
    }

    // MARK: - Equatable

    func testErrorEquality() {
        XCTAssertEqual(PulseError.cancelled, PulseError.cancelled)
        XCTAssertEqual(PulseError.serverError(404), PulseError.serverError(404))
        XCTAssertNotEqual(PulseError.serverError(404), PulseError.serverError(500))
    }

    // MARK: - Provider Failure

    func testProviderFailurePropagates() async {
        let provider = TestMockProvider(
            shouldFail: true,
            failError: .serverError(503)
        )

        let request = LLMRequest.prompt("test")

        do {
            _ = try await provider.stream(request: request)
            XCTFail("Expected error to be thrown")
        } catch let error as PulseError {
            XCTAssertEqual(error, .serverError(503))
        } catch {
            XCTFail("Expected PulseError, got \(error)")
        }
    }

    // MARK: - Stream Error

    func testStreamErrorSurfacesOnIteration() async {
        let stream = TokenStream { continuation in
            continuation.yield("partial")
            continuation.finish(throwing: PulseError.invalidStream("truncated"))
        }

        var tokens: [String] = []
        do {
            for try await token in stream {
                tokens.append(token)
            }
            XCTFail("Expected error")
        } catch let error as PulseError {
            XCTAssertEqual(error, .invalidStream("truncated"))
            XCTAssertEqual(tokens, ["partial"])
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}
