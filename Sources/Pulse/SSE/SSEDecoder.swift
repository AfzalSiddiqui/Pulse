import Foundation

/// Decodes ``SSEEvent`` payloads into domain-level token strings.
///
/// Supports multiple LLM provider response formats:
/// - OpenAI-style `choices[0].delta.content`
/// - Anthropic-style `delta.text`
/// - Plain text data fields
public struct SSEDecoder: Sendable {

    public enum DecodingStrategy: Sendable {
        /// Treat the raw `data:` field as the token (no JSON parsing).
        case plainText
        /// Parse OpenAI-compatible `choices[0].delta.content` JSON.
        case openAI
        /// Parse Anthropic-compatible `delta.text` JSON.
        case anthropic
        /// Use a custom key path into the JSON payload.
        case custom(@Sendable (String) throws -> String?)
    }

    private let strategy: DecodingStrategy

    public init(strategy: DecodingStrategy = .plainText) {
        self.strategy = strategy
    }

    /// Decode a single ``SSEEvent`` into a token string.
    ///
    /// - Returns: The extracted token, or `nil` if the event should be skipped.
    /// - Throws: ``PulseError/decodingFailure`` on malformed payloads.
    public func decode(_ event: SSEEvent) throws -> String? {
        guard !event.isDone else { return nil }
        guard !event.isEmpty else { return nil }

        switch strategy {
        case .plainText:
            return event.data

        case .openAI:
            return try decodeOpenAI(event.data)

        case .anthropic:
            return try decodeAnthropic(event.data)

        case .custom(let decoder):
            return try decoder(event.data)
        }
    }

    // MARK: - OpenAI

    private func decodeOpenAI(_ data: String) throws -> String? {
        guard let jsonData = data.data(using: .utf8) else {
            throw PulseError.decodingFailure("Invalid UTF-8 in OpenAI payload")
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let delta = first["delta"] as? [String: Any] else {
                return nil
            }

            // `content` may be null on role-only chunks
            return delta["content"] as? String
        } catch {
            throw PulseError.decodingFailure("OpenAI JSON parse error: \(error.localizedDescription)")
        }
    }

    // MARK: - Anthropic

    private func decodeAnthropic(_ data: String) throws -> String? {
        guard let jsonData = data.data(using: .utf8) else {
            throw PulseError.decodingFailure("Invalid UTF-8 in Anthropic payload")
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                return nil
            }

            // Anthropic uses `type` to distinguish event kinds
            let type = json["type"] as? String

            switch type {
            case "content_block_delta":
                guard let delta = json["delta"] as? [String: Any],
                      let text = delta["text"] as? String else {
                    return nil
                }
                return text

            case "message_stop", "content_block_stop":
                return nil

            default:
                return nil
            }
        } catch {
            throw PulseError.decodingFailure("Anthropic JSON parse error: \(error.localizedDescription)")
        }
    }
}
