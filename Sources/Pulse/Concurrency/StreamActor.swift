import Foundation

/// Actor-isolated container for streaming state.
///
/// Provides thread-safe accumulation of streamed tokens and exposes
/// the current full text without data races.
public actor StreamActor {

    // MARK: - State

    private var tokens: [String] = []
    private var isComplete: Bool = false
    private var error: PulseError?

    // MARK: - Token Management

    /// Append a single token to the accumulated response.
    public func append(_ token: String) {
        tokens.append(token)
    }

    /// Append multiple tokens at once (batch delivery).
    public func append(contentsOf newTokens: [String]) {
        tokens.append(contentsOf: newTokens)
    }

    /// The concatenated full-text response so far.
    public func currentText() -> String {
        tokens.joined()
    }

    /// The raw token array.
    public func allTokens() -> [String] {
        tokens
    }

    /// Total number of tokens received.
    public func tokenCount() -> Int {
        tokens.count
    }

    // MARK: - Lifecycle

    /// Mark the stream as complete.
    public func markComplete() {
        isComplete = true
    }

    /// Mark the stream as failed.
    public func markFailed(_ pulseError: PulseError) {
        error = pulseError
        isComplete = true
    }

    /// Whether the stream has finished (successfully or with an error).
    public func isFinished() -> Bool {
        isComplete
    }

    /// The error that terminated the stream, if any.
    public func streamError() -> PulseError? {
        error
    }

    // MARK: - Reset

    /// Clear all state for reuse.
    public func reset() {
        tokens.removeAll(keepingCapacity: true)
        isComplete = false
        error = nil
    }
}
