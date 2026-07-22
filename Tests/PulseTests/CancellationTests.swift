import XCTest
@testable import Pulse

final class CancellationTests: XCTestCase {

    // MARK: - CancellationManager

    func testRegisterAndCancel() async {
        let manager = CancellationManager()
        var didCancel = false

        let task = Task { try? await Task.sleep(for: .seconds(100)) }
        let id = await manager.register(task: task, onCancel: { didCancel = true })

        await manager.cancel(id: id)

        XCTAssertTrue(didCancel)
        XCTAssertEqual(await manager.activeCount, 0)
    }

    func testCancelAll() async {
        let manager = CancellationManager()
        var cancelCount = 0

        for _ in 0..<5 {
            let task = Task { try? await Task.sleep(for: .seconds(100)) }
            _ = await manager.register(task: task, onCancel: { cancelCount += 1 })
        }

        XCTAssertEqual(await manager.activeCount, 5)

        await manager.cancelAll()

        XCTAssertEqual(cancelCount, 5)
        XCTAssertEqual(await manager.activeCount, 0)
    }

    func testDeregister() async {
        let manager = CancellationManager()

        let task = Task {}
        let id = await manager.register(task: task)

        XCTAssertEqual(await manager.activeCount, 1)

        await manager.deregister(id: id)

        XCTAssertEqual(await manager.activeCount, 0)
    }

    // MARK: - Task Cancellation Propagation

    func testTaskCancellationStopsProvider() async throws {
        let provider = TestMockProvider(
            tokens: (0..<1000).map { "t\($0)" },
            delay: .milliseconds(10)
        )

        let request = LLMRequest.prompt("test")
        let stream = try await provider.stream(request: request)

        var collected: [String] = []
        let task = Task {
            for try await token in stream {
                collected.append(token)
            }
        }

        // Let some tokens through
        try await Task.sleep(for: .milliseconds(100))
        task.cancel()

        // Wait for cancellation to propagate
        try? await task.value

        // Should have received some tokens but not all 1000
        XCTAssertTrue(collected.count < 1000)
        XCTAssertTrue(collected.count > 0)
    }
}
