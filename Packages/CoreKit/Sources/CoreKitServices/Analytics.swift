// Fan-out point for analytics and crash reporting, with no vendor SDK attached.

import Foundation

/// Somewhere events can be sent.
public protocol AnalyticsReporting: AnyObject, Sendable {
    func log(_ event: AnalyticsEvent)
    /// Segments users. Values are low cardinality — a stage id here would be useless.
    func setUserProperty(_ value: String?, forName name: String)
}

/// Somewhere non-fatal problems can be recorded.
public protocol CrashReporting: AnyObject, Sendable {
    func record(_ error: Error, context: [String: String])
    /// Breadcrumb that shows up attached to the next crash.
    func leaveBreadcrumb(_ message: String)
    func setKey(_ value: String, forName name: String)
}

/// The single place games send analytics.
///
/// Named `AnalyticsHub` rather than `Analytics` so it never collides with a vendor
/// SDK type of the same name in a file that imports both.
///
/// Reporters are registered rather than hard-coded so that the vendor stays
/// swappable, and so tests and the harness can observe events without a backend.
@MainActor
public final class AnalyticsHub {
    public static let shared = AnalyticsHub()

    /// Turned off entirely when the player opts out.
    public var isEnabled: Bool = true

    private var reporters: [AnalyticsReporting] = []
    private var crashReporters: [CrashReporting] = []

    public init() {}

    public func register(_ reporter: AnalyticsReporting) {
        reporters.append(reporter)
    }

    public func register(crashReporter: CrashReporting) {
        crashReporters.append(crashReporter)
    }

    public func removeAllReporters() {
        reporters.removeAll()
        crashReporters.removeAll()
    }

    public func log(_ event: AnalyticsEvent) {
        guard isEnabled else { return }
        reporters.forEach { $0.log(event) }
    }

    public func setUserProperty(_ value: String?, forName name: String) {
        guard isEnabled else { return }
        reporters.forEach { $0.setUserProperty(value, forName: name) }
    }

    /// Records a problem the app handled but should not have hit.
    ///
    /// Silent `try?` is how persistence and purchase bugs stay invisible for months.
    /// Failures that are survivable still need to be visible.
    public func record(_ error: Error, context: [String: String] = [:]) {
        crashReporters.forEach { $0.record(error, context: context) }
    }

    public func leaveBreadcrumb(_ message: String) {
        crashReporters.forEach { $0.leaveBreadcrumb(message) }
    }

    public func setCrashKey(_ value: String, forName name: String) {
        crashReporters.forEach { $0.setKey(value, forName: name) }
    }
}

/// Prints events to the console. For development and the harness.
public final class ConsoleAnalyticsReporter: AnalyticsReporting, @unchecked Sendable {
    /// Newest events retained. Bounded because a long session logs thousands, and an
    /// unbounded buffer in a shipped build is a slow memory leak nobody attributes
    /// to analytics.
    public let capacity: Int

    private let lock = NSLock()
    private var _events: [AnalyticsEvent] = []

    /// Everything retained so far, newest last.
    public var events: [AnalyticsEvent] { lock.withLock { _events } }

    public init(capacity: Int = 200) {
        self.capacity = max(1, capacity)
    }

    public func log(_ event: AnalyticsEvent) {
        lock.withLock {
            _events.append(event)
            if _events.count > capacity { _events.removeFirst(_events.count - capacity) }
        }
        #if DEBUG
        let parameters = event.parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.described)" }
            .joined(separator: " ")
        print("📊 \(event.name) \(parameters)")
        #endif
    }

    public func setUserProperty(_ value: String?, forName name: String) {
        #if DEBUG
        print("📊 property \(name)=\(value ?? "nil")")
        #endif
    }

    public func clear() { lock.withLock { _events.removeAll() } }
}

public extension AnalyticsValue {
    /// Human-readable form, for debug output and the harness.
    var described: String {
        switch self {
        case .string(let value): value
        case .int(let value): "\(value)"
        case .double(let value): "\(value)"
        case .bool(let value): "\(value)"
        }
    }
}
