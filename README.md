# Pulse

**Production-grade LLM token streaming engine for iOS.**

Pulse is the streaming infrastructure layer powering [NOVA](https://github.com/AfzalSiddiqui/NOVAVoiceBankingAI), a voice-first AI banking assistant. It delivers a ChatGPT-like streaming experience on iOS with low latency, smooth SwiftUI rendering, immediate cancellation, and memory-efficient processing.

---

## Architecture

```
LLM Provider (OpenAI / Anthropic / Azure / Local)
          │
          ▼
   HTTP Streaming Response
          │
          ▼
   URLSession.AsyncBytes
          │
          ▼
       SSEParser
          │
          ▼
   AsyncSequence TokenStream
          │
          ▼
   Actor-Managed State (StreamActor)
          │
          ▼
   TokenRenderer → SwiftUI (50ms batched updates)
```

---

## Requirements

| Requirement | Value |
|---|---|
| Swift | 6.0+ |
| iOS | 17.0+ |
| macOS | 14.0+ |
| Dependencies | None (Apple frameworks only) |

---

## Installation

### Swift Package Manager

```swift
.package(url: "https://github.com/AfzalSiddiqui/Pulse.git", from: "1.0.0")
```

```swift
.target(name: "YourApp", dependencies: ["Pulse"])
```

---

## Quick Start

### Stream tokens from an OpenAI-compatible endpoint

```swift
import Pulse

let client = LLMClient(
    baseURL: URL(string: "https://api.openai.com/v1")!,
    apiKey: "sk-...",
    decodingStrategy: .openAI
)

let stream = try await client.stream(prompt: "Explain quantum computing")

for try await token in stream {
    print(token, terminator: "")
}
```

### Use with any provider via the protocol

```swift
struct MyBankingModel: LLMStreamingProvider {
    func stream(request: LLMRequest) async throws -> TokenStream {
        // Connect to your enterprise model endpoint
    }
}
```

### SwiftUI integration with batched rendering

```swift
@MainActor
final class ChatViewModel: ObservableObject {
    private let renderer = TokenRenderer(renderInterval: .milliseconds(50))

    func generate(prompt: String) async {
        let stream = try await client.stream(prompt: prompt)
        await renderer.stream(stream) // Batched 60 FPS updates
    }
}

struct ChatView: View {
    @StateObject var viewModel = ChatViewModel()
    @StateObject var renderer: TokenRenderer

    var body: some View {
        Text(renderer.text)
    }
}
```

---

## Module Reference

### Networking

| Type | Purpose |
|---|---|
| `LLMClient` | High-level client — primary entry point |
| `LLMStreamingProvider` | Protocol for pluggable LLM backends |
| `LLMRequest` | Provider-agnostic request payload |
| `StreamingSession` | Manages a single streaming HTTP session |
| `HTTPStreamReader` | Low-level `URLSession.AsyncBytes` reader |

### SSE

| Type | Purpose |
|---|---|
| `SSEParser` | Incremental Server-Sent Events parser |
| `SSEEvent` | Parsed SSE event (data, event, id, retry) |
| `SSEDecoder` | Decodes SSE payloads to tokens (OpenAI, Anthropic, plain text, custom) |

### Streaming

| Type | Purpose |
|---|---|
| `TokenStream` | `AsyncSequence<String>` — the core streaming primitive |
| `StreamController` | Orchestrates connection, streaming, cancellation, metrics |
| `BackpressureManager` | Configurable token buffering with overflow strategies |

### Concurrency

| Type | Purpose |
|---|---|
| `StreamActor` | Actor-isolated token accumulation (thread-safe state) |
| `CancellationManager` | Coordinates structured cancellation across the pipeline |

### Rendering

| Type | Purpose |
|---|---|
| `TokenRenderer` | Batched `@MainActor` renderer — coalesces tokens into 50ms UI updates |

### Observability

| Type | Purpose |
|---|---|
| `PulseMetrics` | Actor-based production metrics (TTFT, tokens/sec, cancellation rate) |

### Configuration

| Type | Purpose |
|---|---|
| `PulseConfiguration` | Buffer size, render interval, timeouts, retry, overflow strategy |

### Errors

| Type | Purpose |
|---|---|
| `PulseError` | Typed, equatable, recoverable error taxonomy |

---

## SSE Parser

Handles the full W3C EventSource specification:

- Incremental parsing of partial network chunks
- Multi-line `data:` fields joined with `\n`
- `event:`, `id:`, `retry:` fields
- Comment lines (`:` prefix) ignored
- Malformed input handled gracefully
- Windows-style `\r\n` line endings

```swift
var parser = SSEParser()
let events = parser.parse(chunk: "data: Hello\n\ndata: World\n\n")
// → [SSEEvent(data: "Hello"), SSEEvent(data: "World")]
```

---

## Provider Abstraction

Pulse supports any LLM backend via `LLMStreamingProvider`:

```swift
protocol LLMStreamingProvider: Sendable {
    func stream(request: LLMRequest) async throws -> TokenStream
}
```

Built-in decoding strategies:

| Strategy | Format |
|---|---|
| `.plainText` | Raw `data:` field as token |
| `.openAI` | `choices[0].delta.content` JSON |
| `.anthropic` | `delta.text` with `content_block_delta` type |
| `.custom` | User-provided `(String) throws -> String?` closure |

---

## Backpressure

Configure how fast token generation interacts with slower UI rendering:

```swift
let config = PulseConfiguration(
    maxBufferSize: 100,
    overflowStrategy: .batch,       // .batch | .dropOldest | .error
    renderInterval: .milliseconds(50)
)
```

---

## Cancellation

Structured cancellation propagates through the full pipeline:

```
User taps Stop
      │
      ▼
  Task.cancel()
      │
      ▼
  URLSession request cancelled
      │
      ▼
  SSE parser stops
      │
      ▼
  TokenStream finishes
      │
      ▼
  Resources released
```

```swift
let task = Task {
    for try await token in stream { ... }
}

// Later:
task.cancel() // Entire pipeline tears down
```

---

## Observability

```swift
let metrics = PulseMetrics()
let controller = StreamController(provider: client, metrics: metrics)

// After streaming:
let snap = await metrics.snapshot()
snap.timeToFirstToken   // Duration?
snap.tokensReceived     // Int
snap.tokensPerSecond    // Double?
snap.streamDuration     // Duration?
snap.cancellationRate   // Double (0.0–1.0)
snap.failureRate        // Double (0.0–1.0)
```

---

## Error Handling

All errors are typed, equatable, and carry debug context:

```swift
enum PulseError: Error, Sendable, Equatable {
    case networkFailure(String)
    case invalidStream(String)
    case cancelled
    case decodingFailure(String)
    case serverError(Int)
    case invalidContentType(String)
    case bufferOverflow(Int)
    case providerError(String)
    case internalError(String)
}
```

---

## Performance Targets

| Metric | Target |
|---|---|
| Time To First Token | < 500ms |
| UI Frame Rate | 60 FPS during long responses |
| Memory | 20,000+ tokens without uncontrolled growth |
| Cancellation | Immediate (structured Task cancellation) |

---

## Test Coverage

**64 tests** across 8 test suites:

| Suite | Tests | Coverage |
|---|---|---|
| `SSEParserTests` | 15 | Parsing, partial frames, edge cases |
| `SSEDecoderTests` | 9 | OpenAI, Anthropic, plain text, custom |
| `TokenStreamTests` | 6 | Iteration, cancellation, errors, 10K tokens |
| `StreamActorTests` | 7 | Accumulation, lifecycle, concurrent access |
| `BackpressureManagerTests` | 5 | Buffering, batch, drop-oldest |
| `CancellationTests` | 4 | Manager, propagation |
| `ErrorHandlingTests` | 4 | Descriptions, equality, propagation |
| `IntegrationTests` | 9 | End-to-end, 20K tokens, metrics pipeline |
| `MetricsTests` | 5 | Lifecycle, cancellation/failure tracking |

---

## Project Structure

```
Pulse/
├── Package.swift
├── Sources/
│   ├── Pulse/
│   │   ├── Pulse.swift
│   │   ├── Configuration/
│   │   │   └── PulseConfiguration.swift
│   │   ├── Concurrency/
│   │   │   ├── CancellationManager.swift
│   │   │   └── StreamActor.swift
│   │   ├── Errors/
│   │   │   └── PulseError.swift
│   │   ├── Networking/
│   │   │   ├── HTTPStreamReader.swift
│   │   │   ├── LLMClient.swift
│   │   │   ├── LLMRequest.swift
│   │   │   ├── LLMStreamingProvider.swift
│   │   │   └── StreamingSession.swift
│   │   ├── Observability/
│   │   │   └── PulseMetrics.swift
│   │   ├── Rendering/
│   │   │   └── TokenRenderer.swift
│   │   ├── SSE/
│   │   │   ├── SSEDecoder.swift
│   │   │   ├── SSEEvent.swift
│   │   │   └── SSEParser.swift
│   │   └── Streaming/
│   │       ├── BackpressureManager.swift
│   │       ├── StreamController.swift
│   │       └── TokenStream.swift
│   └── PulseDemo/
│       ├── PulseDemoApp.swift
│       ├── ChatViewModel.swift
│       └── MockLLMProvider.swift
└── Tests/
    └── PulseTests/
        ├── MockHelpers.swift
        ├── SSEParserTests.swift
        ├── SSEDecoderTests.swift
        ├── TokenStreamTests.swift
        ├── StreamActorTests.swift
        ├── BackpressureManagerTests.swift
        ├── CancellationTests.swift
        ├── ErrorHandlingTests.swift
        ├── IntegrationTests.swift
        └── MetricsTests.swift
```

---

## Design Decisions

1. **Swift 6 strict concurrency** — All types are `Sendable`. No data races by construction.
2. **No third-party dependencies** — Built entirely on Foundation, URLSession, and Swift Concurrency.
3. **AsyncSequence as the core primitive** — `TokenStream` conforms to `AsyncSequence` for natural `for try await` consumption.
4. **Actor isolation over locks** — `StreamActor`, `BackpressureManager`, `CancellationManager`, and `PulseMetrics` are all actors.
5. **Batched rendering** — `TokenRenderer` coalesces tokens in a 50ms window to prevent excessive `@MainActor` hops and maintain 60 FPS.
6. **Provider abstraction** — `LLMStreamingProvider` protocol decouples the engine from any specific LLM backend.
7. **Incremental SSE parsing** — `SSEParser` handles partial frames across network chunk boundaries.
8. **Structured cancellation** — Swift `Task` cancellation propagates through the entire pipeline from UI to network.

---

## License

MIT
