import XCTest
import os
@testable import Pulse

final class CancellationTests: XCTestCase {

    // MARK: - CancellationManager

    func testRegisterAndCancel() async {
        let manager = CancellationManager()
        let didCancel = OSAllocatedUnfairLock(initialState: false)

        let task = Task<Void, Never> {
            try? await Task.sleep(for: .seconds(100))
        }
        let id = await manager.register(task: task, onCancel: {
            didCancel.withLock { $0 = true }
        })

        await manager.cancel(id: id)

        let cancelled = didCancel.withLock { $0 }
        XCTAssertTrue(cancelled)

        let count = await manager.activeCount
        XCTAssertEqual(count, 0)
    }

    func testCancelAll() async {
        let manager = CancellationManager()
        let cancelCount = OSAllocatedUnfairLock(initialState: 0)

        for _ in 0..<5 {
            let task = Task<Void, Never> {
                try? await Task.sleep(for: .seconds(100))
            }
            _ = await manager.register(task: task, onCancel: {
                cancelCount.withLock { $0 += 1 }
            })
        }

        let beforeCount = await manager.activeCount
        XCTAssertEqual(beforeCount, 5)

        await manager.cancelAll()

        let total = cancelCount.withLock { $0 }
        XCTAssertEqual(total, 5)

        let afterCount = await manager.activeCount
        XCTAssertEqual(afterCount, 0)
    }

    func testDeregister() async {
        let manager = CancellationManager()

        let task = Task<Void, Never> {}
        let id = await manager.register(task: task)

        let beforeCount = await manager.activeCount
        XCTAssertEqual(beforeCount, 1)

        await manager.deregister(id: id)

        let afterCount = await manager.activeCount
        XCTAssertEqual(afterCount, 0)
    }

    // MARK: - Task Cancellation Propagation

    func testTaskCancellationStopsProvider() async throws {
        let provider = TestMockProvider(
            tokens: (0..<1000).map { "t\($0)" },
            delay: .milliseconds(10)
        )

        let request = LLMRequest.prompt("test")
        let stream = try await provider.stream(request: request)

        let collected = OSAllocatedUnfairLock(initialState: [String]())
        let task = Task {
            for try await token in stream {
                collected.withLock { $0.append(token) }
            }
        }

        // Let some tokens through
        try await Task.sleep(for: .milliseconds(100))
        task.cancel()

        // Wait for cancellation to propagate
        _ = try? await task.value

        let result = collected.withLock { $0 }
        // Should have received some tokens but not all 1000
        XCTAssertTrue(result.count < 1000)
        XCTAssertTrue(result.count > 0)
    }
}
