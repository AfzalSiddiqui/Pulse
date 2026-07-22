import XCTest
@testable import Pulse

final class StreamActorTests: XCTestCase {

    // MARK: - Token Accumulation

    func testAppendAndRetrieve() async {
        let actor = StreamActor()
        await actor.append("Hello")
        await actor.append(" ")
        await actor.append("World")

        let text = await actor.currentText()
        XCTAssertEqual(text, "Hello World")
    }

    func testBatchAppend() async {
        let actor = StreamActor()
        await actor.append(contentsOf: ["A", "B", "C"])

        let tokens = await actor.allTokens()
        XCTAssertEqual(tokens, ["A", "B", "C"])
    }

    func testTokenCount() async {
        let actor = StreamActor()
        await actor.append("1")
        await actor.append("2")
        await actor.append("3")

        let count = await actor.tokenCount()
        XCTAssertEqual(count, 3)
    }

    // MARK: - Lifecycle

    func testMarkComplete() async {
        let actor = StreamActor()
        await actor.append("done")
        await actor.markComplete()

        let finished = await actor.isFinished()
        XCTAssertTrue(finished)

        let error = await actor.streamError()
        XCTAssertNil(error)
    }

    func testMarkFailed() async {
        let actor = StreamActor()
        await actor.markFailed(.networkFailure("test"))

        let finished = await actor.isFinished()
        XCTAssertTrue(finished)

        let error = await actor.streamError()
        XCTAssertEqual(error, .networkFailure("test"))
    }

    // MARK: - Reset

    func testReset() async {
        let actor = StreamActor()
        await actor.append("data")
        await actor.markComplete()
        await actor.reset()

        let text = await actor.currentText()
        XCTAssertEqual(text, "")

        let finished = await actor.isFinished()
        XCTAssertFalse(finished)
    }

    // MARK: - Concurrent Access

    func testConcurrentAppends() async {
        let actor = StreamActor()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    await actor.append("token\(i)")
                }
            }
        }

        let count = await actor.tokenCount()
        XCTAssertEqual(count, 100)
    }
}
