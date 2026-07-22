import XCTest
@testable import Pulse

final class MetricsTests: XCTestCase {

    func testInitialState() async {
        let metrics = PulseMetrics()
        let snap = await metrics.snapshot()

        XCTAssertNil(snap.timeToFirstToken)
        XCTAssertEqual(snap.tokensReceived, 0)
        XCTAssertNil(snap.streamDuration)
        XCTAssertNil(snap.tokensPerSecond)
        XCTAssertEqual(snap.cancellationCount, 0)
        XCTAssertEqual(snap.failureCount, 0)
        XCTAssertEqual(snap.totalStreams, 0)
    }

    func testRecordingLifecycle() async throws {
        let metrics = PulseMetrics()

        await metrics.recordStreamStart()
        try await Task.sleep(for: .milliseconds(10))
        await metrics.recordFirstToken()
        await metrics.recordToken()
        await metrics.recordToken()
        await metrics.recordToken()
        await metrics.recordStreamEnd()

        let snap = await metrics.snapshot()

        XCTAssertNotNil(snap.timeToFirstToken)
        XCTAssertEqual(snap.tokensReceived, 3)
        XCTAssertNotNil(snap.streamDuration)
        XCTAssertNotNil(snap.tokensPerSecond)
        XCTAssertEqual(snap.totalStreams, 1)
    }

    func testCancellationTracking() async {
        let metrics = PulseMetrics()

        await metrics.recordStreamStart()
        await metrics.recordCancellation()

        let snap = await metrics.snapshot()
        XCTAssertEqual(snap.cancellationCount, 1)
        XCTAssertEqual(snap.cancellationRate, 1.0)
    }

    func testFailureTracking() async {
        let metrics = PulseMetrics()

        await metrics.recordStreamStart()
        await metrics.recordFailure()

        await metrics.recordStreamStart()
        await metrics.recordStreamEnd()

        let snap = await metrics.snapshot()
        XCTAssertEqual(snap.failureCount, 1)
        XCTAssertEqual(snap.totalStreams, 2)
        XCTAssertEqual(snap.failureRate, 0.5)
    }

    func testReset() async {
        let metrics = PulseMetrics()

        await metrics.recordStreamStart()
        await metrics.recordToken()
        await metrics.recordStreamEnd()
        await metrics.reset()

        let snap = await metrics.snapshot()
        XCTAssertEqual(snap.tokensReceived, 0)
        XCTAssertEqual(snap.totalStreams, 0)
    }
}
