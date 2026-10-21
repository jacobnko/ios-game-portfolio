// Checks the feedback sender: length and pacing rules, the request it builds, and how failures surface.

import Testing
import Foundation
@testable import CoreKitServices

private let endpoint = FeedbackEndpoint(url: URL(string: "https://relay.example.com/feedback")!, appKey: "key-123")

private func report(_ message: String = "The board froze after a power-up.") -> FeedbackReport {
    FeedbackReport(kind: .bug, message: message, appVersion: "1.0.0", build: "1", osVersion: "26.0.1", device: "iPhone17,1", context: "classic.hard.8")
}

private final class Box: @unchecked Sendable {
    var requests: [URLRequest] = []
    var status = 204
}

@MainActor
private func makeSender(_ box: Box, now: @escaping () -> Date) -> FeedbackSender {
    FeedbackSender(endpoint: endpoint, transport: { request in
        box.requests.append(request)
        return (Data(), HTTPURLResponse(url: request.url!, statusCode: box.status, httpVersion: nil, headerFields: nil)!)
    }, now: now)
}

@MainActor
@Test func shortLongAndRepeatedMessagesAreRefusedBeforeSending() async throws {
    var clock = Date(timeIntervalSince1970: 1_000)
    let box = Box()
    let sender = makeSender(box) { clock }
    #expect(sender.problem(with: "  hi \n") == .tooShort)
    #expect(sender.problem(with: String(repeating: "a", count: FeedbackSender.maximumLength + 1)) == .tooLong)
    #expect(sender.problem(with: "Long enough to send") == nil)
    try await sender.send(report())
    clock += 10
    #expect(sender.problem(with: "Another one") == .tooSoon(seconds: 20))
    await #expect(throws: FeedbackError.tooSoon(seconds: 20)) { try await sender.send(report()) }
    #expect(box.requests.count == 1, "nothing goes out while too soon")
    clock += 21
    try await sender.send(report())
    #expect(box.requests.count == 2)
}

@MainActor
@Test func theRequestCarriesTheKeyAndATrimmedReport() async throws {
    let box = Box()
    let sender = makeSender(box) { Date() }
    try await sender.send(report("   Stage 12 has no answer   \n"))
    let request = try #require(box.requests.first)
    #expect(request.httpMethod == "POST" && request.url == endpoint.url)
    #expect(request.value(forHTTPHeaderField: "X-Feedback-Key") == "key-123")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    let sent = try JSONDecoder().decode(FeedbackReport.self, from: try #require(request.httpBody))
    #expect(sent.message == "Stage 12 has no answer" && sent.kind == .bug && sent.context == "classic.hard.8" && sent.device == "iPhone17,1")
}

@MainActor
@Test func aRefusedOrFailedPostIsAFailureAndDoesNotStartTheInterval() async throws {
    let box = Box()
    box.status = 429
    let sender = makeSender(box) { Date(timeIntervalSince1970: 5) }
    await #expect(throws: FeedbackError.failed) { try await sender.send(report()) }
    #expect(sender.problem(with: "try again now") == nil, "a failure does not lock the player out")
    let offline = FeedbackSender(endpoint: endpoint, transport: { _ in throw URLError(.notConnectedToInternet) })
    await #expect(throws: FeedbackError.failed) { try await offline.send(report()) }
}

@Test func theEndpointComesFromTheBundleOnlyWhenComplete() {
    #expect(FeedbackEndpoint.from(bundle: Bundle(for: Box.self)) == nil, "a bundle without the keys has no relay")
    #expect(URL(string: "https:///feedback")?.host == nil, "what an unset FEEDBACK_HOST builds — refused by the host check")
    let current = FeedbackReport.current(kind: .idea, message: "More levels please", context: "classic.easy.3")
    #expect(!current.osVersion.isEmpty && !current.device.isEmpty && current.kind == .idea)
}

@MainActor
@Test func aDiscordWebhookGetsOneEmbedAndNoPings() async throws {
    let box = Box()
    let hook = URL(string: "https://discord.com/api/webhooks/123/abc")!
    let sender = FeedbackSender(endpoint: FeedbackEndpoint(discordWebhook: hook, appName: "GameOne"), transport: { request in
        box.requests.append(request)
        return (Data(), HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!)
    })
    try await sender.send(report("  Tiles vanished @everyone  "))
    let request = try #require(box.requests.first)
    #expect(request.url == hook && request.value(forHTTPHeaderField: "X-Feedback-Key") == nil)
    let body = try #require(request.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect((json["allowed_mentions"] as? [String: Any])?["parse"] as? [String] == [])
    let embed = try #require((json["embeds"] as? [[String: Any]])?.first)
    #expect(embed["title"] as? String == "🐞 Bug · GameOne 1.0.0 (1)")
    #expect(embed["description"] as? String == "Tiles vanished @everyone")
    #expect(embed["color"] as? Int == 0xFF4D2E)
}

@Test func onlyARealDiscordWebhookCountsAsOne() {
    #expect(FeedbackEndpoint.isDiscordWebhook(URL(string: "https://discord.com/api/webhooks/1/token")!))
    #expect(FeedbackEndpoint.isDiscordWebhook(URL(string: "https://discordapp.com/api/webhooks/1/token")!))
    #expect(!FeedbackEndpoint.isDiscordWebhook(URL(string: "https://discord.com/api/webhooks/1")!), "no token")
    #expect(!FeedbackEndpoint.isDiscordWebhook(URL(string: "https://discord.com/api/webhooks//")!), "an unset build setting")
    #expect(!FeedbackEndpoint.isDiscordWebhook(URL(string: "http://discord.com/api/webhooks/1/t")!), "plain http")
    #expect(!FeedbackEndpoint.isDiscordWebhook(URL(string: "https://evil.example/api/webhooks/1/t")!))
}
