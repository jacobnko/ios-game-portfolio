// Verifies event sanitization and the shared schema every game depends on.

import Testing
import Foundation
@testable import CoreKitServices

// MARK: - Sanitization

@Test func namesAreLowercasedAndStripped() {
    // Backends reject malformed names without telling the app, so a typo becomes a
    // metric that is simply never collected.
    #expect(AnalyticsEvent(name: "Stage Clear!").name == "stage_clear_")
    #expect(AnalyticsEvent(name: "stage-clear").name == "stage_clear")
}

@Test func namesMustStartWithALetter() {
    #expect(AnalyticsEvent(name: "123stage").name == "stage")
    #expect(AnalyticsEvent(name: "_stage").name == "stage")
}

@Test func reservedPrefixesAreRemoved() {
    // firebase_, google_ and ga_ are reserved; events using them are dropped.
    #expect(AnalyticsEvent(name: "firebase_start").name == "start")
    #expect(AnalyticsEvent(name: "ga_clear").name == "clear")
}

@Test func namesAreTruncatedToTheLimit() {
    let long = String(repeating: "a", count: 100)
    #expect(AnalyticsEvent(name: long).name.count == AnalyticsEvent.maxNameLength)
}

@Test func anUnusableNameFallsBackRatherThanVanishing() {
    #expect(AnalyticsEvent(name: "!!!").name == "unnamed_event")
    #expect(AnalyticsEvent(name: "").name == "unnamed_event")
}

@Test func parameterKeysAreSanitizedToo() {
    let event = AnalyticsEvent(name: "test", parameters: ["Stage ID": .string("s1")])
    #expect(event.parameters["stage_id"] == .string("s1"))
}

@Test func longStringValuesAreTruncated() {
    let long = String(repeating: "x", count: 250)
    let event = AnalyticsEvent(name: "test", parameters: ["note": .string(long)])
    guard case .string(let stored)? = event.parameters["note"] else { Issue.record("missing"); return }
    #expect(stored.count == 100)
}

@Test func parameterCountIsCapped() {
    let many = Dictionary(uniqueKeysWithValues: (0..<40).map { ("p\($0)", AnalyticsValue.int($0)) })
    #expect(AnalyticsEvent(name: "test", parameters: many).parameters.count == AnalyticsEvent.maxParameterCount)
}

@Test func truncationIsDeterministic() {
    // Dictionary ordering is not stable between runs; truncating by it would make
    // the same call site emit different events on different launches.
    let many = Dictionary(uniqueKeysWithValues: (0..<40).map { ("p\($0)", AnalyticsValue.int($0)) })
    #expect(AnalyticsEvent(name: "t", parameters: many) == AnalyticsEvent(name: "t", parameters: many))
}

@Test func nonStringValuesPassThroughUnchanged() {
    let event = AnalyticsEvent(name: "test", parameters: [
        "count": .int(7), "ratio": .double(0.5), "flag": .bool(true),
    ])
    #expect(event.parameters["count"] == .int(7))
    #expect(event.parameters["ratio"] == .double(0.5))
    #expect(event.parameters["flag"] == .bool(true))
}

// MARK: - Shared schema

@Test func stageFunnelUsesStableNames() {
    // These names are compared across ten apps. Renaming one breaks the comparison
    // silently, so they are pinned here.
    #expect(GameEvent.stageStarted(stageID: "s1", attempt: 1).name == "stage_start")
    #expect(GameEvent.stageCleared(stageID: "s1", attempt: 1, durationSeconds: 12, stars: 3).name == "stage_clear")
    #expect(GameEvent.stageAbandoned(stageID: "s1", attempt: 1, durationSeconds: 5, progressPercent: 40).name == "stage_abandon")
}

@Test func monetizationEventsUseStableNames() {
    #expect(GameEvent.adShown(placement: .interstitial).name == "ad_shown")
    #expect(GameEvent.adSuppressed(verdict: .tooSoon).name == "ad_suppressed")
    #expect(GameEvent.removeAdsPurchased(priceDisplay: "$2.99").name == "remove_ads_purchase")
    #expect(GameEvent.purchasesRestored(didRestore: true).name == "purchases_restore")
}

@Test func suppressedAdsCarryTheirReason() {
    let event = GameEvent.adSuppressed(verdict: .onboardingGrace)
    #expect(event.parameters["verdict"] == .string("onboardingGrace"))
}

