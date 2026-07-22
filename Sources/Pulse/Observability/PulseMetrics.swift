import Foundation

/// Production observability metrics for the Pulse streaming engine.
///
/// All mutations are actor-isolated for thread safety. Read snapshots
/// via ``snapshot()`` for display in UI or logging.
public actor PulseMetrics {

    // MARK: - Raw Counters

    private var _tokensReceived: Int = 0
    private var _streamStartTime: ContinuousClock.Instant?
    private var _firstTokenTime: ContinuousClock.Instant?
    private var _streamEndTime: ContinuousClock.Instant?
    private var _cancellationCount: Int = 0
    private var _failureCount: Int = 0
    private var _totalStreams: Int = 0

    // MARK: - Init

    public init() {}

    // MARK: - Recording

    /// Record that a new stream has started.
    public func recordStreamStart() {
        _streamStartTime = .now
        _firstTokenTime = nil
        _streamEndTime = nil
        _tokensReceived = 0
        _totalStreams += 1
    }

    /// Record arrival of the first token.
    public func recordFirstToken() {
        if _firstTokenTime == nil {
            _firstTokenTime = .now
        }
    }

    /// Record a single token arrival.
    public func recordToken() {
        _tokensReceived += 1
        if _firstTokenTime == nil {
            _firstTokenTime = .now
        }
    }

    /// Record that the stream ended successfully.
    public func recordStreamEnd() {
        _streamEndTime = .now
    }

    /// Record a cancellation event.
    public func recordCancellation() {
        _cancellationCount += 1
        _streamEndTime = .now
    }

    /// Record a failure event.
    public func recordFailure() {
        _failureCount += 1
        _streamEndTime = .now
    }

    // MARK: - Computed Metrics

    /// Time To First Token — the interval from stream start to first token arrival.
    public var timeToFirstToken: Duration? {
        guard let start = _streamStartTime, let first = _firstTokenTime else { return nil }
        return first - start
    }

    /// Total number of tokens received in the current/last stream.
    public var tokensReceived: Int {
        _tokensReceived
    }

    /// Total duration of the stream from start to end.
    public var streamDuration: Duration? {
        guard let start = _streamStartTime, let end = _streamEndTime else { return nil }
        return end - start
    }

    /// Tokens per second throughput.
    public var tokensPerSecond: Double? {
        guard let duration = streamDuration,
              _tokensReceived > 0 else { return nil }
        let seconds = Double(duration.components.seconds) +
                      Double(duration.components.attoseconds) / 1e18
        guard seconds > 0 else { return nil }
        return Double(_tokensReceived) / seconds
    }

    /// Average latency between tokens.
    public var averageTokenLatency: Duration? {
        guard let duration = streamDuration, _tokensReceived > 1 else { return nil }
        let totalNanos = duration.components.seconds * 1_000_000_000 +
                         duration.components.attoseconds / 1_000_000_000
        let avgNanos = totalNanos / Int64(_tokensReceived - 1)
        return .nanoseconds(avgNanos)
    }

    /// Total number of cancellations across all streams.
    public var cancellationCount: Int { _cancellationCount }

    /// Total number of failures across all streams.
    public var failureCount: Int { _failureCount }

    /// Total number of streams started.
    public var totalStreams: Int { _totalStreams }

    /// Cancellation rate as a fraction (0.0–1.0).
    public var cancellationRate: Double {
        guard _totalStreams > 0 else { return 0 }
        return Double(_cancellationCount) / Double(_totalStreams)
    }

    /// Failure rate as a fraction (0.0–1.0).
    public var failureRate: Double {
        guard _totalStreams > 0 else { return 0 }
        return Double(_failureCount) / Double(_totalStreams)
    }

    // MARK: - Snapshot

    /// An immutable, `Sendable` snapshot of the current metrics state.
    public struct Snapshot: Sendable {
        public let timeToFirstToken: Duration?
        public let tokensReceived: Int
        public let streamDuration: Duration?
        public let tokensPerSecond: Double?
        public let averageTokenLatency: Duration?
        public let cancellationCount: Int
        public let failureCount: Int
        public let totalStreams: Int
        public let cancellationRate: Double
        public let failureRate: Double
    }

    /// Capture an immutable snapshot for cross-isolation transfer.
    public func snapshot() -> Snapshot {
        Snapshot(
            timeToFirstToken: timeToFirstToken,
            tokensReceived: tokensReceived,
            streamDuration: streamDuration,
            tokensPerSecond: tokensPerSecond,
            averageTokenLatency: averageTokenLatency,
            cancellationCount: cancellationCount,
            failureCount: failureCount,
            totalStreams: totalStreams,
            cancellationRate: cancellationRate,
            failureRate: failureRate
        )
    }

    /// Reset all metrics.
    public func reset() {
        _tokensReceived = 0
        _streamStartTime = nil
        _firstTokenTime = nil
        _streamEndTime = nil
        _cancellationCount = 0
        _failureCount = 0
        _totalStreams = 0
    }
}
