import Foundation

/// Coordinates structured cancellation across the streaming pipeline.
///
/// Ensures that when a user taps "Stop", cancellation propagates through:
/// 1. The Swift `Task` tree
/// 2. The underlying `URLSession` data task
/// 3. The SSE parser
/// 4. The UI rendering pipeline
public actor CancellationManager {

    // MARK: - State

    private var activeTasks: [UUID: Task<Void, Never>] = [:]
    private var cancellationHandlers: [UUID: @Sendable () -> Void] = [:]

    // MARK: - Registration

    /// Register a cancellable task and return its identifier.
    @discardableResult
    public func register(
        task: Task<Void, Never>,
        onCancel: (@Sendable () -> Void)? = nil
    ) -> UUID {
        let id = UUID()
        activeTasks[id] = task
        if let handler = onCancel {
            cancellationHandlers[id] = handler
        }
        return id
    }

    /// Cancel a specific task by its identifier.
    public func cancel(id: UUID) {
        activeTasks[id]?.cancel()
        cancellationHandlers[id]?()
        activeTasks.removeValue(forKey: id)
        cancellationHandlers.removeValue(forKey: id)
    }

    /// Cancel all active tasks.
    public func cancelAll() {
        for (id, task) in activeTasks {
            task.cancel()
            cancellationHandlers[id]?()
        }
        activeTasks.removeAll()
        cancellationHandlers.removeAll()
    }

    /// Remove a completed task from tracking.
    public func deregister(id: UUID) {
        activeTasks.removeValue(forKey: id)
        cancellationHandlers.removeValue(forKey: id)
    }

    /// Number of currently tracked tasks.
    public var activeCount: Int {
        activeTasks.count
    }
}