@Test func shareEventsWorkWithAndWithoutAStage() {
    #expect(GameEvent.shareTriggered(surface: "result", stageID: "s3").parameters["stage_id"] == .string("s3"))
    #expect(GameEvent.shareTriggered(surface: "menu", stageID: nil).parameters["stage_id"] == nil)
}

@Test func everySharedEventNameSurvivesSanitization() {
    // If a factory produced a name the sanitizer would alter, the event logged would
    // not match the name written in the dashboards.
    let events = [
        GameEvent.stageStarted(stageID: "s", attempt: 1),
        GameEvent.stageCleared(stageID: "s", attempt: 1, durationSeconds: 1, stars: 1),
        GameEvent.stageAbandoned(stageID: "s", attempt: 1, durationSeconds: 1, progressPercent: 1),
        GameEvent.hintUsed(stageID: "s", source: .rewardedAd),
        GameEvent.adShown(placement: .banner),
        GameEvent.adSuppressed(verdict: .allowed),
        GameEvent.rewardEarned(placement: "hint"),
        GameEvent.removeAdsViewed(source: "settings"),
        GameEvent.removeAdsPurchased(priceDisplay: "$2.99"),
        GameEvent.purchasesRestored(didRestore: false),
        GameEvent.shareTriggered(surface: "result", stageID: nil),
        GameEvent.settingToggled(name: "haptics", isOn: true),
    ]
    for event in events {
        #expect(event.name == AnalyticsEvent.sanitizeName(event.name))
        #expect(event.name.count <= AnalyticsEvent.maxNameLength)
        #expect(event.parameters.count <= AnalyticsEvent.maxParameterCount)
    }
}

// MARK: - Hub

@Test @MainActor func eventsReachEveryRegisteredReporter() {
    let analytics = AnalyticsHub()
    let a = ConsoleAnalyticsReporter()
    let b = ConsoleAnalyticsReporter()
    analytics.register(a)
    analytics.register(b)

    analytics.log(GameEvent.adShown(placement: .banner))
    #expect(a.events.count == 1)
    #expect(b.events.count == 1)
}

@Test @MainActor func optingOutStopsEverything() {
    let analytics = AnalyticsHub()
    let reporter = ConsoleAnalyticsReporter()
    analytics.register(reporter)
    analytics.isEnabled = false

    analytics.log(GameEvent.adShown(placement: .banner))
    analytics.setUserProperty("x", forName: "y")
    #expect(reporter.events.isEmpty)
}

@Test @MainActor func loggingWithNoReportersIsHarmless() {
    // Games log from the first launch, before any backend is configured, so this
    // path has to be safe rather than merely unlikely.
    let hub = AnalyticsHub()
    hub.log(GameEvent.stageStarted(stageID: "s1", attempt: 1))
    hub.record(SampleError())
    hub.leaveBreadcrumb("no reporters attached")
    hub.setUserProperty("ko", forName: "language")
    #expect(hub.isEnabled)                 // nothing disabled itself as a side effect
    #expect(hub.isCrashReportingEnabled)
}

// MARK: - Regression: the console reporter is bounded

@Test @MainActor func theConsoleReporterDiscardsOldEvents() {
    // A long session logs thousands of events. An unbounded buffer is a slow leak
    // nobody would ever attribute to analytics.
    let reporter = ConsoleAnalyticsReporter(capacity: 10)
    for index in 0..<50 {
        reporter.log(AnalyticsEvent(name: "event", parameters: ["i": .int(index)]))
    }
    #expect(reporter.events.count == 10)
    #expect(reporter.events.last?.parameters["i"] == .int(49))   // newest kept
}

// MARK: - Regression: names must end up ASCII

@Test func nonAsciiNamesAreReplaced() {
    // Swift's `isLetter` is true for Hangul and Kana, so a Korean event name would
    // pass an "is it a letter" check and then be dropped silently by the backend —
    // the exact failure this sanitizer exists to prevent.
    let event = AnalyticsEvent(name: "스테이지클리어")
    #expect(event.name.allSatisfy { $0.isASCII })
    #expect(event.name == "unnamed_event")   // nothing usable survived
}

@Test func mixedScriptNamesKeepOnlyTheAsciiPart() {
    // "클리어" is three characters, so it becomes three underscores between the two
    // that were already there.
    let event = AnalyticsEvent(name: "stage_클리어_2")
    #expect(event.name.allSatisfy { $0.isASCII })
    #expect(event.name == "stage_____2")
}

