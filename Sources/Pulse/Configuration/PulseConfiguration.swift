import Foundation

/// Configuration for the Pulse streaming engine.
///
/// Controls buffering, rendering cadence, timeouts, and retry behaviour.
public struct PulseConfiguration: Sendable {

    // MARK: - Backpressure

    /// Maximum number of tokens held in the backpressure buffer before
    /// the overflow strategy is applied.
    public let maxBufferSize: Int

    /// Strategy applied when the buffer reaches `maxBufferSize`.
    public let overflowStrategy: OverflowStrategy

    // MARK: - Rendering

    /// The interval at which buffered tokens are flushed to the UI layer.
    public let renderInterval: Duration

    // MARK: - Networking

    /// Timeout for the initial HTTP connection.
    public let connectionTimeout: TimeInterval

    /// Timeout applied to *idle* periods between received bytes.
    public let streamIdleTimeout: TimeInterval

    // MARK: - Retry

    /// Maximum number of automatic retry attempts on transient failures.
    public let maxRetryAttempts: Int

    /// Base delay between retries (exponential backoff is applied).
    public let retryBaseDelay: Duration

    // MARK: - Types

    public enum OverflowStrategy: Sendable {
        /// Drop the oldest buffered tokens when the limit is reached.
        case dropOldest
        /// Batch all buffered tokens into a single delivery.
        case batch
        /// Throw ``PulseError/bufferOverflow`` when the limit is reached.
        case error
    }

    // MARK: - Defaults

    public static let `default` = PulseConfiguration(
        maxBufferSize: 100,
        overflowStrategy: .batch,
        renderInterval: .milliseconds(50),
        connectionTimeout: 30,
        streamIdleTimeout: 60,
        maxRetryAttempts: 3,
        retryBaseDelay: .seconds(1)
    )

    // MARK: - Init

    public init(
        maxBufferSize: Int = 100,
        overflowStrategy: OverflowStrategy = .batch,
        renderInterval: Duration = .milliseconds(50),
        connectionTimeout: TimeInterval = 30,
        streamIdleTimeout: TimeInterval = 60,
        maxRetryAttempts: Int = 3,
        retryBaseDelay: Duration = .seconds(1)
    ) {
        self.maxBufferSize = maxBufferSize
        self.overflowStrategy = overflowStrategy
        self.renderInterval = renderInterval
        self.connectionTimeout = connectionTimeout
        self.streamIdleTimeout = streamIdleTimeout
        self.maxRetryAttempts = maxRetryAttempts
        self.retryBaseDelay = retryBaseDelay
    }
}
