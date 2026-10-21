// Sends a player's bug report or idea to Discord — straight to a webhook, or through the studio relay (D-126).

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

/// Where reports go. Built from the game's Info.plist; nil when nothing is configured, so the screen
/// can offer email instead.
public struct FeedbackEndpoint: Equatable, Sendable {
    public enum Style: Equatable, Sendable {
        /// The studio relay (`Tools/FeedbackRelay`): the key names the game; the webhook stays on the server.
        case relay(appKey: String)
        /// A Discord webhook posted to directly. Simpler, but the URL ships inside the app and anyone who
        /// extracts it can post to the channel; the only remedy is a new webhook and an app update (D-126).
        case discord(appName: String)
    }

    public let url: URL
    public let style: Style

    public init(url: URL, appKey: String) {
        self.url = url
        style = .relay(appKey: appKey)
    }

    public init(discordWebhook url: URL, appName: String) {
        self.url = url
        style = .discord(appName: appName)
    }

    /// `FeedbackDiscordWebhook` (a discord.com webhook) wins; otherwise `FeedbackEndpoint` + `FeedbackAppKey`.
    /// Blank or half-built values (an unset build setting) count as absent.
    public static func from(bundle: Bundle = .main) -> FeedbackEndpoint? {
        func value(_ key: String) -> String? {
            let text = (bundle.object(forInfoDictionaryKey: key) as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
            return text.isEmpty || text.contains("$(") ? nil : text
        }
        if let raw = value("FeedbackDiscordWebhook"), let url = URL(string: raw), isDiscordWebhook(url) {
            let name = value("CFBundleDisplayName") ?? value("CFBundleName") ?? "App"
            return FeedbackEndpoint(discordWebhook: url, appName: name)
        }
        guard let raw = value("FeedbackEndpoint"), let key = value("FeedbackAppKey"),
              let url = URL(string: raw), url.scheme == "https",
              let host = url.host, !host.isEmpty else { return nil }   // an unset host builds "https:///feedback"
        return FeedbackEndpoint(url: url, appKey: key)
    }

    /// `https://discord.com/api/webhooks/<id>/<token>` (or discordapp.com) with both parts present.
    static func isDiscordWebhook(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host, host == "discord.com" || host == "discordapp.com" else { return false }
        let parts = url.path.split(separator: "/")
        return parts.count == 4 && parts[0] == "api" && parts[1] == "webhooks" && !parts[2].isEmpty && !parts[3].isEmpty
    }
}

/// The Discord message for a report: one embed, and no pings ever (`allowed_mentions` empty).
enum DiscordFeedback {
    static func payload(_ report: FeedbackReport, appName: String) -> [String: Any] {
        let bug = report.kind == .bug
        let title = "\(bug ? "🐞 Bug" : "💡 Idea") · \(appName) \(report.appVersion) (\(report.build))"
        return [
            "username": "Feedback",
            "allowed_mentions": ["parse": [String]()],
            "embeds": [[
                "title": String(title.prefix(256)),
                "description": report.message,
                "color": bug ? 0xFF4D2E : 0xB8FF2E,
                "fields": [
                    ["name": "Device", "value": String("\(report.device) · iOS \(report.osVersion)".prefix(1024)), "inline": true],
                    ["name": "Context", "value": String((report.context.isEmpty ? "—" : report.context).prefix(1024)), "inline": true],
                ],
            ]],
        ]
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
    /// Discord caps a message at 2000 characters (an embed's text at 4096); this leaves room either way.
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
        switch endpoint.style {
        case .relay(let appKey):
            request.setValue(appKey, forHTTPHeaderField: "X-Feedback-Key")
            request.httpBody = try JSONEncoder().encode(trimmed)
        case .discord(let appName):
            request.httpBody = try JSONSerialization.data(withJSONObject: DiscordFeedback.payload(trimmed, appName: appName))
        }
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
