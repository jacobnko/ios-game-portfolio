// The toast's only logic: how long it stays up.

import Testing
@testable import CoreKitUI

@Test func aToastKeepsTheDurationItIsGiven() {
    #expect(ToastMessage(text: "hi", seconds: 2).seconds == 2)
}

@Test func aDurationTooShortToReadIsRaised() {
    // A tip that vanishes in a tenth of a second is worse than none: the
    // player sees a flash and cannot tell what it said.
    #expect(ToastMessage(text: "hi", seconds: 0).seconds == 0.5)
    #expect(ToastMessage(text: "hi", seconds: -3).seconds == 0.5)
}

@Test func twoToastsWithTheSameTextAreStillDistinct() {
    // The overlay keys its expiry timer on the id. Two identical tips in a row
    // must not share one timer, or the second inherits the first's remainder.
    #expect(ToastMessage(text: "same") != ToastMessage(text: "same"))
}
