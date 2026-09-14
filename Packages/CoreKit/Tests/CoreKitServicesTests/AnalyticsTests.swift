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
    // Games log from the first launch, before any backend is configured.
    AnalyticsHub().log(GameEvent.stageStarted(stageID: "s1", attempt: 1))
}
