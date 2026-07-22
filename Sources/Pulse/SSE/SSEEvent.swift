import Foundation

/// A fully parsed Server-Sent Event conforming to the W3C EventSource specification.
public struct SSEEvent: Sendable, Equatable {

    /// The event type (the `event:` field). Defaults to `"message"` when omitted by the server.
    public let event: String

    /// The data payload (the `data:` field). Multiple `data:` lines are joined with `\n`.
    public let data: String

    /// Optional event identifier (the `id:` field).
    public let id: String?

    /// Optional reconnection interval in milliseconds (the `retry:` field).
    public let retry: Int?

    // MARK: - Convenience

    /// `true` when this event signals the end of the stream (OpenAI convention).
    public var isDone: Bool {
        data == "[DONE]"
    }

    /// `true` when the data payload is empty.
    public var isEmpty: Bool {
        data.isEmpty
    }

    // MARK: - Init

    public init(
        event: String = "message",
        data: String,
        id: String? = nil,
        retry: Int? = nil
    ) {
        self.event = event
        self.data = data
        self.id = id
        self.retry = retry
    }
}
