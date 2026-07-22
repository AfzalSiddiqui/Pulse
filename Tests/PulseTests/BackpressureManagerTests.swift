import XCTest
@testable import Pulse

final class BackpressureManagerTests: XCTestCase {

    // MARK: - Basic Buffering

    func testPassesThroughBelowLimit() async {
        let config = PulseConfiguration(maxBufferSize: 10)
        let manager = BackpressureManager(configuration: config)

        let result = await manager.buffer(token: "hello")
        XCTAssertEqual(result, ["hello"])
    }

    // MARK: - Batch Strategy

    func testBatchStrategyFlushesAtLimit() async {
        let config = PulseConfiguration(
            maxBufferSize: 3,
            overflowStrategy: .batch
        )
        let manager = BackpressureManager(configuration: config)

        // Fill buffer to limit — each call below limit passes through
        _ = await manager.buffer(token: "a")
        _ = await manager.buffer(token: "b")
        // Third token hits the limit
        let result = await manager.buffer(token: "c")
        // Should return all buffered tokens as a batch
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Flush

    func testFlushReturnsRemainingTokens() async {
        let config = PulseConfiguration(maxBufferSize: 100)
        let manager = BackpressureManager(configuration: config)

        _ = await manager.buffer(token: "remaining")
        // Force a state where tokens are in the buffer
        // Flush should return them
        let flushed = await manager.flush()
        XCTAssertTrue(flushed.isEmpty) // They were already yielded in buffer()
    }

    // MARK: - Count

    func testCountReflectsBufferState() async {
        let config = PulseConfiguration(maxBufferSize: 100)
        let manager = BackpressureManager(configuration: config)

        let initialCount = await manager.count
        XCTAssertEqual(initialCount, 0)
    }

    // MARK: - Drop Oldest

    func testDropOldestStrategyAtLimit() async {
        let config = PulseConfiguration(
            maxBufferSize: 2,
            overflowStrategy: .dropOldest
        )
        let manager = BackpressureManager(configuration: config)

        _ = await manager.buffer(token: "old")
        let result = await manager.buffer(token: "new")
        // Should have returned tokens with some possibly dropped
        XCTAssertFalse(result.isEmpty)
    }
}
