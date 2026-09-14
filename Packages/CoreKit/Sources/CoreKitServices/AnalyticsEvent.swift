// Typed analytics events, sanitized to the limits the backend actually enforces.

import Foundation

/// A value an event can carry.
public enum AnalyticsValue: Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    /// Backends cap string parameters at 100 characters and drop anything longer,
    /// so truncation happens here rather than silently at the far end.
    public var truncated: AnalyticsValue {
        guard case .string(let text) = self, text.count > 100 else { return self }
        return .string(String(text.prefix(100)))
    }
}

/// One analytics event.
///
/// Names and parameters are sanitized on construction. Analytics backends reject
/// malformed events without telling the app, so an unsanitized typo means a metric
/// that is simply never collected — and you find out weeks later when you go
/// looking for the data that would have decided whether a game gets more work.
public struct AnalyticsEvent: Sendable, Equatable {
    /// Firebase's limit, and a reasonable one for any backend.
    public static let maxNameLength = 40
    public static let maxParameterCount = 25

    public let name: String
    public let parameters: [String: AnalyticsValue]

    public init(name: String, parameters: [String: AnalyticsValue] = [:]) {
        self.name = Self.sanitizeName(name)
        var cleaned: [String: AnalyticsValue] = [:]
        // Sorted so that truncation past the cap is deterministic rather than
        // dependent on dictionary ordering, which would make events differ per run.
        for key in parameters.keys.sorted().prefix(Self.maxParameterCount) {
            cleaned[Self.sanitizeName(key)] = parameters[key]?.truncated
        }
        self.parameters = cleaned
    }

    /// Lowercases, replaces anything but letters, digits and underscore, ensures a
    /// leading letter, strips reserved prefixes, and truncates.
    static func sanitizeName(_ raw: String) -> String {
        var result = raw.lowercased().map { character -> Character in
            character.isLetter || character.isNumber || character == "_" ? character : "_"
        }

        // Reserved prefixes are silently rejected by Firebase.
        var text = String(result)
        for reserved in ["firebase_", "google_", "ga_"] where text.hasPrefix(reserved) {
            text = String(text.dropFirst(reserved.count))
        }
        result = Array(text)

        // Must begin with a letter.
        while let first = result.first, !first.isLetter { result.removeFirst() }
        if result.isEmpty { return "unnamed_event" }

        return String(result.prefix(maxNameLength))
    }
}