@Test func everySanitizedNameIsAsciiSafe() {
    let inputs = ["日本語イベント", "événement", "тест", "emoji_🎉_event", "stage clear!", "ガチャ_pull"]
    for input in inputs {
        let name = AnalyticsEvent(name: input).name
        #expect(name.allSatisfy { $0.isASCII }, "\(input) produced \(name)")
        #expect(name.first?.isLetter == true)
    }
}

@Test func sharedEventNamesAreAllAscii() {
    for event in [GameEvent.stageStarted(stageID: "s", attempt: 1), GameEvent.adShown(placement: .banner)] {
        #expect(event.name.allSatisfy { $0.isASCII })
    }
}

// MARK: - Crash reporting fan-out
//
// Entirely unexecuted until the third audit pass. Non-fatal errors are how
// persistence and purchase failures become visible at all; if this path is dead,
// those bugs stay invisible for months.

private final class SpyCrashReporter: CrashReporting, @unchecked Sendable {
    private let lock = NSLock()
    private var _errors: [(Error, [String: String])] = []
    private var _breadcrumbs: [String] = []
    private var _keys: [String: String] = [:]

    var errors: [(Error, [String: String])] { lock.withLock { _errors } }
    var breadcrumbs: [String] { lock.withLock { _breadcrumbs } }
    var keys: [String: String] { lock.withLock { _keys } }

    func record(_ error: Error, context: [String: String]) { lock.withLock { _errors.append((error, context)) } }
    func leaveBreadcrumb(_ message: String) { lock.withLock { _breadcrumbs.append(message) } }
    func setKey(_ value: String, forName name: String) { lock.withLock { _keys[name] = value } }
}

private struct SampleError: Error {}

@Test @MainActor func recordedErrorsReachEveryCrashReporter() {
    let hub = AnalyticsHub()
    let a = SpyCrashReporter()
    let b = SpyCrashReporter()
    hub.register(crashReporter: a)
    hub.register(crashReporter: b)

    hub.record(SampleError(), context: ["stage": "s12"])
    #expect(a.errors.count == 1)
    #expect(b.errors.count == 1)
    // Context is what makes a non-fatal actionable; without it the dashboard shows
    // a stack trace and no way to tell which stage it came from.
    #expect(a.errors.first?.1["stage"] == "s12")
}

@Test @MainActor func breadcrumbsAndKeysReachCrashReporters() {
    let hub = AnalyticsHub()
    let spy = SpyCrashReporter()
    hub.register(crashReporter: spy)

    hub.leaveBreadcrumb("entered stage 12")
    hub.setCrashKey("chordline", forName: "game")
    #expect(spy.breadcrumbs == ["entered stage 12"])
    #expect(spy.keys["game"] == "chordline")
}

@Test @MainActor func crashReportingIsAySeparateSwitchFromAnalytics() {
    // Opting out of analytics is a choice about behavioural data. It must not
    // blind crash reporting, or a player who opts out can never be supported.
    let hub = AnalyticsHub()
    let spy = SpyCrashReporter()
    hub.register(crashReporter: spy)

    hub.isEnabled = false
    hub.record(SampleError())
    #expect(spy.errors.count == 1)

    // And the diagnostic switch must actually work on its own.
    hub.isCrashReportingEnabled = false
    hub.record(SampleError())
    hub.leaveBreadcrumb("x")
    hub.setCrashKey("v", forName: "k")
    #expect(spy.errors.count == 1)
    #expect(spy.breadcrumbs.isEmpty)
    #expect(spy.keys.isEmpty)
}

@Test @MainActor func removingReportersDetachesEverything() {
    let hub = AnalyticsHub()
    let reporter = ConsoleAnalyticsReporter()
    let crash = SpyCrashReporter()
    hub.register(reporter)
    hub.register(crashReporter: crash)
    hub.removeAllReporters()

    hub.log(GameEvent.adShown(placement: .banner))
    hub.record(SampleError())
    #expect(reporter.events.isEmpty)
    #expect(crash.errors.isEmpty)
}

@Test @MainActor func theConsoleReporterCanBeClearedAndTakesProperties() {
    let reporter = ConsoleAnalyticsReporter()
    reporter.log(GameEvent.adShown(placement: .banner))
    reporter.setUserProperty("ko", forName: "language")
    #expect(reporter.events.count == 1)
    reporter.clear()
    #expect(reporter.events.isEmpty)
}

@Test func analyticsValuesDescribeThemselves() {
    #expect(AnalyticsValue.string("x").described == "x")
    #expect(AnalyticsValue.int(3).described == "3")
    #expect(AnalyticsValue.bool(true).described == "true")
    #expect(AnalyticsValue.double(1.5).described == "1.5")
}
