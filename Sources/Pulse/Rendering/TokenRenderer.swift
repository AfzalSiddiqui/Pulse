import Foundation
import SwiftUI

/// Batched token renderer that coalesces high-frequency token arrivals
/// into periodic UI updates to maintain 60 FPS.
///
/// Instead of hopping to `@MainActor` for every single token, the renderer
/// accumulates tokens over a configurable window (default 50 ms) and flushes
/// them to a `@Published` property in one update.
@MainActor
public final class TokenRenderer: ObservableObject {

    // MARK: - Published State

    /// The fully accumulated response text, updated in batches.
    @Published public private(set) var text: String = ""

    /// Whether the stream is currently active.
    @Published public private(set) var isStreaming: Bool = false

    /// The number of tokens received so far.
    @Published public private(set) var tokenCount: Int = 0

    // MARK: - Private

    private var buffer: [String] = []
    private var flushTask: Task<Void, Never>?
    private let renderInterval: Duration
    private let streamActor = StreamActor()

    // MARK: - Init

    public init(renderInterval: Duration = .milliseconds(50)) {
        self.renderInterval = renderInterval
    }

    // MARK: - Streaming

    /// Consume a ``TokenStream`` and render its output with batched UI updates.
    public func stream(_ tokenStream: TokenStream) async {
        isStreaming = true
        text = ""
        tokenCount = 0
        buffer.removeAll()

        startFlushLoop()

        do {
            for try await token in tokenStream {
                buffer.append(token)
                await streamActor.append(token)
            }

            // Final flush
            flushBuffer()
            await streamActor.markComplete()
        } catch is CancellationError {
            await streamActor.markFailed(.cancelled)
        } catch let error as PulseError {
            await streamActor.markFailed(error)
        } catch {
            await streamActor.markFailed(.networkFailure(error.localizedDescription))
        }

        flushTask?.cancel()
        flushTask = nil
        isStreaming = false
    }

    /// Stop rendering and cancel the flush loop.
    public func stop() {
        flushTask?.cancel()
        flushTask = nil
        isStreaming = false
    }

    /// Reset all state for a new conversation turn.
    public func reset() {
        stop()
        text = ""
        tokenCount = 0
        buffer.removeAll()
    }

    // MARK: - Flush Loop

    private func startFlushLoop() {
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: self.renderInterval)
                self.flushBuffer()
            }
        }
    }

    private func flushBuffer() {
        guard !buffer.isEmpty else { return }
        let batch = buffer.joined()
        buffer.removeAll(keepingCapacity: true)
        text.append(batch)
        tokenCount = text.count  // character-level count for display
    }
}
