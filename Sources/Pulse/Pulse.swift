/// Pulse — A production-grade LLM token streaming engine for iOS.
///
/// Pulse provides the streaming infrastructure layer for AI-powered mobile
/// applications, delivering ChatGPT-like token streaming with:
///
/// - Low-latency SSE parsing
/// - Smooth SwiftUI rendering via token batching
/// - Immediate structured cancellation
/// - Memory-efficient backpressure management
/// - Actor-isolated thread safety
/// - Production-grade observability
///
/// ## Quick Start
///
/// ```swift
/// let client = LLMClient(
///     baseURL: URL(string: "https://api.openai.com/v1")!,
///     apiKey: "sk-..."
/// )
///
/// let stream = try await client.stream(prompt: "Explain quantum computing")
///
/// for try await token in stream {
///     print(token, terminator: "")
/// }
/// ```
///
/// ## Architecture
///
/// ```
/// LLM Provider
///       ↓
/// HTTP Streaming Response
///       ↓
/// URLSession.AsyncBytes
///       ↓
/// SSEParser
///       ↓
/// AsyncSequence TokenStream
///       ↓
/// Actor-Managed State
///       ↓
/// SwiftUI TokenRenderer
/// ```

// Re-export all public types for a single-import experience.
// Each sub-module file already declares `public` on its types,
// and because they live in the same Swift module target, a
// single `import Pulse` gives access to everything.
