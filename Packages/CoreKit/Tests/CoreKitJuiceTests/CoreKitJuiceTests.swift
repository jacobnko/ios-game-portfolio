// Guards the juice layer's public contract.

import Testing
@testable import CoreKitJuice

@Test func feedbackWeightCoversEveryIntent() {
    #expect(FeedbackWeight.allCases.count == 3)
}

@Test func juiceStepIsValueComparable() {
    let a = JuiceStep(index: 0, weight: .micro)
    let b = JuiceStep(index: 0, weight: .micro)
    #expect(a == b)
}
