import Foundation

/// Production-grade error taxonomy for the Pulse streaming engine.
public enum PulseError: Error, Sendable, Equatable {

    /// The underlying network transport failed (timeout, DNS, TLS, etc.).
    case networkFailure(String)

    /// The byte stream did not conform to the SSE specification.
    case invalidStream(String)

    /// The operation was explicitly cancelled by the caller.
    case cancelled

    /// A received SSE data frame could not be decoded into a valid token.
    case decodingFailure(String)

    /// The remote server responded with a non-2xx status code.
    case serverError(Int)

    /// The response was missing required headers (e.g. `text/event-stream`).
    case invalidContentType(String)

    /// The stream exceeded the configured backpressure buffer limit.
    case bufferOverflow(Int)

    /// The provider returned an application-level error payload.
    case providerError(String)

    /// An unexpected internal error.
    case internalError(String)
}

extension PulseError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .networkFailure(let detail):
            return "Network failure: \(detail)"
        case .invalidStream(let detail):
            return "Invalid stream: \(detail)"
        case .cancelled:
            return "Stream cancelled"
        case .decodingFailure(let detail):
            return "Decoding failure: \(detail)"
        case .serverError(let code):
            return "Server error: HTTP \(code)"
        case .invalidContentType(let type):
            return "Invalid content type: \(type)"
        case .bufferOverflow(let size):
            return "Buffer overflow at \(size) tokens"
        case .providerError(let detail):
            return "Provider error: \(detail)"
        case .internalError(let detail):
            return "Internal error: \(detail)"
        }
    }
}
