import XCTest
@testable import Pulse

final class IntegrationTests: XCTestCase {

    // MARK: - End-to-End: Mock Provider → TokenStream → Collection

    func testEndToEndStreaming() async throws {
        let provider = TestMockProvider(
            tokens: ["Hello", " ", "World", "!"]
        )

        let request = LLMRequest.prompt("Say hello")
        let stream = try await provider.stream(request: request)

        var result = ""
        for try await token in stream {
            result.append(token)
        }

        XCTAssertEqual(result, "Hello World!")
    }

    // MARK: - SSE Parser → Decoder Pipeline

    func testSSEParserToDecoderPipeline() throws {
        var parser = SSEParser()
        let decoder = SSEDecoder(strategy: .plainText)

        let chunk = "data: Hello\n\ndata: World\n\ndata: [DONE]\n\n"
        let events = parser.parse(chunk: chunk)

        var tokens: [String] = []
        for event in events {
            if let token = try decoder.decode(event) {
                tokens.append(token)
            }
        }

        XCTAssertEqual(tokens, ["Hello", "World"])
    }

    // MARK: - OpenAI Format Pipeline

    func testOpenAIFormatPipeline() throws {
        var parser = SSEParser()
        let decoder = SSEDecoder(strategy: .openAI)

        let chunk1 = "data: \(makeOpenAIChunk(content: "Hello"))\n\n"
        let chunk2 = "data: \(makeOpenAIChunk(content: " World"))\n\n"
        let done = "data: [DONE]\n\n"

        var tokens: [String] = []

        for chunk in [chunk1, chunk2, done] {
            let events = parser.parse(chunk: chunk)
            for event in events {
                if let token = try decoder.decode(event) {
                    tokens.append(token)
                }
            }
        }

        XCTAssertEqual(tokens, ["Hello", " World"])
    }

    // MARK: - Anthropic Format Pipeline

    func testAnthropicFormatPipeline() throws {
        var parser = SSEParser()
        let decoder = SSEDecoder(strategy: .anthropic)

        let chunk1 = "data: \(makeAnthropicChunk(text: "Block"))\n\n"
        let chunk2 = "data: \(makeAnthropicChunk(text: "chain"))\n\n"
        let stop = "data: {\"type\":\"message_stop\"}\n\n"
        let done = "data: [DONE]\n\n"

        var tokens: [String] = []

        for chunk in [chunk1, chunk2, stop, done] {
            let events = parser.parse(chunk: chunk)
            for event in events {
                if let token = try decoder.decode(event) {
                    tokens.append(token)
                }
            }
        }

        XCTAssertEqual(tokens, ["Block", "chain"])
    }

    // MARK: - StreamActor Integration

    func testStreamActorAccumulatesFromTokenStream() async throws {
        let actor = StreamActor()
        let stream = TokenStream.from(["A", "B", "C", "D", "E"])

        for try await token in stream {
            await actor.append(token)
        }

        await actor.markComplete()

        let text = await actor.currentText()
        XCTAssertEqual(text, "ABCDE")
        XCTAssertEqual(await actor.tokenCount(), 5)
        XCTAssertTrue(await actor.isFinished())
    }

    // MARK: - StreamController

    func testStreamControllerLifecycle() async throws {
        let provider = TestMockProvider(
            tokens: ["x", "y", "z"]
        )
        let controller = StreamController(provider: provider)

        let stream = try await controller.startStream(
            request: LLMRequest.prompt("test")
        )

        var result: [String] = []
        for try await token in stream {
            result.append(token)
        }

        XCTAssertEqual(result, ["x", "y", "z"])
    }

    // MARK: - Metrics Integration

    func testMetricsRecordThroughPipeline() async throws {
        let metrics = PulseMetrics()
        let provider = TestMockProvider(
            tokens: ["a", "b", "c"],
            delay: .milliseconds(5)
        )

        let controller = StreamController(
            provider: provider,
            metrics: metrics
        )

        let stream = try await controller.startStream(
            request: LLMRequest.prompt("test")
        )

        for try await _ in stream {}

        let snap = await metrics.snapshot()
        XCTAssertEqual(snap.tokensReceived, 3)
        XCTAssertEqual(snap.totalStreams, 1)
        XCTAssertNotNil(snap.timeToFirstToken)
    }

    // MARK: - Large Response Stability

    func testLargeResponseDoesNotExhaustMemory() async throws {
        let tokenCount = 20_000
        let tokens = (0..<tokenCount).map { "word\($0) " }
        let provider = TestMockProvider(tokens: tokens)

        let stream = try await provider.stream(
            request: LLMRequest.prompt("large")
        )

        let actor = StreamActor()
        var count = 0

        for try await token in stream {
            await actor.append(token)
            count += 1
        }

        XCTAssertEqual(count, tokenCount)
        XCTAssertEqual(await actor.tokenCount(), tokenCount)
    }

    // MARK: - Cancellation During Stream

    func testCancellationDuringActiveStream() async throws {
        let provider = TestMockProvider(
            tokens: (0..<500).map { "t\($0)" },
            delay: .milliseconds(5)
        )

        let controller = StreamController(provider: provider)
        let stream = try await controller.startStream(
            request: LLMRequest.prompt("test")
        )

        var received = 0

        let task = Task {
            for try await _ in stream {
                received += 1
                if received >= 10 {
                    break
                }
            }
        }

        try await task.value

        XCTAssertGreaterThanOrEqual(received, 10)
        XCTAssertLessThan(received, 500)
    }
}
