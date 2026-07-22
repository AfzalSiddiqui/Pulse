import XCTest
@testable import Pulse

final class SSEParserTests: XCTestCase {

    // MARK: - Basic Parsing

    func testParsesSingleEvent() {
        var parser = SSEParser()
        let events = parser.parse(chunk: "data: hello\n\n")
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.data, "hello")
        XCTAssertEqual(events.first?.event, "message")
    }

    func testParsesMultipleEvents() {
        var parser = SSEParser()
        let chunk = "data: token1\n\ndata: token2\n\ndata: token3\n\n"
        let events = parser.parse(chunk: chunk)
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events.map(\.data), ["token1", "token2", "token3"])
    }

    func testParsesDoneEvent() {
        var parser = SSEParser()
        let events = parser.parse(chunk: "data: [DONE]\n\n")
        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(events.first!.isDone)
    }

    // MARK: - Incremental / Partial Frames

    func testHandlesPartialChunks() {
        var parser = SSEParser()

        // First chunk — incomplete event (no double newline)
        let events1 = parser.parse(chunk: "data: hel")
        XCTAssertTrue(events1.isEmpty)

        // Second chunk — completes the event
        let events2 = parser.parse(chunk: "lo\n\n")
        XCTAssertEqual(events2.count, 1)
        XCTAssertEqual(events2.first?.data, "hello")
    }

    func testHandlesSplitAcrossMultipleChunks() {
        var parser = SSEParser()

        XCTAssertTrue(parser.parse(chunk: "da").isEmpty)
        XCTAssertTrue(parser.parse(chunk: "ta: wo").isEmpty)
        XCTAssertTrue(parser.parse(chunk: "rld\n").isEmpty)

        let events = parser.parse(chunk: "\n")
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.data, "world")
    }

    // MARK: - Multi-line Data

    func testParsesMultiLineData() {
        var parser = SSEParser()
        let chunk = "data: line1\ndata: line2\ndata: line3\n\n"
        let events = parser.parse(chunk: chunk)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.data, "line1\nline2\nline3")
    }

    // MARK: - Event Types

    func testParsesCustomEventType() {
        var parser = SSEParser()
        let chunk = "event: custom\ndata: payload\n\n"
        let events = parser.parse(chunk: chunk)
        XCTAssertEqual(events.first?.event, "custom")
        XCTAssertEqual(events.first?.data, "payload")
    }

    // MARK: - ID and Retry

    func testParsesIdField() {
        var parser = SSEParser()
        let chunk = "id: 42\ndata: hello\n\n"
        let events = parser.parse(chunk: chunk)
        XCTAssertEqual(events.first?.id, "42")
    }

    func testParsesRetryField() {
        var parser = SSEParser()
        let chunk = "retry: 3000\ndata: hello\n\n"
        let events = parser.parse(chunk: chunk)
        XCTAssertEqual(events.first?.retry, 3000)
    }

    // MARK: - Edge Cases

    func testIgnoresComments() {
        var parser = SSEParser()
        let chunk = ": this is a comment\ndata: hello\n\n"
        let events = parser.parse(chunk: chunk)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.data, "hello")
    }

    func testIgnoresEmptyDataBlocks() {
        var parser = SSEParser()
        let chunk = "\n\n"
        let events = parser.parse(chunk: chunk)
        XCTAssertTrue(events.isEmpty)
    }

    func testHandlesWindowsLineEndings() {
        var parser = SSEParser()
        let chunk = "data: hello\r\n\r\n"
        let events = parser.parse(chunk: chunk)
        // Should parse correctly even with \r\n
        XCTAssertFalse(events.isEmpty)
        XCTAssertEqual(events.first?.data, "hello")
    }

    func testDataWithColonInValue() {
        var parser = SSEParser()
        let chunk = "data: key: value\n\n"
        let events = parser.parse(chunk: chunk)
        XCTAssertEqual(events.first?.data, "key: value")
    }

    func testDataWithNoSpaceAfterColon() {
        var parser = SSEParser()
        let chunk = "data:noSpace\n\n"
        let events = parser.parse(chunk: chunk)
        XCTAssertEqual(events.first?.data, "noSpace")
    }

    func testEmptyDataField() {
        var parser = SSEParser()
        let chunk = "data:\n\n"
        let events = parser.parse(chunk: chunk)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.data, "")
        XCTAssertTrue(events.first!.isEmpty)
    }
}
