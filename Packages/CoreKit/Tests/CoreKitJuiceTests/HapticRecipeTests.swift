// Verifies the intent-to-feel mapping that every game depends on.

import Testing
import Foundation
@testable import CoreKitJuice

@Test func microStartsGentle() {
    let r = HapticRecipe.make(for: .micro, stepIndex: 0)
    #expect(r.intensity < 0.5)
    #expect(r.eventCount == 1)
}

@Test func microEscalatesMonotonically() {
    let values = (0...8).map { HapticRecipe.make(for: .micro, stepIndex: $0).intensity }
    #expect(zip(values, values.dropFirst()).allSatisfy { $0 <= $1 })
    #expect(values.first! < values.last!)
}

@Test func microClampsBeyondEscalationSpan() {
    let atSpan = HapticRecipe.make(for: .micro, stepIndex: 8, escalationSpan: 8)
    let beyond = HapticRecipe.make(for: .micro, stepIndex: 500, escalationSpan: 8)
    #expect(atSpan == beyond)
}

@Test func microNeverReachesMilestoneIntensity() {
    // A milestone must always feel heavier than any micro step, or the player
    // cannot tell progress from completion by touch alone.
    let peak = HapticRecipe.make(for: .micro, stepIndex: 999).intensity
    let milestone = HapticRecipe.make(for: .milestone).intensity
    #expect(peak < milestone)
}

@Test func milestoneAndErrorIgnoreStepIndex() {
    #expect(HapticRecipe.make(for: .milestone, stepIndex: 0) == HapticRecipe.make(for: .milestone, stepIndex: 7))
    #expect(HapticRecipe.make(for: .error, stepIndex: 0) == HapticRecipe.make(for: .error, stepIndex: 7))
}

@Test func errorIsSharperThanMilestone() {
    // Success and failure must never be confusable through the hand.
    #expect(HapticRecipe.make(for: .error).sharpness > HapticRecipe.make(for: .milestone).sharpness)
}

@Test(arguments: FeedbackWeight.allCases)
func everyRecipeStaysInUnitRange(weight: FeedbackWeight) {
    for step in [0, 1, 4, 99] {
        let r = HapticRecipe.make(for: weight, stepIndex: step)
        #expect((0...1).contains(r.intensity))
        #expect((0...1).contains(r.sharpness))
        #expect(r.eventCount >= 1)
        #expect(r.eventSpacing >= 0)
    }
}

@Test func initialiserClampsOutOfRangeInput() {
    let r = HapticRecipe(intensity: 5, sharpness: -3, eventCount: 0, eventSpacing: -1)
    #expect(r.intensity == 1)
    #expect(r.sharpness == 0)
    #expect(r.eventCount == 1)
    #expect(r.eventSpacing == 0)
}

@Test func durationMatchesEventLayout() {
    let single = HapticRecipe.make(for: .micro)
    #expect(single.duration == 0)
    let milestone = HapticRecipe.make(for: .milestone)
    #expect(milestone.duration > 0)
}

@Test func stepConvenienceMatchesExplicitCall() {
    let step = JuiceStep(index: 3, weight: .micro)
    #expect(HapticRecipe.make(for: step) == HapticRecipe.make(for: .micro, stepIndex: 3))
}
