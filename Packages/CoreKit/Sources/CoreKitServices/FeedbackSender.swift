// Sends a player's bug report or idea to the studio's feedback relay, which forwards it to Discord (D-126).

import Foundation

/// What the player chose to send. The relay — not the app — knows which game a key belongs to.
public struct FeedbackReport: Equatable, Sendable, Codable {
    public enum Kind: String, Sendable, Codable, CaseIterable {
        case bug, idea
    }

    public var kind: Kind
    public var message: String
    public var appVersion: String
    public var build: String
    public var osVersion: String
    public var device: String
    /// A short line the game adds, such as the mode and stage last played. Never personal data.
    public var context: String

    public init(kind: Kind, message: String, appVersion: String, build: String, osVersion: String, device: String, context: String = "") {
        self.kind = kind
        self.message = message
        self.appVersion = appVersion
        self.build = build
        self.osVersion = osVersion
        self.device = device
        self.context = context
    }

    /// Fills the app and device fields from the running app.
    public static func current(kind: Kind, message: String, context: String = "", bundle: Bundle = .main) -> FeedbackReport {
        let info = bundle.infoDictionary ?? [:]
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return FeedbackReport(kind: kind, message: message,
                              appVersion: info["CFBundleShortVersionString"] as? String ?? "?",
                              build: info["CFBundleVersion"] as? String ?? "?",
                              osVersion: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
                              device: FeedbackReport.deviceModel(), context: context)
    }

    /// The hardware model identifier ("iPhone17,1"), which says nothing about who owns it.
    static func deviceModel() -> String {
        var info = utsname()
        uname(&info)
        let machine = withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
        return machine.isEmpty ? "unknown" : machine
    }
}

/// Where reports go and how often. Built from the game's Info.plist; nil when the game has no relay
/// configured, so the screen can offer email instead.
public struct FeedbackEndpoint: Equatable, Sendable {
    public let url: URL
    /// Identifies the game to the relay. Not a secret — it only lets the relay name the game and
    /// drop requests that carry no known key.
    public let appKey: String

    public init(url: URL, appKey: String) {
        self.url = url
        self.appKey = appKey
    }

    /// Reads `FeedbackEndpoint` and `FeedbackAppKey` from the bundle; nil if either is missing or blank.
    public static func from(bundle: Bundle = .main) -> FeedbackEndpoint? {
        guard let raw = bundle.object(forInfoDictionaryKey: "FeedbackEndpoint") as? String,
              let key = bundle.object(forInfoDictionaryKey: "FeedbackAppKey") as? String,
              !key.trimmingCharacters(in: .whitespaces).isEmpty,
              let url = URL(string: raw.trimmingCharacters(in: .whitespaces)), url.scheme == "https",
              let host = url.host, !host.isEmpty else { return nil }   // an unset host builds "https:///feedback"
        return FeedbackEndpoint(url: url, appKey: key)
    }
}

public enum FeedbackError: Error, Equatable, Sendable {
    case tooShort
    case tooLong
    /// Sent one a moment ago; try again after this many seconds.
    case tooSoon(seconds: Int)
    case failed
}

/// Checks and posts reports. The rules are pure so the host tests pin them; the network is injected.
@MainActor
public final class FeedbackSender {
    public static let minimumLength = 5
    /// Discord caps a message at 2000 characters; the relay adds a header.
    public static let maximumLength = 1500
    /// One report per this many seconds from one device.
    public static let interval: TimeInterval = 30

    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let endpoint: FeedbackEndpoint
    private let transport: Transport
    private let now: () -> Date
    private var lastSent: Date?

    public init(endpoint: FeedbackEndpoint, transport: Transport? = nil, now: @escaping () -> Date = Date.init) {
        self.endpoint = endpoint
        self.transport = transport ?? { try await URLSession.shared.data(for: $0) }
        self.now = now
    }

    /// Why a message can't be sent yet, or nil if it can.
    public func problem(with message: String) -> FeedbackError? {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count < FeedbackSender.minimumLength { return .tooShort }
        if text.count > FeedbackSender.maximumLength { return .tooLong }
        if let lastSent {
            let wait = FeedbackSender.interval - now().timeIntervalSince(lastSent)
            if wait > 0 { return .tooSoon(seconds: Int(wait.rounded(.up))) }
        }
        return nil
    }

    func request(for report: FeedbackReport) throws -> URLRequest {
        var trimmed = report
        trimmed.message = report.message.trimmingCharacters(in: .whitespacesAndNewlines)
        var request = URLRequest(url: endpoint.url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(endpoint.appKey, forHTTPHeaderField: "X-Feedback-Key")
        request.httpBody = try JSONEncoder().encode(trimmed)
        return request
    }

    /// Posts the report. Throws `FeedbackError`; on success the interval starts.
    public func send(_ report: FeedbackReport) async throws {
        if let problem = problem(with: report.message) { throw problem }
        let request: URLRequest
        do { request = try self.request(for: report) } catch { throw FeedbackError.failed }
        do {
            let (_, response) = try await transport(request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw FeedbackError.failed }
        } catch let error as FeedbackError {
            throw error
        } catch {
            throw FeedbackError.failed
        }
        lastSent = now()
    }
}
