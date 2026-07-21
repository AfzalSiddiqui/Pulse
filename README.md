# Pulse — LLM Streaming Engine for iOS

> 🚧 **In active development** — architecture below; code landing in phases.

## High-Performance Token Streaming Infrastructure for AI Applications

Pulse is a Swift package that provides a production-oriented streaming engine for Large Language Model (LLM) responses on iOS.

The project focuses on building a **low-latency, memory-efficient, and interruption-friendly streaming architecture** for AI-powered mobile applications.

Pulse transforms token-by-token LLM responses into a smooth SwiftUI rendering experience using modern Swift concurrency patterns.

Pulse is the streaming foundation for [NOVA](https://github.com/AfzalSiddiqui/NOVAVoiceBankingAI), a voice-first AI banking assistant.

---

# 🚀 Vision

Modern AI applications require more than sending a request and waiting for a response.

Users expect:

* Instant response streaming
* Smooth token rendering
* Immediate cancellation
* Efficient memory usage
* Responsive UI during long generations

Pulse provides the infrastructure layer required for building ChatGPT-like experiences on iOS.

---

# ✨ Key Features

## ⚡ Token-by-Token LLM Streaming

Pulse supports real-time streaming of LLM responses.

Instead of waiting for the complete response:

```
Traditional:

Request
   |
   |
Complete Response
   |
   |
Display


Pulse:

Request

↓

Token 1 → Render

Token 2 → Render

Token 3 → Render

...

Final Response
```

---

# 🌐 Server-Sent Events (SSE) Streaming

Pulse implements SSE streaming using native iOS networking.

Technology:

* URLSession
* URLSession.AsyncBytes
* AsyncSequence
* Swift Concurrency

Pipeline:

```
LLM Provider

     |

HTTP Streaming Response

     |

URLSession AsyncBytes

     |

SSE Parser

     |

Token Stream

     |

SwiftUI Renderer
```

---

# 🧵 Swift Concurrency Architecture

Built using modern Swift concurrency.

Features:

* AsyncSequence based streaming
* Structured concurrency
* Task cancellation
* Actor-based state management
* Thread-safe token
