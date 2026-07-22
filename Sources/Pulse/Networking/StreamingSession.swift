import Foundation

/// Manages the lifecycle of a single streaming HTTP session.
///
/// Bridges ``HTTPStreamReader`` and ``SSEParser`` to produce a decoded ``TokenStream``.
public final class StreamingSession: Sendable {

    private let reader: HTTPStreamReader
    private let decoder: SSEDecoder
    private let configuration: PulseConfiguration

    public init(
        reader: HTTPStreamReader = HTTPStreamReader(),
        decoder: SSEDecoder = SSEDecoder(),
        configuration: PulseConfiguration = .default
    ) {
        self.reader = reader
        self.decoder = decoder
        self.configuration = configuration
    }

    /// Start streaming from the given URL request and return a ``TokenStream``.
    public func start(request: URLRequest) async throws -> TokenStream {
        let rawStream = try await reader.readStream(request: request)

        return TokenStream { continuation in
            let task = Task {
                var parser = SSEParser()

                do {
                    for try await chunk in rawStream {
                        try Task.checkCancellation()

                        let events = parser.parse(chunk: chunk)

                        for event in events {
                            if event.isDone {
                                continuation.finish()
                                return
                            }

                            if let token = try self.decoder.decode(event) {
                                continuation.yield(token)
                            }
                        }
                    }

                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: PulseError.cancelled)
                } catch let error as PulseError {
                    continuation.finish(throwing: error)
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
