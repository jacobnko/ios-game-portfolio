// Checks the feedback form's pure parts: the refusal lines and the email fallback.

import Testing
import Foundation
@testable import CoreKitUI
import CoreKitServices

private let text = FeedbackFormText(title: "Feedback", subtitle: "s", bug: "Bug", idea: "Idea", placeholder: "p", disclosure: "d",
                                    send: "Send", sent: "Thanks", failed: "Couldn't send", tooShort: "Too short", tooLong: "Too long",
                                    tooSoon: "Try again in %lld s", close: "Close", emailInstead: "Email us")

@Test func eachRefusalHasItsLine() {
    #expect(text.message(for: .tooShort) == "Too short" && text.message(for: .tooLong) == "Too long")
    #expect(text.message(for: .tooSoon(seconds: 12)) == "Try again in 12 s" && text.message(for: .failed) == "Couldn't send")
}

@Test func theEmailFallbackCarriesTheSameFields() throws {
    let report = FeedbackReport(kind: .bug, message: "Hint did nothing & stuck", appVersion: "1.0.0", build: "1",
                                osVersion: "26.0", device: "iPad16,1", context: "classic.hard.3")
    let url = try #require(FeedbackForm.mailURL(to: "admin@example.com", report: report))
    let parts = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    #expect(parts.scheme == "mailto" && parts.path == "admin@example.com")
    let body = parts.queryItems?.first { $0.name == "body" }?.value ?? ""
    #expect(body.contains("Hint did nothing & stuck") && body.contains("1.0.0 (1)") && body.contains("iPad16,1") && body.contains("classic.hard.3"))
    #expect(parts.queryItems?.first { $0.name == "subject" }?.value == "Bug report")
}
