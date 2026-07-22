import Foundation

/// Orchestrates a complete streaming session — from request through token delivery.
///
/// Manages the lifecycle of a single generation: connection, streaming, cancellation,
/// backpressure, and metrics collection.
public actor StreamController {

    // MARK: - State

    public enum State: Sendable {
        case idle
        case connecting
        case streaming
        case completed
        case failed(PulseError)
        case cancelled
    }

    private(set) public var state: State = .idle
    private var activeTask: Task<Void, Never>?
    private let provider: any LLMStreamingProvider
    private let backpressureManager: BackpressureManager
    private let metrics: PulseMetrics
    private let configuration: PulseConfiguration

    // MARK: - Init

    public init(
        provider: any LLMStreamingProvider,
        configuration: PulseConfiguration = .default,
        metrics: PulseMetrics = PulseMetrics()
    ) {
        self.provider = provider
        self.configuration = configuration
        self.metrics = metrics
        self.backpressureManager = BackpressureManager(configuration: configuration)
    }

    // MARK: - Stream Management

    /// Start a new streaming generation and return a ``TokenStream``.
    public func startStream(request: LLMRequest) async throws -> TokenStream {
        guard case .idle = state else {
            throw PulseError.internalError("StreamController is not idle; current state: \(state)")
        }

        state = .connecting
        await metrics.recordStreamStart()

        do {
            let rawStream = try await provider.stream(request: request)
            state = .streaming
            await metrics.recordFirstToken()

            return TokenStream { [backpressureManager, metrics] continuation in
                let task = Task {
                    do {
                        for try await token in rawStream {
                            try Task.checkCancellation()
                            await metrics.recordToken()
                            let buffered = await backpressureManager.buffer(token: token)
                            for t in buffered {
                                continuation.yield(t)
                            }
                        }

                        // Flush remaining buffered tokens
                        let remaining = await backpressureManager.flush()
                        for t in remaining {
                            continuation.yield(t)
                        }

                        await metrics.recordStreamEnd()
                        continuation.finish()
                    } catch is CancellationError {
                        await metrics.recordCancellation()
                        continuation.finish(throwing: PulseError.cancelled)
                    } catch {
                        await metrics.recordFailure()
                        continuation.finish(throwing: error)
                    }
                }

                continuation.onTermination = { @Sendable _ in
                    task.cancel()
                }
            }
        } catch {
            state = .failed(error as? PulseError ?? .networkFailure(error.localizedDescription))
            await metrics.recordFailure()
            throw error
        }
    }

    /// Cancel the active generation.
    public func cancel() {
        activeTask?.cancel()
        activeTask = nil
        state = .cancelled
    }

    /// Reset the controller to idle for reuse.
    public func reset() {
        activeTask?.cancel()
        activeTask = nil
        state = .idle
    }
}
