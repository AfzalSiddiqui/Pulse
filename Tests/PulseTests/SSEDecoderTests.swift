import XCTest
@testable import Pulse

final class SSEDecoderTests: XCTestCase {

    // MARK: - Plain Text

    func testPlainTextDecoding() throws {
        let decoder = SSEDecoder(strategy: .plainText)
        let event = SSEEvent(data: "Hello world")
        let token = try decoder.decode(event)
        XCTAssertEqual(token, "Hello world")
    }

    func testPlainTextSkipsDoneEvent() throws {
        let decoder = SSEDecoder(strategy: .plainText)
        let event = SSEEvent(data: "[DONE]")
        let token = try decoder.decode(event)
        XCTAssertNil(token)
    }

    func testPlainTextSkipsEmptyEvent() throws {
        let decoder = SSEDecoder(strategy: .plainText)
        let event = SSEEvent(data: "")
        let token = try decoder.decode(event)
        XCTAssertNil(token)
    }

    // MARK: - OpenAI

    func testOpenAIDecoding() throws {
        let decoder = SSEDecoder(strategy: .openAI)
        let json = makeOpenAIChunk(content: "Hello")
        let event = SSEEvent(data: json)
        let token = try decoder.decode(event)
        XCTAssertEqual(token, "Hello")
    }

    func testOpenAIReturnsNilForRoleChunk() throws {
        let decoder = SSEDecoder(strategy: .openAI)
        let json = """
        {"choices":[{"delta":{"role":"assistant"}}]}
        """
        let event = SSEEvent(data: json)
        let token = try decoder.decode(event)
        XCTAssertNil(token)
    }

    func testOpenAIThrowsOnMalformedJSON() {
        let decoder = SSEDecoder(strategy: .openAI)
        let event = SSEEvent(data: "not json {{{")
        XCTAssertThrowsError(try decoder.decode(event)) { error in
            guard case PulseError.decodingFailure = error else {
                XCTFail("Expected PulseError.decodingFailure, got \(error)")
                return
            }
        }
    }

    // MARK: - Anthropic

    func testAnthropicDecoding() throws {
        let decoder = SSEDecoder(strategy: .anthropic)
        let json = makeAnthropicChunk(text: "World")
        let event = SSEEvent(data: json)
        let token = try decoder.decode(event)
        XCTAssertEqual(token, "World")
    }

    func testAnthropicSkipsStopEvent() throws {
        let decoder = SSEDecoder(strategy: .anthropic)
        let json = """
        {"type":"message_stop"}
        """
        let event = SSEEvent(data: json)
        let token = try decoder.decode(event)
        XCTAssertNil(token)
    }

    // MARK: - Custom

    func testCustomDecoder() throws {
        let decoder = SSEDecoder(strategy: .custom { data in
            data.uppercased()
        })
        let event = SSEEvent(data: "hello")
        let token = try decoder.decode(event)
        XCTAssertEqual(token, "HELLO")
    }
}
