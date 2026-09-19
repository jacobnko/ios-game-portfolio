// The home screen's mode rows carry state; this pins what each state means.

import Testing
@testable import CoreKitUI

private func mode(_ state: HomeModeState) -> HomeMode {
    HomeMode(id: "m", title: "Play", lockedTitle: "Locked", state: state, action: {})
}

@Test func theThreeStatesAreDistinct() {
    // They are drawn differently on purpose — filled and glowing, checked and
    // shrunken, or dim with a padlock. Collapsing any two would leave the
    // screen without a single focal point.
    let states: [HomeModeState] = [.current, .cleared, .locked]
    #expect(Set(states.map(String.init(describing:))).count == 3)
}

@Test func aModeKeepsTheStateItIsGiven() {
    #expect(mode(.current).state == .current)
    #expect(mode(.cleared).state == .cleared)
    #expect(mode(.locked).state == .locked)
}

@Test func aModeCarriesBothItsOpenAndLockedNames() {
    // The locked row says what opens it rather than what it is called, so both
    // strings have to survive construction.
    let subject = mode(.locked)
    #expect(subject.title == "Play")
    #expect(subject.lockedTitle == "Locked")
}
