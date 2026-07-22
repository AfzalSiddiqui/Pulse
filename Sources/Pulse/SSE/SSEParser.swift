import Foundation

/// Incremental SSE parser that processes raw bytes into ``SSEEvent`` values.
///
/// Handles partial frames, multi-line data fields, and malformed input gracefully.
/// Thread-safe by value semantics (struct + Sendable).
public struct SSEParser: Sendable {

    // MARK: - State

    private var buffer: String = ""
    private var currentEvent: String = "message"
    private var currentData: [String] = []
    private var currentId: String?
    private var currentRetry: Int?

    // MARK: - Init

    public init() {}

    // MARK: - Parsing

    /// Feed a raw chunk of bytes into the parser and extract any complete events.
    ///
    /// - Parameter chunk: A UTF-8 string chunk received from the network.
    /// - Returns: Zero or more fully parsed ``SSEEvent`` values.
    public mutating func parse(chunk: String) -> [SSEEvent] {
        buffer.append(chunk)

        var events: [SSEEvent] = []

        while let separatorRange = buffer.range(of: "\n\n") {
            let block = String(buffer[buffer.startIndex..<separatorRange.lowerBound])
            buffer = String(buffer[separatorRange.upperBound...])
            if let event = parseBlock(block) {
                events.append(event)
            }
        }

        // Also handle \r\n\r\n (Windows-style line endings)
        while let separatorRange = buffer.range(of: "\r\n\r\n") {
            let block = String(buffer[buffer.startIndex..<separatorRange.lowerBound])
            buffer = String(buffer[separatorRange.upperBound...])
            if let event = parseBlock(block) {
                events.append(event)
            }
        }

        return events
    }

    /// Parse a complete SSE block (lines between blank-line separators).
    private mutating func parseBlock(_ block: String) -> SSEEvent? {
        currentEvent = "message"
        currentData = []
        currentId = nil
        currentRetry = nil

        let lines = block.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .carriageReturns) }

        for line in lines {
            parseLine(line)
        }

        guard !currentData.isEmpty else { return nil }

        let data = currentData.joined(separator: "\n")
        return SSEEvent(
            event: currentEvent,
            data: data,
            id: currentId,
            retry: currentRetry
        )
    }

    /// Parse a single SSE field line (e.g. `data: hello`).
    private mutating func parseLine(_ line: String) {
        // Ignore comments
        if line.hasPrefix(":") { return }

        // Empty line — skip (block separator already handled)
        if line.isEmpty { return }

        let field: String
        let value: String

        if let colonIndex = line.firstIndex(of: ":") {
            field = String(line[line.startIndex..<colonIndex])
            let afterColon = line.index(after: colonIndex)
            let rawValue = String(line[afterColon...])
            // Strip single leading space per spec
            value = rawValue.hasPrefix(" ") ? String(rawValue.dropFirst()) : rawValue
        } else {
            // Field with no value
            field = line
            value = ""
        }

        switch field {
        case "data":
            currentData.append(value)
        case "event":
            currentEvent = value
        case "id":
            currentId = value
        case "retry":
            if let ms = Int(value) {
                currentRetry = ms
            }
        default:
            // Unknown fields are ignored per spec
            break
        }
    }
}

// MARK: - Helpers

private extension CharacterSet {
    static let carriageReturns = CharacterSet(charactersIn: "\r")
}

private extension String {
    func trimmingCharacters(in set: CharacterSet) -> String {
        (self as NSString).trimmingCharacters(in: set)
    }
}
