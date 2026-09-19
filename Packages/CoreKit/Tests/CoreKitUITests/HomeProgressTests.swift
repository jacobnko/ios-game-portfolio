// The progress bar's only real logic: turning two counts into a fraction.

import Testing
@testable import CoreKitUI

@Test func fractionIsClearedOverTotal() {
    #expect(HomeProgress(cleared: 23, total: 60).fraction == 23.0 / 60.0)
}

@Test func anEmptyGameDoesNotDivideByZero() {
    // A game whose catalog failed to load reports 0/0. Returning 0 keeps the
    // bar empty; the arithmetic would otherwise produce NaN and SwiftUI would
    // size the fill view to NaN, which is a crash rather than a blank bar.
    #expect(HomeProgress(cleared: 0, total: 0).fraction == 0)
    #expect(HomeProgress(cleared: 5, total: 0).fraction == 0)
}

@Test func fractionNeverExceedsOne() {
    // More clears than stages should not draw a bar wider than its track.
    #expect(HomeProgress(cleared: 70, total: 60).fraction == 1)
}

@Test func negativeCountsAreClampedAtConstruction() {
    let progress = HomeProgress(cleared: -4, total: -9)
    #expect(progress.cleared == 0)
    #expect(progress.total == 0)
}

@Test func aFinishedGameReportsAFullBar() {
    #expect(HomeProgress(cleared: 60, total: 60).fraction == 1)
}
