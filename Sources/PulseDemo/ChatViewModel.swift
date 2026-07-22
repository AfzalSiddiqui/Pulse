import Foundation
import SwiftUI
import Pulse

/// View model driving the demo chat interface.
@MainActor
@Observable
public final class ChatViewModel {

    // MARK: - Published State

    public var messages: [ChatMessage] = []
    public var inputText: String = ""
    public var isStreaming: Bool = false
    public var tokenCount: Int = 0
    public var metricsText: String = ""

    // MARK: - Private

    private let provider: any LLMStreamingProvider
    private let renderer: TokenRenderer
    private let metrics: PulseMetrics
    private var streamTask: Task<Void, Never>?

    // MARK: - Init

    public init(provider: any LLMStreamingProvider = MockLLMProvider()) {
        self.provider = provider
        self.renderer = TokenRenderer(renderInterval: .milliseconds(50))
        self.metrics = PulseMetrics()
    }

    // MARK: - Actions

    public func send() {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        // Add user message
        messages.append(ChatMessage(role: .user, content: prompt))
        inputText = ""

        // Add placeholder assistant message
        let assistantIndex = messages.count
        messages.append(ChatMessage(role: .assistant, content: ""))

        isStreaming = true
        tokenCount = 0

        streamTask = Task {
            await metrics.recordStreamStart()

            do {
                let request = LLMRequest.prompt(prompt)
                let stream = try await provider.stream(request: request)

                await metrics.recordFirstToken()

                var fullText = ""
                var count = 0

                for try await token in stream {
                    guard !Task.isCancelled else { break }
                    await metrics.recordToken()
                    fullText.append(token)
                    count += 1

                    // Batch UI updates
                    if count % 3 == 0 || Task.isCancelled {
                        messages[assistantIndex].content = fullText
                        tokenCount = count
                    }
                }

                // Final update
                messages[assistantIndex].content = fullText
                tokenCount = count

                await metrics.recordStreamEnd()
                await updateMetricsDisplay()

            } catch {
                if case PulseError.cancelled = error {
                    await metrics.recordCancellation()
                } else {
                    await metrics.recordFailure()
                    messages[assistantIndex].content = "Error: \(error.localizedDescription)"
                }
            }

            isStreaming = false
        }
    }

    public func stop() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }

    // MARK: - Metrics

    private func updateMetricsDisplay() async {
        let snap = await metrics.snapshot()

        var parts: [String] = []

        if let ttft = snap.timeToFirstToken {
            let ms = Double(ttft.components.seconds) * 1000 +
                     Double(ttft.components.attoseconds) / 1e15
            parts.append(String(format: "TTFT: %.0fms", ms))
        }

        parts.append("Tokens: \(snap.tokensReceived)")

        if let tps = snap.tokensPerSecond {
            parts.append(String(format: "%.1f tok/s", tps))
        }

        if let dur = snap.streamDuration {
            let seconds = Double(dur.components.seconds) +
                          Double(dur.components.attoseconds) / 1e18
            parts.append(String(format: "Duration: %.1fs", seconds))
        }

        metricsText = parts.joined(separator: " | ")
    }
}

// MARK: - Chat Message

public struct ChatMessage: Identifiable {
    public let id = UUID()
    public let role: Role
    public var content: String

    public enum Role {
        case user
        case assistant
    }
}
