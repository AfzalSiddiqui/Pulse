import Foundation

/// Low-level HTTP stream reader built on `URLSession.AsyncBytes`.
///
/// Validates response headers, handles cancellation, and yields raw
/// UTF-8 line chunks suitable for SSE parsing.
public struct HTTPStreamReader: Sendable {

    private let session: URLSession
    private let configuration: PulseConfiguration

    public init(
        session: URLSession = .shared,
        configuration: PulseConfiguration = .default
    ) {
        self.session = session
        self.configuration = configuration
    }

    /// Open a streaming HTTP connection and yield decoded UTF-8 chunks.
    ///
    /// - Parameter request: A configured `URLRequest` pointing at an SSE endpoint.
    /// - Returns: An `AsyncThrowingStream` of string chunks as they arrive on the wire.
    public func readStream(
        request: URLRequest
    ) async throws -> AsyncThrowingStream<String, Error> {
        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PulseError.networkFailure("Non-HTTP response received")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw PulseError.serverError(httpResponse.statusCode)
        }

        // Validate content type — accept text/event-stream or application/json for
        // providers that don't set the correct MIME.
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
        let acceptable = ["text/event-stream", "application/json", "text/plain"]
        let valid = acceptable.contains { contentType.lowercased().contains($0) }
        if !valid && !contentType.isEmpty {
            throw PulseError.invalidContentType(contentType)
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var lineBuffer = ""
                    for try await byte in bytes {
                        try Task.checkCancellation()

                        let char = Character(UnicodeScalar(byte))
                        lineBuffer.append(char)

                        // Flush on newline — the SSE parser handles block assembly.
                        if char == "\n" {
                            continuation.yield(lineBuffer)
                            lineBuffer = ""
                        }
                    }

                    // Flush remaining buffer
                    if !lineBuffer.isEmpty {
                        continuation.yield(lineBuffer)
                    }

                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: PulseError.cancelled)
                } catch {
                    continuation.finish(throwing: PulseError.networkFailure(error.localizedDescription))
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
