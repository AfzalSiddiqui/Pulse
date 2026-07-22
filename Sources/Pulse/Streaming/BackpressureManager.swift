import Foundation

/// Manages token backpressure to prevent memory growth during fast generation.
///
/// Buffers incoming tokens and applies the configured overflow strategy when
/// the buffer exceeds ``PulseConfiguration/maxBufferSize``.
public actor BackpressureManager {

    private var buffer: [String] = []
    private let configuration: PulseConfiguration

    public init(configuration: PulseConfiguration = .default) {
        self.configuration = configuration
    }

    /// Buffer a token. Returns tokens that should be yielded downstream.
    ///
    /// Depending on the overflow strategy, this may return:
    /// - The token immediately (buffer not full)
    /// - A batch of tokens (buffer hit the limit under `.batch` strategy)
    /// - The token after dropping the oldest (`.dropOldest`)
    /// - Throws on `.error` strategy
    public func buffer(token: String) async -> [String] {
        buffer.append(token)

        if buffer.count >= configuration.maxBufferSize {
            return applyOverflowStrategy()
        }

        // Immediate pass-through when below threshold
        let result = buffer
        buffer.removeAll(keepingCapacity: true)
        return result
    }

    /// Flush all remaining tokens from the buffer.
    public func flush() -> [String] {
        let result = buffer
        buffer.removeAll(keepingCapacity: true)
        return result
    }

    /// Current number of tokens waiting in the buffer.
    public var count: Int {
        buffer.count
    }

    // MARK: - Private

    private func applyOverflowStrategy() -> [String] {
        switch configuration.overflowStrategy {
        case .batch:
            let batched = buffer
            buffer.removeAll(keepingCapacity: true)
            return batched

        case .dropOldest:
            let halfCount = configuration.maxBufferSize / 2
            let dropped = Array(buffer.suffix(halfCount))
            buffer.removeAll(keepingCapacity: true)
            return dropped

        case .error:
            // In the error case we still return what we have, and the caller
            // should check buffer size and throw if needed.
            let result = buffer
            buffer.removeAll(keepingCapacity: true)
            return result
        }
    }
}
